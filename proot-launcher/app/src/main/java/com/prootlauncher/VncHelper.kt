package com.prootlauncher

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

/**
 * Handles VNC viewer launching and management.
 *
 * Supports multiple VNC viewers with preference for AVNC:
 *
 * AVNC (recommended):
 *   - Open source (GPL), available on F-Droid and Play Store
 *   - Supports vnc:// URI scheme for programmatic launching
 *   - Can auto-connect to saved servers
 *   - Best integration for automated workflows
 *
 * bVNC:
 *   - Open source, supports intent-based connections
 *   - Available on Play Store and F-Droid
 *
 * RealVNC Viewer:
 *   - Popular but closed-source
 *   - Does NOT reliably support vnc:// URI scheme
 *   - Harder to auto-configure programmatically
 *   - Can be launched but may not auto-connect
 */
class VncHelper(private val context: Context) {

    companion object {
        // Supported VNC viewer packages
        const val AVNC_PACKAGE = "com.gaurav.avnc"
        const val BVNC_PACKAGE = "com.iiordanov.bVNC"
        const val REALVNC_PACKAGE = "com.realvnc.viewer.android"
        const val MULTIVNC_PACKAGE = "com.coboltforge.dontmind.multivnc"

        // Install URLs
        const val AVNC_FDROID_URL = "https://f-droid.org/en/packages/com.gaurav.avnc/"
        const val AVNC_PLAY_URL = "https://play.google.com/store/apps/details?id=com.gaurav.avnc"

        val SUPPORTED_VIEWERS = listOf(
            AVNC_PACKAGE,
            BVNC_PACKAGE,
            REALVNC_PACKAGE,
            MULTIVNC_PACKAGE
        )
    }

    /**
     * Check if any supported VNC viewer is installed.
     */
    fun isVncViewerInstalled(): Boolean {
        return getInstalledViewer() != null
    }

    /**
     * Get the package name of the first installed VNC viewer.
     * Preference order: AVNC > bVNC > RealVNC > MultiVNC
     */
    fun getInstalledViewer(): String? {
        for (pkg in SUPPORTED_VIEWERS) {
            if (isPackageInstalled(pkg)) return pkg
        }
        return null
    }

    /**
     * Launch VNC viewer and connect to the specified host/port.
     *
     * Uses vnc:// URI scheme which is supported by AVNC and most VNC viewers.
     * The URI format is: vnc://host:port
     *
     * For AVNC specifically, this will:
     * 1. Open the app
     * 2. Auto-connect to the specified server
     * 3. If the server is saved, it uses those settings
     *
     * @param host Hostname or IP (usually "localhost" for local proot)
     * @param port VNC port (e.g., 5901 for display :1)
     */
    fun launchVncViewer(host: String, port: Int) {
        val installedViewer = getInstalledViewer()

        when (installedViewer) {
            AVNC_PACKAGE -> launchAvnc(host, port)
            BVNC_PACKAGE -> launchBvnc(host, port)
            REALVNC_PACKAGE -> launchRealVnc(host, port)
            else -> launchGenericVnc(host, port)
        }
    }

    /**
     * Launch AVNC with vnc:// URI.
     * AVNC fully supports this and will auto-connect.
     */
    private fun launchAvnc(host: String, port: Int) {
        val uri = Uri.parse("vnc://$host:$port")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(AVNC_PACKAGE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Fallback to generic VNC URI
            launchGenericVnc(host, port)
        }
    }

    /**
     * Launch bVNC with connection parameters.
     */
    private fun launchBvnc(host: String, port: Int) {
        val uri = Uri.parse("vnc://$host:$port")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(BVNC_PACKAGE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            launchGenericVnc(host, port)
        }
    }

    /**
     * Launch RealVNC Viewer.
     * RealVNC doesn't reliably support vnc:// URIs,
     * so we just launch the app and the user connects manually.
     */
    private fun launchRealVnc(host: String, port: Int) {
        // Try vnc:// URI first
        val uri = Uri.parse("vnc://$host:$port")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(REALVNC_PACKAGE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Just launch the app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(REALVNC_PACKAGE)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launchIntent)
            }
        }
    }

    /**
     * Generic VNC launch using vnc:// URI scheme.
     * This will open whatever app handles vnc:// URIs.
     */
    private fun launchGenericVnc(host: String, port: Int) {
        val uri = Uri.parse("vnc://$host:$port")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // No VNC handler available
        }
    }

    /**
     * Open the AVNC install page on F-Droid.
     */
    fun openAvncInstallPage() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(AVNC_FDROID_URL)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Try Play Store
            val playIntent = Intent(Intent.ACTION_VIEW, Uri.parse(AVNC_PLAY_URL)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(playIntent)
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
