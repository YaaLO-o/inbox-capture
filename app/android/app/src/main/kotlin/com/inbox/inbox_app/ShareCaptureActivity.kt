package com.inbox.inbox_app

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

class ShareCaptureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val request = ShareIntentParser(contentResolver).parse(intent)
        if (request == null) {
            showResult(success = false)
            return
        }

        AndroidCaptureBridge.capture(
            mapOf(
                "source" to "share",
                "text" to request.text,
                "attachments" to emptyList<Map<String, Any?>>(),
            ),
        ) { result ->
            runOnUiThread { showResult(success = result["status"] == "saved") }
        }
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
