package com.vibeterm.vibeterm

import android.app.Activity
import com.vibeterm.vibeterm.BuildConfig
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import android.os.Handler
import android.os.Looper
import java.net.NetworkInterface
import java.util.Collections

/**
 * Flutter plugin that bridges Tailscale via libtailscale (Go).
 *
 * Implements libtailscale.AppContext so Go can call back into Android
 * for encrypted storage, device info, and network interfaces.
 *
 * Handles:
 * - Login via LocalAPI /login-interactive → browser OAuth
 * - VPN tunnel lifecycle via TailscaleVpnService
 * - IPN Bus notifications (state changes, browse URL, IP address)
 */
class TailscalePlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener, libtailscale.AppContext {

    companion object {
        private const val TAG = "TailscalePlugin"
        private const val CHANNEL_NAME = "com.chillshell.tailscale"
        private const val VPN_PERMISSION_REQUEST_CODE = 9001
        private const val PREFS_NAME = "tailscale_prefs"
        private const val ENCRYPTED_PREFS_NAME = "tailscale_encrypted_prefs"

        /** Singleton for VPN service callbacks. */
        @Volatile
        var instance: TailscalePlugin? = null
            private set
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    @Volatile
    private var pendingLoginResult: Result? = null
    private var tailscaleApp: libtailscale.Application? = null
    private var notificationManager: libtailscale.NotificationManager? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Cached state from IPN Bus
    private var currentIP: String? = null
    private var currentDeviceName: String? = null
    private var isConnected: Boolean = false
    private var pendingBrowseURL: String? = null

    // --- FlutterPlugin lifecycle ---

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        instance = this
        initLibtailscale()
        Log.d(TAG, "TailscalePlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        notificationManager?.stop()
        scope.cancel()
        context = null
        instance = null
        Log.d(TAG, "TailscalePlugin detached from engine")
    }

    // --- ActivityAware lifecycle ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() { activity = null }

    // --- Initialize libtailscale Go backend ---

    private fun initLibtailscale() {
        val ctx = context ?: return
        try {
            val dataDir = ctx.filesDir.absolutePath
            tailscaleApp = libtailscale.Libtailscale.start(
                dataDir,         // dataDir for Go state
                dataDir,         // directFileRoot
                false,           // hardware attestation (not needed)
                this             // AppContext implementation
            )
            Log.d(TAG, "libtailscale started successfully")
            startNotificationWatcher()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start libtailscale", e)
        }
    }

    // --- IPN Bus notification watcher ---

    private fun startNotificationWatcher() {
        val app = tailscaleApp ?: return
        scope.launch {
            try {
                // Watch mask: Netmap(1) | Prefs(2) | InitialState(4)
                val mask: Long = 1 or 2 or 4
                notificationManager = app.watchNotifications(mask,
                    object : libtailscale.NotificationCallback {
                        override fun onNotify(data: ByteArray) {
                            handleNotification(String(data, Charsets.UTF_8))
                        }
                    }
                )
                Log.d(TAG, "IPN Bus notification watcher started")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start notification watcher", e)
            }
        }
    }

    private fun handleNotification(jsonStr: String) {
        try {
            val json = JSONObject(jsonStr)

            // BrowseToURL — OAuth login URL from Go
            if (json.has("BrowseToURL") && !json.isNull("BrowseToURL")) {
                val url = json.getString("BrowseToURL")
                if (url.isNotEmpty() && url.startsWith("https://")) {
                    val allowedDomains = listOf("login.tailscale.com", "controlplane.tailscale.com", "tailscale.com")
                    val urlHost = try { java.net.URI(url).host } catch (e: Exception) { null }
                    if (urlHost != null && allowedDomains.any { urlHost.endsWith(it) }) {
                        Log.d(TAG, "BrowseToURL received (${url.length} chars)")
                        pendingBrowseURL = url
                        openBrowserForAuth(url)
                    } else {
                        Log.w(TAG, "BrowseToURL rejected: untrusted domain")
                    }
                } else {
                    Log.d(TAG, "BrowseToURL ignored (empty or not HTTPS)")
                }
            }

            // State change
            if (json.has("State") && !json.isNull("State")) {
                val state = json.optInt("State", -1)
                if (state >= 0) {
                    // State: 0=NoState, 1=InUseOtherUser, 2=NeedsLogin,
                    //        3=NeedsMachineAuth, 4=Stopped, 5=Starting, 6=Running
                    Log.d(TAG, "State changed: $state")
                    val wasConnected = isConnected
                    isConnected = state == 6 // Running
                    if (isConnected != wasConnected) {
                        notifyFlutterStateChanged()
                    }

                    // Start VPN service when state is Running
                    if (isConnected && !TailscaleVpnService.isRunning) {
                        startVpnService()
                    }
                }
            }

            // NetMap — contains self node with IP
            if (json.has("NetMap") && !json.isNull("NetMap")) {
                val netMap = json.getJSONObject("NetMap")
                if (netMap.has("SelfNode")) {
                    val selfNode = netMap.getJSONObject("SelfNode")

                    // Extract device name
                    if (selfNode.has("Name")) {
                        currentDeviceName = selfNode.getString("Name")
                            .removeSuffix(".") // Remove trailing dot
                    }

                    // Extract IP from Addresses
                    if (selfNode.has("Addresses")) {
                        val addrs = selfNode.getJSONArray("Addresses")
                        for (i in 0 until addrs.length()) {
                            val addr = addrs.getString(i)
                            // Take the first IPv4 (100.x.y.z/32)
                            if (addr.startsWith("100.")) {
                                currentIP = addr.split("/")[0]
                                break
                            }
                        }
                    }
                    notifyFlutterStateChanged()
                }
            }

            // LoginFinished
            if (json.has("LoginFinished") && !json.isNull("LoginFinished")) {
                Log.d(TAG, "Login finished successfully")
                // Resolve pending login result
                val result = pendingLoginResult
                pendingLoginResult = null
                activity?.runOnUiThread {
                    result?.success(mapOf(
                        "status" to "logged_in",
                        "myIP" to currentIP,
                        "deviceName" to currentDeviceName
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling IPN notification", e)
        }
    }

    private fun openBrowserForAuth(url: String) {
        val act = activity ?: return
        act.runOnUiThread {
            try {
                val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))
                act.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open browser for auth", e)
            }
        }
    }

    private fun notifyFlutterStateChanged() {
        activity?.runOnUiThread {
            channel.invokeMethod("onStateChanged", mapOf(
                "isConnected" to isConnected,
                "myIP" to currentIP,
                "deviceName" to currentDeviceName
            ))
        }
    }

    /** Start VPN service when Tailscale reaches Running state. */
    private fun startVpnService() {
        val ctx = context ?: return
        try {
            val serviceIntent = Intent(ctx, TailscaleVpnService::class.java).apply {
                action = TailscaleVpnService.ACTION_START
            }
            ctx.startForegroundService(serviceIntent)
            Log.d(TAG, "VPN service start requested")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN service", e)
        }
    }

    /** Called from TailscaleVpnService when VPN state changes. */
    fun onVpnStateChanged(active: Boolean) {
        isConnected = active
        notifyFlutterStateChanged()
    }

    // --- MethodCallHandler ---

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "login" -> handleLogin(result)
            "logout" -> handleLogout(result)
            "getStatus" -> handleGetStatus(result)
            "getPeers" -> handleGetPeers(result)
            else -> result.notImplemented()
        }
    }

    // --- Login ---

    private fun handleLogin(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        // Check VPN permission
        val vpnIntent = VpnService.prepare(currentActivity)
        if (vpnIntent != null) {
            pendingLoginResult = result
            currentActivity.startActivityForResult(vpnIntent, VPN_PERMISSION_REQUEST_CODE)
            return
        }

        startTailscaleLogin(result)
    }

    private fun startTailscaleLogin(result: Result) {
        val app = tailscaleApp
        if (app == null) {
            result.error("NOT_INITIALIZED", "libtailscale not initialized", null)
            return
        }

        val ctx = context ?: run {
            result.error("NO_CONTEXT", "No context", null)
            return
        }

        // Reject if a login is already in progress
        if (pendingLoginResult != null) {
            result.error("LOGIN_IN_PROGRESS", "A login is already in progress", null)
            return
        }

        pendingLoginResult = result

        // Timeout: cancel login after 120 seconds if not completed
        Handler(Looper.getMainLooper()).postDelayed({
            pendingLoginResult?.let { r ->
                r.error("TIMEOUT", "Login timed out after 120 seconds", null)
                pendingLoginResult = null
            }
        }, 120_000)

        scope.launch {
            try {
                // Call LocalAPI to start interactive login
                // Go will send BrowseToURL notification → opens browser
                // VPN service starts later when Go reaches Running state
                Log.d(TAG, "Calling login-interactive...")
                val response = app.callLocalAPI(
                    30000, // 30 second timeout
                    "POST",
                    "/localapi/v0/login-interactive",
                    null // no body
                )
                Log.d(TAG, "login-interactive response: ${response.statusCode()}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start login", e)
                withContext(Dispatchers.Main) {
                    val r = pendingLoginResult
                    pendingLoginResult = null
                    r?.error("LOGIN_FAILED", "Authentication failed", null)
                }
            }
        }
    }

    // --- Logout ---

    private fun handleLogout(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "No context", null)
            return
        }

