package com.vibeterm.vibeterm

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * Flutter plugin bridging Tailscale native operations via MethodChannel.
 *
 * Exposed methods:
 * - login: starts OAuth flow and VPN tunnel
 * - logout: stops tunnel and clears state
 * - getStatus: returns connection status map
 * - getMyIP: returns Tailscale IP (100.x.y.z)
 *
 * Requires libtailscale.aar to be present in android/app/libs/.
 * Build it from https://github.com/tailscale/tailscale-android with:
 *   gomobile bind -target android -androidapi 26 -o libtailscale.aar ./libtailscale
 */
class TailscalePlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "TailscalePlugin"
        private const val CHANNEL_NAME = "com.chillshell.tailscale"
        private const val VPN_PERMISSION_REQUEST_CODE = 9001
        private const val PREFS_NAME = "tailscale_prefs"
        private const val KEY_AUTH_TOKEN = "auth_token"
        private const val KEY_TAILSCALE_IP = "tailscale_ip"
        private const val KEY_DEVICE_NAME = "device_name"
        private const val KEY_IS_CONNECTED = "is_connected"
    }

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingLoginResult: Result? = null

    // --- FlutterPlugin lifecycle ---

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        Log.d(TAG, "TailscalePlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
        Log.d(TAG, "TailscalePlugin detached from engine")
    }

    // --- ActivityAware lifecycle ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- MethodCallHandler ---

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "login" -> handleLogin(result)
            "logout" -> handleLogout(result)
            "getStatus" -> handleGetStatus(result)
            "getMyIP" -> handleGetMyIP(result)
            else -> result.notImplemented()
        }
    }

    // --- Login ---

    private fun handleLogin(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available for VPN permission", null)
            return
        }

        // Step 1: Check VPN permission
        val vpnIntent = VpnService.prepare(currentActivity)
        if (vpnIntent != null) {
            // Need to request VPN permission first
            pendingLoginResult = result
            currentActivity.startActivityForResult(vpnIntent, VPN_PERMISSION_REQUEST_CODE)
            return
        }

        // VPN permission already granted, proceed with Tailscale login
        startTailscaleLogin(result)
    }

    private fun startTailscaleLogin(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        try {
            // Start the VPN service
            val serviceIntent = Intent(ctx, TailscaleVpnService::class.java).apply {
                action = TailscaleVpnService.ACTION_START
            }
            ctx.startForegroundService(serviceIntent)

            // TODO: When libtailscale.aar is integrated, this will:
            // 1. Initialize the Tailscale backend via libtailscale
            // 2. Start the OAuth login flow (opens browser/webview)
            // 3. Receive the auth token callback
            // 4. Establish the WireGuard tunnel
            //
            // For now, we signal that the native layer is ready and
            // the Dart side should handle OAuth via the Tailscale API.

            Log.d(TAG, "Tailscale VPN service started, awaiting OAuth from Dart layer")

            result.success(mapOf(
                "status" to "vpn_service_started",
                "message" to "VPN service started. Complete OAuth via Dart layer."
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Tailscale login", e)
            result.error("LOGIN_FAILED", e.message, null)
        }
    }

    // --- Logout ---

    private fun handleLogout(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        try {
            // Stop the VPN service
            val serviceIntent = Intent(ctx, TailscaleVpnService::class.java).apply {
                action = TailscaleVpnService.ACTION_STOP
            }
            ctx.startService(serviceIntent)

            // Clear stored auth state
            val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .remove(KEY_AUTH_TOKEN)
                .remove(KEY_TAILSCALE_IP)
                .remove(KEY_DEVICE_NAME)
                .putBoolean(KEY_IS_CONNECTED, false)
                .apply()

            Log.d(TAG, "Tailscale logout complete")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to logout", e)
            result.error("LOGOUT_FAILED", e.message, null)
        }
    }

    // --- Status ---

    private fun handleGetStatus(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isConnected = prefs.getBoolean(KEY_IS_CONNECTED, false)
        val myIP = prefs.getString(KEY_TAILSCALE_IP, null)
        val deviceName = prefs.getString(KEY_DEVICE_NAME, null)

        result.success(mapOf(
            "isConnected" to isConnected,
            "myIP" to myIP,
            "deviceName" to deviceName,
            "vpnServiceRunning" to TailscaleVpnService.isRunning
        ))
    }

    // --- Get IP ---

    private fun handleGetMyIP(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ip = prefs.getString(KEY_TAILSCALE_IP, null)
        if (ip != null) {
            result.success(ip)
        } else {
            result.error("NOT_CONNECTED", "No Tailscale IP available. Not connected.", null)
        }
    }

    // --- VPN permission result ---

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val result = pendingLoginResult
            pendingLoginResult = null

            if (resultCode == Activity.RESULT_OK) {
                if (result != null) {
                    startTailscaleLogin(result)
                }
            } else {
                result?.error(
                    "VPN_PERMISSION_DENIED",
                    "User denied VPN permission",
                    null
                )
            }
            return true
        }
        return false
    }

    // --- State updates from VPN service ---

    /**
     * Called by TailscaleVpnService when the tunnel state changes.
     * Updates stored preferences so getStatus returns current values.
     */
    fun updateConnectionState(isConnected: Boolean, ip: String?, deviceName: String?) {
        val ctx = context ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_IS_CONNECTED, isConnected)
            .apply {
                if (ip != null) putString(KEY_TAILSCALE_IP, ip)
                if (deviceName != null) putString(KEY_DEVICE_NAME, deviceName)
            }
            .apply()

        // Notify Flutter side of state change
        activity?.runOnUiThread {
            channel.invokeMethod("onStateChanged", mapOf(
                "isConnected" to isConnected,
                "myIP" to ip,
                "deviceName" to deviceName
            ))
        }
    }
}
