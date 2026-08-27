package com.inbox.inbox_app

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

internal data class ClipboardProbeRead(val count: Int, val text: String?)

internal class ClipboardCaptureProbe(
    private val read: () -> ClipboardProbeRead,
    private val capture: (Map<String, Any?>, (Map<String, Any?>) -> Unit) -> Unit,
    private val finish: (String) -> Unit,
) {
    private val attempted = AtomicBoolean(false)
    private val completed = AtomicBoolean(false)

    fun onWindowFocusChanged(hasFocus: Boolean) {
        if (!hasFocus || !attempted.compareAndSet(false, true)) return
        val clipboard = try {
            read()
        } catch (_: RuntimeException) {
            complete("error")
            return
        }
        if (clipboard.text.isNullOrBlank()) {
            complete("empty")
            return
        }
        capture(
            mapOf(
                "source" to "clipboard",
                "text" to clipboard.text,
                "attachments" to emptyList<Any>(),
            ),
        ) { result ->
            complete(result["status"]?.toString() ?: "error")
        }
    }

    private fun complete(status: String) {
        if (completed.compareAndSet(false, true)) finish(status)
    }
}

class ClipboardCaptureActivity : Activity() {
    private lateinit var probe: ClipboardCaptureProbe

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "start")
        probe = ClipboardCaptureProbe(
            read = ::readClipboard,
            capture = AndroidCaptureBridge::capture,
            finish = { status ->
                Log.d(TAG, "bridge status=$status")
                forwardResultToOverlay(status)
                finish()
            },
        )
    }

    private fun forwardResultToOverlay(status: String) {
        if (!OverlayService.isRunning) return
        try {
            startService(
                Intent(this, OverlayService::class.java)
                    .setAction(OverlayService.ACTION_CAPTURE_RESULT)
                    .putExtra("status", status),
            )
        } catch (t: Throwable) {
            // The overlay may have stopped between the check and the send; this
            // is a non-fatal UI hint and must never break the capture flow.
            Log.w(TAG, "Failed to forward capture result to overlay", t)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        Log.d(TAG, "focus")
        probe.onWindowFocusChanged(true)
    }

    private fun readClipboard(): ClipboardProbeRead {
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = manager.primaryClip
        val count = clip?.itemCount ?: 0
        Log.d(TAG, "clip count=$count")
        val text = clip?.getItemAt(0)?.coerceToText(this)?.toString()
        Log.d(TAG, "non-empty=${!text.isNullOrBlank()}")
        return ClipboardProbeRead(count, text)
    }

    companion object {
        private const val TAG = "INboxClipboardProbe"

        fun launch(context: Context) {
            context.startActivity(
                Intent(context, ClipboardCaptureActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }
}
