package com.inbox.inbox_app

private typealias CaptureRequest = (
    Map<String, Any?>,
    (Map<String, Any?>) -> Unit,
) -> Unit

internal class ShareCaptureCoordinator(
    private val capture: CaptureRequest,
    private val onOutcome: (Boolean) -> Unit,
) {
    private var completed = false

    fun submit(request: ShareRequest) {
        capture(
            mapOf(
                "source" to "share",
                "text" to request.text,
                "attachments" to emptyList<Map<String, Any?>>(),
            ),
            ::complete,
        )
    }

    fun reject() {
        complete(mapOf("status" to "error"))
    }

    private fun complete(result: Map<String, Any?>) {
        if (completed) return
        completed = true
        onOutcome(result["status"] == "saved")
    }
}