        scope.launch {
            try {
                // Tell Go to log out
                tailscaleApp?.callLocalAPI(10000, "POST", "/localapi/v0/logout", null)

                // Stop VPN service
                val serviceIntent = Intent(ctx, TailscaleVpnService::class.java).apply {
                    action = TailscaleVpnService.ACTION_STOP
                }
                ctx.startService(serviceIntent)

                isConnected = false
                currentIP = null
                currentDeviceName = null

                withContext(Dispatchers.Main) {
                    result.success(null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to logout", e)
                withContext(Dispatchers.Main) {
                    result.error("LOGOUT_FAILED", "Logout failed", null)
                }
            }
        }
    }

    // --- Status ---

    private fun handleGetStatus(result: Result) {
        result.success(mapOf(
            "isConnected" to isConnected,
            "myIP" to currentIP,
            "deviceName" to currentDeviceName,
            "vpnServiceRunning" to TailscaleVpnService.isRunning
        ))
    }

    // --- Get Peers via LocalAPI ---

    private fun handleGetPeers(result: Result) {
        val app = tailscaleApp
        if (app == null) {
            result.error("NOT_INITIALIZED", "libtailscale not initialized", null)
            return
        }

        scope.launch {
            try {
                val response = app.callLocalAPI(
                    10000,
                    "GET",
                    "/localapi/v0/status",
                    null
                )
                val bodyBytes = response.bodyBytes()
                val bodyStr = if (bodyBytes != null) String(bodyBytes, Charsets.UTF_8) else "{}"
                val json = JSONObject(bodyStr)

                val peers = mutableListOf<Map<String, Any?>>()

                // Self node
                if (json.has("Self") && !json.isNull("Self")) {
                    val self = json.getJSONObject("Self")
                    parsePeer(self)?.let { peers.add(it) }
                }

                // Peer nodes
                if (json.has("Peer") && !json.isNull("Peer")) {
                    val peerMap = json.getJSONObject("Peer")
                    val keys = peerMap.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        val peer = peerMap.getJSONObject(key)
                        parsePeer(peer)?.let { peers.add(it) }
                    }
                }

                withContext(Dispatchers.Main) {
                    result.success(peers)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get peers", e)
                withContext(Dispatchers.Main) {
                    result.error("PEERS_FAILED", "Failed to fetch peers", null)
                }
            }
        }
    }

    private fun parsePeer(peer: JSONObject): Map<String, Any?>? {
        try {
            val name = peer.optString("HostName", "")
            val dnsName = peer.optString("DNSName", "").removeSuffix(".")
            val online = peer.optBoolean("Online", false)
            val os = peer.optString("OS", "")

            // Extract first IPv4 from TailscaleIPs
            var ip = ""
            if (peer.has("TailscaleIPs") && !peer.isNull("TailscaleIPs")) {
                val ips = peer.getJSONArray("TailscaleIPs")
                for (i in 0 until ips.length()) {
                    val addr = ips.getString(i)
                    if (addr.startsWith("100.")) {
                        ip = addr
                        break
                    }
                }
            }

            if (ip.isEmpty()) return null

            return mapOf(
                "name" to (dnsName.ifEmpty { name }),
                "ip" to ip,
                "isOnline" to online,
                "os" to os,
                // Intentionally truncated to 16 chars: used as opaque peer ID,
                // avoids exposing the full public key to the Flutter layer.
                "id" to peer.optString("PublicKey", "").take(16)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse peer: ${e.message ?: "Unknown error"}")
            return null
        }
    }

    // --- VPN permission result ---

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val result = pendingLoginResult
            if (resultCode == Activity.RESULT_OK) {
                if (result != null) {
                    startTailscaleLogin(result)
                }
            } else {
                pendingLoginResult = null
                result?.error("VPN_PERMISSION_DENIED", "User denied VPN permission", null)
            }
            return true
        }
        return false
    }

