package com.prootlauncher

import android.content.Context
import android.content.SharedPreferences
import androidx.preference.PreferenceManager

/**
 * Manages all user preferences for the proot launcher.
 * Provides typed access to SharedPreferences values with sensible defaults.
 */
class ProotPreferences(context: Context) {

    private val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context)

    companion object {
        // Keys
        const val KEY_FIRST_LAUNCH = "first_launch"
        const val KEY_LAST_START_TIME = "last_start_time"

        // Termux
        const val KEY_PROOT_START_SCRIPT = "proot_start_script"
        const val KEY_PROOT_START_CUSTOM_CMD = "proot_start_custom_cmd"

        // VNC Server
        const val KEY_VNC_DISPLAY = "vnc_display"
        const val KEY_VNC_RESOLUTION = "vnc_resolution"
        const val KEY_VNC_START_CMD = "vnc_start_cmd"
        const val KEY_VNC_STOP_CMD = "vnc_stop_cmd"

        // VNC Viewer
        const val KEY_AUTO_CONNECT_VNC = "auto_connect_vnc"
        const val KEY_VNC_CONNECTION_DELAY = "vnc_connection_delay"
        const val KEY_VNC_VIEWER_PACKAGE = "vnc_viewer_package"

        // Advanced
        const val KEY_PRE_START_CMD = "pre_start_cmd"
        const val KEY_POST_START_CMD = "post_start_cmd"
        const val KEY_CUSTOM_ENV_VARS = "custom_env_vars"

        // Defaults
        const val DEFAULT_PROOT_SCRIPT = "./start-ubuntu22.sh"
        const val DEFAULT_VNC_DISPLAY = ":1"
        const val DEFAULT_VNC_RESOLUTION = "1920x1080"
        const val DEFAULT_VNC_START_CMD = "vncserver-start"
        const val DEFAULT_VNC_STOP_CMD = "vncserver-stop"
        const val DEFAULT_VNC_DELAY = 5
    }

    // ── First launch ─────────────────────────────────────────────────────────

    var isFirstLaunch: Boolean
        get() = prefs.getBoolean(KEY_FIRST_LAUNCH, true)
        set(value) = prefs.edit().putBoolean(KEY_FIRST_LAUNCH, value).apply()

    var lastStartTime: Long
        get() = prefs.getLong(KEY_LAST_START_TIME, 0)
        set(value) = prefs.edit().putLong(KEY_LAST_START_TIME, value).apply()

    // ── Proot settings ───────────────────────────────────────────────────────

    val prootStartScript: String
        get() = prefs.getString(KEY_PROOT_START_SCRIPT, DEFAULT_PROOT_SCRIPT) ?: DEFAULT_PROOT_SCRIPT

    val prootStartCustomCmd: String
        get() = prefs.getString(KEY_PROOT_START_CUSTOM_CMD, "") ?: ""

    // ── VNC server settings ──────────────────────────────────────────────────

    val vncDisplay: String
        get() = prefs.getString(KEY_VNC_DISPLAY, DEFAULT_VNC_DISPLAY) ?: DEFAULT_VNC_DISPLAY

    val vncResolution: String
        get() = prefs.getString(KEY_VNC_RESOLUTION, DEFAULT_VNC_RESOLUTION) ?: DEFAULT_VNC_RESOLUTION

    val vncStartCmd: String
        get() = prefs.getString(KEY_VNC_START_CMD, DEFAULT_VNC_START_CMD) ?: DEFAULT_VNC_START_CMD

    val vncStopCmd: String
        get() = prefs.getString(KEY_VNC_STOP_CMD, DEFAULT_VNC_STOP_CMD) ?: DEFAULT_VNC_STOP_CMD

    /** Derived: VNC port from display number (e.g., :1 -> 5901, :2 -> 5902) */
    val vncPort: Int
        get() {
            val displayNum = vncDisplay.removePrefix(":").toIntOrNull() ?: 1
            return 5900 + displayNum
        }

    // ── VNC viewer settings ──────────────────────────────────────────────────

    val autoConnectVnc: Boolean
        get() = prefs.getBoolean(KEY_AUTO_CONNECT_VNC, true)

    val vncConnectionDelay: Int
        get() = prefs.getString(KEY_VNC_CONNECTION_DELAY, DEFAULT_VNC_DELAY.toString())
            ?.toIntOrNull() ?: DEFAULT_VNC_DELAY

    val vncViewerPackage: String
        get() = prefs.getString(KEY_VNC_VIEWER_PACKAGE, VncHelper.AVNC_PACKAGE)
            ?: VncHelper.AVNC_PACKAGE

    // ── Advanced settings ────────────────────────────────────────────────────

    val preStartCmd: String
        get() = prefs.getString(KEY_PRE_START_CMD, "") ?: ""

    val postStartCmd: String
        get() = prefs.getString(KEY_POST_START_CMD, "") ?: ""

    val customEnvVars: String
        get() = prefs.getString(KEY_CUSTOM_ENV_VARS, "") ?: ""

    // ── Command builders ─────────────────────────────────────────────────────

    /**
     * Build the full start command that will be sent to Termux.
     *
     * The command:
     * 1. Runs any pre-start commands
     * 2. Starts the proot environment
     * 3. Inside proot, starts the VNC server with configured resolution
     * 4. Runs any post-start commands
     *
     * The proot start script is expected to leave the user in a proot shell,
     * so subsequent commands run inside proot.
     */
    fun buildStartCommand(): String {
        val parts = mutableListOf<String>()

        // Custom environment variables
        if (customEnvVars.isNotBlank()) {
            parts.add(customEnvVars)
        }

        // Pre-start command
        if (preStartCmd.isNotBlank()) {
            parts.add(preStartCmd)
        }

        // Build the proot command that starts proot and runs VNC inside it
        // The proot start script typically drops you into a bash shell.
        // We chain the VNC start command to run after proot initializes.
        val vncCmd = buildString {
            append(vncStartCmd)
            // Some VNC servers accept resolution as argument
            if (vncResolution.isNotBlank()) {
                append(" ")
                // Try to pass resolution - different VNC servers handle this differently
                // TigerVNC in Termux: vncserver-start takes no args, resolution is separate
                // But custom commands may accept it
            }
        }

        if (prootStartCustomCmd.isNotBlank()) {
            // User has a fully custom start command
            parts.add(prootStartCustomCmd)
        } else {
            // Default: run proot script, then VNC start
            // We create a compound command that:
            // 1. Starts proot
            // 2. Inside proot, starts VNC
            parts.add("${prootStartScript} -- $vncCmd")
        }

        // Post-start command
        if (postStartCmd.isNotBlank()) {
            parts.add(postStartCmd)
        }

        return parts.joinToString(" && ")
    }

    /**
     * Build the stop command that will be sent to Termux.
     *
     * The command:
     * 1. Runs VNC stop command inside proot
     * 2. Exits proot
     */
    fun buildStopCommand(): String {
        return "${prootStartScript} -- ${vncStopCmd}; exit"
    }
}
