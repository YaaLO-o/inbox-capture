package com.inbox.inbox_app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

object AndroidCaptureBridge {
    private const val CHANNEL_NAME = "com.inbox.app/android_capture"
    private const val QUEUED_TIMEOUT_MILLIS = 10_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<PendingRequest>()
    private var channel: MethodChannel? = null
    private var ready = false

    fun attach(messenger: BinaryMessenger) {
        ready = false
        channel = MethodChannel(messenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleDartCall)
        }
    }

    fun capture(
        arguments: Map<String, Any?>,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        val taskId = UUID.randomUUID().toString()
        val requestArguments = arguments.toMutableMap().apply {
            this["taskId"] = taskId
        }
        val request = PendingRequest(taskId, requestArguments, callback)
        if (Looper.myLooper() == Looper.getMainLooper()) {
            captureOnMain(request)
        } else {
            mainHandler.post { captureOnMain(request) }
        }
    }

    private fun handleDartCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "coreReady") {
            result.notImplemented()
            return
        }

        ready = true
        result.success(null)
        val queued = pending.toList()
        pending.clear()
        queued.forEach { request ->
            mainHandler.removeCallbacks(request.timeout)
            send(request)
        }
    }

    private fun captureOnMain(request: PendingRequest) {
        if (ready) {
            send(request)
            return
        }

        request.timeout = Runnable {
            if (pending.remove(request)) {
                request.complete(
                    errorResult(request.taskId, "Capture core readiness timed out"),
                )
            }
        }
        pending.add(request)
        mainHandler.postDelayed(request.timeout, QUEUED_TIMEOUT_MILLIS)
    }

    private fun send(request: PendingRequest) {
        val attachedChannel = channel
        if (attachedChannel == null) {
            request.complete(errorResult(request.taskId, "Capture channel unavailable"))
            return
        }

        try {
            attachedChannel.invokeMethod(
                "capture",
                request.arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val response = result.toStringKeyMap()
                        if (response == null || response["taskId"] != request.taskId) {
                            request.complete(
                                errorResult(request.taskId, "Invalid capture response"),
                            )
                            return
                        }
                        request.complete(response)
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        request.complete(
                            errorResult(request.taskId, errorMessage ?: errorCode),
                        )
                    }

                    override fun notImplemented() {
                        request.complete(
                            errorResult(request.taskId, "Capture method unavailable"),
                        )
                    }
                },
            )
        } catch (error: RuntimeException) {
            request.complete(
                errorResult(request.taskId, error.message ?: "Capture channel failed"),
            )
        }
    }

    private fun errorResult(taskId: String, message: String): Map<String, Any?> =
        mapOf(
            "status" to "error",
            "message" to message,
            "taskId" to taskId,
        )

    private fun Any?.toStringKeyMap(): Map<String, Any?>? {
        if (this !is Map<*, *>) return null
        val mapped = mutableMapOf<String, Any?>()
        for ((key, value) in this) {
            if (key !is String) return null
            mapped[key] = value
        }
        return mapped
    }

    private class PendingRequest(
        val taskId: String,
        val arguments: Map<String, Any?>,
        private val callback: (Map<String, Any?>) -> Unit,
    ) {
        lateinit var timeout: Runnable
        private var completed = false

        fun complete(result: Map<String, Any?>) {
            if (completed) return
            completed = true
            callback(result)
        }
    }
}
