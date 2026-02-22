package com.prootlauncher

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.prootlauncher.databinding.ActivitySetupGuideBinding

class SetupGuideActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val binding = ActivitySetupGuideBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setSupportActionBar(binding.toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        binding.tvGuideContent.text = buildGuideText()
    }

    override fun onSupportNavigateUp(): Boolean {
        onBackPressedDispatcher.onBackPressed()
        return true
    }

    private fun buildGuideText(): String {
        return """
PROOT LAUNCHER — SETUP GUIDE
═══════════════════════════════

STEP 1: Install Termux
───────────────────────
• Install Termux from F-Droid (NOT Play Store)
  https://f-droid.org/en/packages/com.termux/
• The Play Store version is outdated and will not work.

STEP 2: Configure Termux for External Apps
──────────────────────────────────────────
Open Termux and run:
  mkdir -p ~/.termux
  echo "allow-external-apps=true" >> ~/.termux/termux.properties

Then restart Termux completely (swipe away from recent apps).

STEP 3: Install Proot + Ubuntu via Andronix
──────────────────────────────────────────
• Install Andronix from Play Store
• Choose Ubuntu 22.04 with XFCE desktop
• Follow Andronix instructions to set up proot
• This creates a start script (usually start-ubuntu22.sh)

STEP 4: VNC Server Setup (in Termux)
─────────────────────────────────────
In Termux (not proot):
  pkg update && pkg upgrade
  pkg install x11-repo
  pkg install tigervnc

STEP 5: Install VNC Viewer
──────────────────────────
Install AVNC (recommended):
  • F-Droid: https://f-droid.org/en/packages/com.gaurav.avnc/
  • Play Store: Search "AVNC"

Why AVNC?
  • Open source and free
  • Supports vnc:// URI for auto-connect
  • Better for automated workflows than RealVNC

STEP 6: Test VNC Manually
──────────────────────────
In Termux:
  1. Start proot:  ./start-ubuntu22.sh
  2. Start VNC:    vncserver-start
  3. Note the display number (usually :1 = port 5901)

In AVNC:
  1. Add new server: localhost:5901
  2. Connect
  3. You should see the XFCE desktop

STEP 7: Run the Installer (Inside VNC)
───────────────────────────────────────
Once you can see the XFCE desktop in AVNC:
  1. Open a terminal in XFCE
  2. Clone the repo or download install.sh
  3. Run: sudo bash install.sh
  4. Follow the interactive prompts

STEP 8: Configure Proot Launcher
─────────────────────────────────
In this app's Settings:
  • Set your proot start script path
    (default: ./start-ubuntu22.sh)
  • Set VNC display (default: :1)
  • Set VNC resolution (default: 1920x1080)
  • Adjust connection delay if needed

STEP 9: One-Tap Launch!
───────────────────────
Tap "Start Proot Env" on the main screen.
The app will:
  1. Launch Termux
  2. Start your proot environment
  3. Start the VNC server
  4. Auto-open AVNC and connect

TROUBLESHOOTING
═══════════════

VNC Shows Black Screen
  → In Termux: vncserver-stop && vncserver-start

Can't Connect to VNC
  → Check display number matches settings
  → Default: display :1 = port 5901

Termux Command Fails
  → Make sure allow-external-apps=true is set
  → Restart Termux after changing properties

AVNC Won't Auto-Connect
  → First connect manually and save the server
  → Then auto-connect from this app should work

Proot Script Not Found
  → Check Settings → Proot start script path
  → Common names: start-ubuntu22.sh, ubuntu.sh
  → Must be in Termux home directory

RealVNC Setup (if using instead of AVNC)
  → Create saved connection: localhost:5901
  → Set authentication to VNC password
  → Manual connect required (can't auto-launch reliably)
        """.trimIndent()
    }
}
