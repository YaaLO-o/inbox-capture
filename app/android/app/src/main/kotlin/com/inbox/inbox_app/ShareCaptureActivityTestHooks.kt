package com.inbox.inbox_app

internal object ShareCaptureActivityTestHooks {
    var capture: ((Map<String, Any?>, (Map<String, Any?>) -> Unit) -> Unit)? = null
    var outcome: ((Boolean) -> Unit)? = null
    var finish: (() -> Unit)? = null

    fun reset() {
        capture = null
        outcome = null
        finish = null
    }
}
