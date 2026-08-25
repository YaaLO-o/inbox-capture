package com.inbox.inbox_app

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

open class ShareCaptureActivity : Activity() {
    private lateinit var coordinator: ShareCaptureCoordinator

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        coordinator = ShareCaptureCoordinator({ request, callback ->
            submitCapture(request, callback)
        }) { success ->
            runOnUiThread { onCaptureOutcome(success) }
        }

        val request = ShareIntentParser(contentResolver).parse(intent)
        if (request == null) {
            coordinator.reject()
            return
        }

        coordinator.submit(request)
    }

    protected open fun submitCapture(
        request: Map<String, Any?>,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        val override = ShareCaptureActivityTestHooks.capture
        if (override == null) {
            AndroidCaptureBridge.capture(request, callback)
        } else {
            override(request, callback)
        }
    }

    protected open fun onCaptureOutcome(success: Boolean) {
        ShareCaptureActivityTestHooks.outcome?.invoke(success)
        Toast.makeText(
            this,
            getString(if (success) R.string.share_capture_success else R.string.share_capture_error),
            Toast.LENGTH_SHORT,
        ).show()
        ShareCaptureActivityTestHooks.finish?.invoke()
        finish()
    }
}
