package com.inbox.inbox_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
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
    }

    override fun onPause() {
        (application as InboxApplication).vaultBridge.detachActivity(this)
        super.onPause()
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

    private companion object {
        const val VAULT_PICKER_REQUEST = 5001
    }
}
