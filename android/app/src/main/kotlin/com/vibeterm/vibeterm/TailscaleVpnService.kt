package com.vibeterm.vibeterm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Android VpnService that manages the Tailscale WireGuard tunnel.
 *
 * This service:
 * - Runs as a foreground service with a persistent notification
 * - Establishes and maintains the VPN tunnel via libtailscale
 * - Handles start/stop lifecycle from TailscalePlugin
 *
 * When libtailscale.aar is integrated, this service will implement
 * the IPNService and VPNServiceBuilder interfaces from the Go library.
 */
class TailscaleVpnService : VpnService() {

    companion object {
        private const val TAG = "TailscaleVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "tailscale_vpn"
        private const val NOTIFICATION_ID = 9002

        const val ACTION_START = "com.chillshell.tailscale.START"
        const val ACTION_STOP = "com.chillshell.tailscale.STOP"

        /** Whether the VPN service is currently running. */
        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "TailscaleVpnService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startVpn()
            ACTION_STOP -> stopVpn()
            else -> Log.w(TAG, "Unknown action: ${intent?.action}")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
        Log.d(TAG, "TailscaleVpnService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onRevoke() {
        // Called when the user revokes VPN permission from system settings
        Log.w(TAG, "VPN permission revoked by user")
        stopVpn()
    }

    // --- VPN lifecycle ---

    private fun startVpn() {
        if (isRunning) {
            Log.d(TAG, "VPN already running, ignoring start request")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification("Connexion en cours..."),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification("Connexion en cours..."))
        }
        isRunning = true

        // TODO: When libtailscale.aar is integrated:
        // 1. Create a VpnService.Builder to configure the tunnel
        //    builder.setMtu(1280)
        //    builder.addAddress("100.x.y.z", 32)
        //    builder.addRoute("100.64.0.0", 10)  // Tailscale CGNAT range
        //    builder.addDnsServer(...)
        //    builder.establish()
        //
        // 2. Pass the ParcelFileDescriptor to libtailscale
        // 3. Start the WireGuard engine
        //
        // For now, the service runs as a placeholder foreground service
        // ready to be connected with the Go library.

        Log.d(TAG, "VPN service started (awaiting libtailscale integration)")
        updateNotification("Tailscale actif")
    }

    private fun stopVpn() {
        if (!isRunning) return

        isRunning = false

        // TODO: When libtailscale.aar is integrated:
        // 1. Shut down the WireGuard engine
        // 2. Close the VPN tunnel file descriptor
        // 3. Notify the Go backend of disconnect

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "VPN service stopped")
    }

    // --- Notification ---

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Tailscale VPN",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Notification for active Tailscale VPN connection"
            setShowBadge(false)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("ChillShell VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setShowWhen(false)
            .apply {
                if (pendingIntent != null) setContentIntent(pendingIntent)
            }
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    // --- VPN Builder helpers (for libtailscale integration) ---

    /**
     * Creates a configured VPN tunnel. Called by libtailscale when the
     * WireGuard handshake completes and the tunnel parameters are known.
     *
     * @param mtu The MTU for the tunnel (typically 1280)
     * @param addresses List of Tailscale IPs to assign (e.g. "100.64.0.1/32")
     * @param routes List of routes to send through the tunnel
     * @param dnsServers List of DNS server IPs
     * @return The tunnel file descriptor, or null on failure
     */
    fun configureTunnel(
        mtu: Int,
        addresses: List<String>,
        routes: List<String>,
        dnsServers: List<String>
    ): android.os.ParcelFileDescriptor? {
        val builder = Builder()
        builder.setMtu(mtu)

        for (addr in addresses) {
            val parts = addr.split("/")
            val ip = parts[0]
            val prefix = parts.getOrNull(1)?.toIntOrNull() ?: 32
            builder.addAddress(ip, prefix)
        }

        for (route in routes) {
            val parts = route.split("/")
            val ip = parts[0]
            val prefix = parts.getOrNull(1)?.toIntOrNull() ?: 32
            builder.addRoute(ip, prefix)
        }

        for (dns in dnsServers) {
            builder.addDnsServer(dns)
        }

        builder.setSession("ChillShell Tailscale")

        return try {
            builder.establish()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN tunnel", e)
            null
        }
    }
}
