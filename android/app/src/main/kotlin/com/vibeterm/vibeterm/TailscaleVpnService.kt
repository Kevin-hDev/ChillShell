package com.vibeterm.vibeterm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.UUID

/**
 * VPN service implementing the libtailscale.IPNService interface.
 *
 * Go calls methods on this service to build and establish the VPN tunnel.
 * The service runs in the foreground with a persistent notification.
 */
class TailscaleVpnService : VpnService(), libtailscale.IPNService {

    companion object {
        private const val TAG = "TailscaleVpnService"
        private const val NOTIFICATION_CHANNEL_ID = "tailscale_vpn"
        private const val NOTIFICATION_ID = 9002

        const val ACTION_START = "com.chillshell.tailscale.START"
        const val ACTION_STOP = "com.chillshell.tailscale.STOP"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private val serviceId: String = UUID.randomUUID().toString()

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

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked by user")
        stopVpn()
    }

    // --- libtailscale.IPNService interface ---

    override fun id(): String = serviceId

    override fun protect(fd: Int): Boolean {
        return super.protect(fd)
    }

    override fun newBuilder(): libtailscale.VPNServiceBuilder {
        val b = Builder()
            .setSession("ChillShell Tailscale")
            .allowFamily(android.system.OsConstants.AF_INET)
            .allowFamily(android.system.OsConstants.AF_INET6)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            b.setMetered(false)
        }

        return VPNServiceBuilderWrapper(b)
    }

    override fun updateVpnStatus(active: Boolean) {
        isRunning = active
        if (active) {
            updateNotification("Tailscale actif")
        }
        // Notify the Flutter plugin of state change
        TailscalePlugin.instance?.onVpnStateChanged(active)
    }

    override fun close() {
        stopVpn()
        libtailscale.Libtailscale.serviceDisconnect(this)
    }

    override fun disconnectVPN() {
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

        // Request VPN from Go backend — Go will call back newBuilder() + establish()
        libtailscale.Libtailscale.requestVPN(this)

        Log.d(TAG, "VPN service started, tunnel requested from libtailscale")
    }

    private fun stopVpn() {
        if (!isRunning) return
        isRunning = false
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
}

/**
 * Wrapper around Android's VpnService.Builder that implements the
 * libtailscale.VPNServiceBuilder Go interface.
 */
class VPNServiceBuilderWrapper(
    private val builder: VpnService.Builder
) : libtailscale.VPNServiceBuilder {

    override fun addAddress(addr: String, prefixLen: Int) {
        builder.addAddress(addr, prefixLen)
    }

    override fun addDNSServer(server: String) {
        builder.addDnsServer(server)
    }

    override fun addRoute(route: String, prefixLen: Int) {
        builder.addRoute(route, prefixLen)
    }

    override fun addSearchDomain(domain: String) {
        builder.addSearchDomain(domain)
    }

    override fun excludeRoute(route: String, prefixLen: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val prefix = android.net.IpPrefix(java.net.InetAddress.getByName(route), prefixLen)
            builder.excludeRoute(prefix)
        }
    }

    override fun setMTU(mtu: Int) {
        builder.setMtu(mtu)
    }

    override fun establish(): libtailscale.ParcelFileDescriptor? {
        val pfd = builder.establish() ?: return null
        return ParcelFileDescriptorWrapper(pfd)
    }
}

/**
 * Wrapper for Android ParcelFileDescriptor implementing the Go interface.
 */
class ParcelFileDescriptorWrapper(
    private val pfd: android.os.ParcelFileDescriptor
) : libtailscale.ParcelFileDescriptor {

    override fun detach(): Int {
        return pfd.detachFd()
    }
}
