package com.inbox.inbox_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

data class PickedVault(val uri: Uri, val flags: Int)

class MainActivity : FlutterActivity() {
    private var vaultPickerCallback: ((PickedVault?) -> Unit)? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as InboxApplication).engine

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        (application as InboxApplication).vaultBridge.attachActivity(this)
        // If the overlay permission was revoked while we were backgrounded,
        // bring the service down so the bubble never violates that state.
        if (OverlayService.isRunning && !canDrawOverlays()) {
            OverlayService.stop(this)
        }
        (application as InboxApplication).vaultBridge.notifyOverlayStateChanged()
    }

    override fun onPause() {
        (application as InboxApplication).vaultBridge.detachActivity(this)
        super.onPause()
    }

    private fun canDrawOverlays(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }

    fun launchVaultPicker(callback: (PickedVault?) -> Unit): Boolean {
        if (vaultPickerCallback != null) return false
        vaultPickerCallback = callback
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            },
            VAULT_PICKER_REQUEST,
        )
        return true
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VAULT_PICKER_REQUEST) return
        val callback = vaultPickerCallback ?: return
        vaultPickerCallback = null
        val uri = data?.data
        callback(
            if (resultCode == Activity.RESULT_OK && uri != null) {
                PickedVault(uri, data.flags)
            } else {
                null
            },
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            (application as InboxApplication).vaultBridge.notifyOverlayStateChanged()
        }
    }

    companion object {
        const val VAULT_PICKER_REQUEST = 5001
        const val NOTIFICATION_PERMISSION_REQUEST = 5002
    }
}