    // ========================================================
    // libtailscale.AppContext interface implementation
    // ========================================================

    override fun log(tag: String, msg: String) {
        if (BuildConfig.DEBUG) Log.d("TS-$tag", msg)
    }

    override fun encryptToPref(key: String, value: String) {
        getEncryptedPrefs().edit().putString(key, value).apply()
    }

    override fun decryptFromPref(key: String): String? {
        return getEncryptedPrefs().getString(key, null)
    }

    override fun getStateStoreKeysJSON(): String {
        val prefs = getEncryptedPrefs()
        val keys = prefs.all.keys
        val jsonArray = JSONArray(keys.toList())
        return jsonArray.toString()
    }

    override fun getOSVersion(): String {
        return "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"
    }

    override fun getDeviceName(): String {
        return "${Build.MANUFACTURER} ${Build.MODEL}"
    }

    override fun getInstallSource(): String = "chillshell"

    override fun shouldUseGoogleDNSFallback(): Boolean = true

    override fun isChromeOS(): Boolean = false

    override fun getInterfacesAsJson(): String {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            val jsonArray = JSONArray()

            for (iface in interfaces) {
                val addrs = JSONArray()
                for (addr in iface.interfaceAddresses) {
                    val addrObj = JSONObject()
                    addrObj.put("ip", addr.address.hostAddress)
                    addrObj.put("prefixLen", addr.networkPrefixLength)
                    addrs.put(addrObj)
                }

                val obj = JSONObject()
                obj.put("name", iface.name)
                obj.put("index", iface.index)
                obj.put("mtu", iface.mtu)
                obj.put("up", iface.isUp)
                obj.put("addrs", addrs)
                jsonArray.put(obj)
            }

            return jsonArray.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get interfaces", e)
            return "[]"
        }
    }

    override fun getPlatformDNSConfig(): String = ""

    // --- Syspolicy (MDM) - not used, return defaults ---

    override fun getSyspolicyStringValue(key: String): String {
        throw Exception("not configured")
    }

    override fun getSyspolicyBooleanValue(key: String): Boolean {
        throw Exception("not configured")
    }

    override fun getSyspolicyStringArrayJSONValue(key: String): String {
        throw Exception("not configured")
    }

    // --- Hardware Attestation - not supported in ChillShell ---

    override fun hardwareAttestationKeySupported(): Boolean = false

    override fun hardwareAttestationKeyCreate(): String {
        throw Exception("not supported")
    }

    override fun hardwareAttestationKeyRelease(id: String) {
        throw Exception("not supported")
    }

    override fun hardwareAttestationKeyPublic(id: String): ByteArray {
        throw Exception("not supported")
    }

    override fun hardwareAttestationKeySign(id: String, data: ByteArray): ByteArray {
        throw Exception("not supported")
    }

    override fun hardwareAttestationKeyLoad(id: String) {
        throw Exception("not supported")
    }

    // --- Encrypted SharedPreferences (cached instance) ---

    @Volatile
    private var cachedEncryptedPrefs: SharedPreferences? = null

    private fun getEncryptedPrefs(): SharedPreferences {
        cachedEncryptedPrefs?.let { return it }
        val ctx = context ?: throw IllegalStateException("No context")
        val masterKey = MasterKey.Builder(ctx)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        val prefs = EncryptedSharedPreferences.create(
            ctx,
            ENCRYPTED_PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
        cachedEncryptedPrefs = prefs
        return prefs
    }
}
