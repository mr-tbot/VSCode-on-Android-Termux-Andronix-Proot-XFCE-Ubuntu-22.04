package com.prootlauncher

import android.os.Bundle
import androidx.preference.EditTextPreference
import androidx.preference.ListPreference
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.SwitchPreferenceCompat

class SettingsFragment : PreferenceFragmentCompat() {

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.preferences, rootKey)

        // Set up summary providers for text preferences
        findPreference<EditTextPreference>(ProotPreferences.KEY_PROOT_START_SCRIPT)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_VNC_DISPLAY)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_VNC_RESOLUTION)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_VNC_START_CMD)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_VNC_STOP_CMD)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_VNC_CONNECTION_DELAY)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<ListPreference>(ProotPreferences.KEY_VNC_VIEWER_PACKAGE)?.apply {
            summaryProvider = ListPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_PRE_START_CMD)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_POST_START_CMD)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_CUSTOM_ENV_VARS)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }

        findPreference<EditTextPreference>(ProotPreferences.KEY_PROOT_START_CUSTOM_CMD)?.apply {
            summaryProvider = EditTextPreference.SimpleSummaryProvider.getInstance()
        }
    }
}
