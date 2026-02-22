package com.prootlauncher

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

/**
 * Handles all Termux interaction via RUN_COMMAND intent.
 *
 * Requirements:
 * - Termux must be installed (from F-Droid, NOT Play Store)
 * - In Termux, run: termux-setup-storage
 * - Edit ~/.termux/termux.properties and set: allow-external-apps=true
 * - Restart Termux after changing properties
 *
 * The RUN_COMMAND intent sends a bash command to Termux for execution.
 * This is the same mechanism used by Termux:Tasker but doesn't require
 * the paid add-on — just the allow-external-apps property.
 */
class TermuxHelper(private val context: Context) {

    companion object {
        const val TERMUX_PACKAGE = "com.termux"
        const val TERMUX_RUN_COMMAND_SERVICE = "com.termux.app.RunCommandService"
        const val TERMUX_RUN_COMMAND_ACTION = "com.termux.RUN_COMMAND"
        const val TERMUX_ACTIVITY = "com.termux.app.TermuxActivity"

        // Intent extras for RUN_COMMAND
        const val EXTRA_COMMAND_PATH = "com.termux.RUN_COMMAND_PATH"
        const val EXTRA_ARGUMENTS = "com.termux.RUN_COMMAND_ARGUMENTS"
        const val EXTRA_WORKDIR = "com.termux.RUN_COMMAND_WORKDIR"
        const val EXTRA_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND"
        const val EXTRA_SESSION_ACTION = "com.termux.RUN_COMMAND_SESSION_ACTION"

        const val FDROID_TERMUX_URL = "https://f-droid.org/en/packages/com.termux/"
    }

    /**
     * Check if Termux is installed on the device.
     */
    fun isTermuxInstalled(): Boolean {
        return try {
            context.packageManager.getPackageInfo(TERMUX_PACKAGE, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Execute a command inside Termux.
     *
     * This sends a RUN_COMMAND intent to Termux's service.
     * The command runs in a new Termux session (visible to user).
     *
     * @param command The full bash command to execute
     * @param background If true, runs in background (no visible session)
     */
    fun executeCommand(command: String, background: Boolean = false) {
        // First, make sure Termux is open/running
        launchTermux()

        // Then send the command via RUN_COMMAND intent
        val intent = Intent(TERMUX_RUN_COMMAND_ACTION).apply {
            setClassName(TERMUX_PACKAGE, TERMUX_RUN_COMMAND_SERVICE)
            putExtra(EXTRA_COMMAND_PATH, "/data/data/com.termux/files/usr/bin/bash")
            putExtra(EXTRA_ARGUMENTS, arrayOf("-c", command))
            putExtra(EXTRA_WORKDIR, "/data/data/com.termux/files/home")
            putExtra(EXTRA_BACKGROUND, background)
            // Session action: 0 = new session, 1 = switch to session, 2 = background
            putExtra(EXTRA_SESSION_ACTION, if (background) 2 else 0)
        }

        try {
            context.startService(intent)
        } catch (e: Exception) {
            // If service start fails, try launching Termux activity directly
            // with the command embedded
            launchTermuxWithFallback(command)
        }
    }

    /**
     * Launch the Termux app (bring to foreground / start if not running).
     */
    fun launchTermux() {
        val intent = Intent().apply {
            setClassName(TERMUX_PACKAGE, TERMUX_ACTIVITY)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Termux not installed or can't be launched
        }
    }

    /**
     * Fallback method: launch Termux activity and attempt to pass command.
     * Less reliable than RUN_COMMAND but works without allow-external-apps.
     */
    private fun launchTermuxWithFallback(command: String) {
        val intent = Intent().apply {
            setClassName(TERMUX_PACKAGE, TERMUX_ACTIVITY)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // Termux doesn't officially support passing commands via activity intent
            // but we launch it so the user can manually type the command
            // The RUN_COMMAND service is the proper way.
        }
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // Termux not available
        }
    }

    /**
     * Open F-Droid page to install Termux.
     */
    fun openTermuxInstallPage() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(FDROID_TERMUX_URL)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
