package com.prootlauncher

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.prootlauncher.databinding.ActivityMainBinding
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: ProotPreferences
    private lateinit var termuxHelper: TermuxHelper
    private lateinit var vncHelper: VncHelper

    private var isRunning = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setSupportActionBar(binding.toolbar)

        prefs = ProotPreferences(this)
        termuxHelper = TermuxHelper(this)
        vncHelper = VncHelper(this)

        // Show setup guide on first launch
        if (prefs.isFirstLaunch) {
            showFirstLaunchDialog()
            prefs.isFirstLaunch = false
        }

        setupButtons()
        updateUI()
    }

    override fun onResume() {
        super.onResume()
        updateUI()
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.action_settings -> {
                startActivity(Intent(this, SettingsActivity::class.java))
                true
            }
            R.id.action_setup_guide -> {
                startActivity(Intent(this, SetupGuideActivity::class.java))
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun setupButtons() {
        binding.btnStart.setOnClickListener { startProotEnvironment() }
        binding.btnStop.setOnClickListener { stopProotEnvironment() }
        binding.btnVncOnly.setOnClickListener { openVncOnly() }
    }

    private fun startProotEnvironment() {
        // Validate Termux is installed
        if (!termuxHelper.isTermuxInstalled()) {
            showTermuxNotInstalledDialog()
            return
        }

        // Validate VNC viewer is installed
        if (!vncHelper.isVncViewerInstalled()) {
            showVncViewerNotInstalledDialog()
            return
        }

        binding.btnStart.isEnabled = false
        binding.progressBar.visibility = View.VISIBLE
        binding.tvStatus.text = getString(R.string.status_starting)

        // Step 1: Launch Termux and start proot
        val startScript = prefs.buildStartCommand()
        termuxHelper.executeCommand(startScript)

        // Step 2: Wait for VNC server to start, then launch VNC viewer
        val delayMs = prefs.vncConnectionDelay * 1000L
        handler.postDelayed({
            if (prefs.autoConnectVnc) {
                vncHelper.launchVncViewer(
                    host = "localhost",
                    port = prefs.vncPort
                )
            }

            isRunning = true
            prefs.lastStartTime = System.currentTimeMillis()
            updateUI()
            binding.progressBar.visibility = View.GONE
            binding.btnStart.isEnabled = true

            Toast.makeText(this, R.string.toast_started, Toast.LENGTH_SHORT).show()
        }, delayMs)
    }

    private fun stopProotEnvironment() {
        binding.btnStop.isEnabled = false
        binding.progressBar.visibility = View.VISIBLE
        binding.tvStatus.text = getString(R.string.status_stopping)

        // Send stop commands to Termux
        val stopScript = prefs.buildStopCommand()
        termuxHelper.executeCommand(stopScript)

        handler.postDelayed({
            isRunning = false
            updateUI()
            binding.progressBar.visibility = View.GONE
            binding.btnStop.isEnabled = true

            Toast.makeText(this, R.string.toast_stopped, Toast.LENGTH_SHORT).show()
        }, 3000)
    }

    private fun openVncOnly() {
        if (!vncHelper.isVncViewerInstalled()) {
            showVncViewerNotInstalledDialog()
            return
        }

        vncHelper.launchVncViewer(
            host = "localhost",
            port = prefs.vncPort
        )
    }

    private fun updateUI() {
        if (isRunning) {
            binding.tvStatus.text = getString(R.string.status_running)
            binding.statusIndicator.setBackgroundResource(R.drawable.status_running)
            binding.btnStop.isEnabled = true
        } else {
            binding.tvStatus.text = getString(R.string.status_stopped)
            binding.statusIndicator.setBackgroundResource(R.drawable.status_stopped)
        }

        // Show connection info
        binding.tvVncInfo.text = getString(
            R.string.vnc_info_format,
            prefs.vncDisplay,
            prefs.vncPort,
            prefs.vncResolution
        )

        // Show last started time
        val lastStart = prefs.lastStartTime
        if (lastStart > 0) {
            val sdf = SimpleDateFormat("h:mm a", Locale.getDefault())
            binding.tvLastStarted.text = getString(
                R.string.last_started_format,
                sdf.format(Date(lastStart))
            )
            binding.tvLastStarted.visibility = View.VISIBLE
        } else {
            binding.tvLastStarted.visibility = View.GONE
        }

        // Check if required apps are installed
        val termuxOk = termuxHelper.isTermuxInstalled()
        val vncOk = vncHelper.isVncViewerInstalled()
        if (!termuxOk || !vncOk) {
            binding.tvWarnings.visibility = View.VISIBLE
            val warnings = mutableListOf<String>()
            if (!termuxOk) warnings.add("• Termux is not installed")
            if (!vncOk) warnings.add("• No VNC viewer found (install AVNC)")
            binding.tvWarnings.text = warnings.joinToString("\n")
        } else {
            binding.tvWarnings.visibility = View.GONE
        }
    }

    private fun showFirstLaunchDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.welcome_title)
            .setMessage(R.string.welcome_message)
            .setPositiveButton(R.string.setup_guide) { _, _ ->
                startActivity(Intent(this, SetupGuideActivity::class.java))
            }
            .setNegativeButton(R.string.later, null)
            .show()
    }

    private fun showTermuxNotInstalledDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.termux_required_title)
            .setMessage(R.string.termux_required_message)
            .setPositiveButton(R.string.open_fdroid) { _, _ ->
                termuxHelper.openTermuxInstallPage()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showVncViewerNotInstalledDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.vnc_required_title)
            .setMessage(R.string.vnc_required_message)
            .setPositiveButton(R.string.install_avnc) { _, _ ->
                vncHelper.openAvncInstallPage()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}
