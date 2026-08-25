package com.inbox.inbox_app

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

class ShareCaptureActivity : Activity() {
    private lateinit var coordinator: ShareCaptureCoordinator

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        coordinator = ShareCaptureCoordinator(AndroidCaptureBridge::capture) { success ->
            runOnUiThread { showResult(success) }
        }

        val request = ShareIntentParser(contentResolver).parse(intent)
        if (request == null) {
            coordinator.reject()
            return
        }

        coordinator.submit(request)
    }

    private fun showResult(success: Boolean) {
        Toast.makeText(
            this,
            getString(if (success) R.string.share_capture_success else R.string.share_capture_error),
            Toast.LENGTH_SHORT,
        ).show()
        finish()
    }
}
