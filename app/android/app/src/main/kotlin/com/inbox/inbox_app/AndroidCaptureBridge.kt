package com.inbox.inbox_app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

object AndroidCaptureBridge {
    private const val CHANNEL_NAME = "com.inbox.app/android_capture"
    private var coordinator: AndroidCaptureBridgeCoordinator? = null

    fun attach(messenger: BinaryMessenger) {
        coordinator = AndroidCaptureBridgeCoordinator(
            MethodChannel(messenger, CHANNEL_NAME),
            AndroidMainCaptureScheduler(),
            { UUID.randomUUID().toString() },
        )
    }

    fun capture(
        arguments: Map<String, Any?>,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        val attachedCoordinator = coordinator
        if (attachedCoordinator == null) {
            callback(
                captureErrorResult(
                    UUID.randomUUID().toString(),
                    "Capture channel unavailable",
                ),
            )
            return
        }
        attachedCoordinator.capture(arguments, callback)
    }
}

internal fun interface ScheduledCaptureTask {
    fun cancel()
}

internal interface CaptureScheduler {
    fun runOnMain(action: () -> Unit)

    fun schedule(delayMillis: Long, action: () -> Unit): ScheduledCaptureTask
}

private class AndroidMainCaptureScheduler : CaptureScheduler {
    private val handler = Handler(Looper.getMainLooper())

    override fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            handler.post(action)
        }
    }

    override fun schedule(
        delayMillis: Long,
        action: () -> Unit,
    ): ScheduledCaptureTask {
        val runnable = Runnable(action)
        handler.postDelayed(runnable, delayMillis)
        return ScheduledCaptureTask { handler.removeCallbacks(runnable) }
    }
}

internal class AndroidCaptureBridgeCoordinator(
    private val channel: MethodChannel,
    private val scheduler: CaptureScheduler,
    private val taskIdGenerator: () -> String,
) {
    private val pending = mutableListOf<PendingRequest>()
    private var ready = false

    init {
        channel.setMethodCallHandler(::handleDartCall)
    }

    fun capture(
        arguments: Map<String, Any?>,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        val taskId = taskIdGenerator()
        val requestArguments = arguments.toMutableMap().apply {
            this["taskId"] = taskId
        }
        val request = PendingRequest(taskId, requestArguments, callback)
        scheduler.runOnMain { captureOnMain(request) }
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
            request.timeout?.cancel()
            send(request)
        }
    }

    private fun captureOnMain(request: PendingRequest) {
        if (ready) {
            send(request)
            return
        }

        pending.add(request)
        request.timeout = scheduler.schedule(QUEUED_TIMEOUT_MILLIS) {
            if (pending.remove(request)) {
                request.complete(
                    captureErrorResult(
                        request.taskId,
                        "Capture core readiness timed out",
                    ),
                )
            }
        }
    }

    private fun send(request: PendingRequest) {
        try {
            channel.invokeMethod(
                "capture",
                request.arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val response = result.toStringKeyMap()
                        if (response == null || response["taskId"] != request.taskId) {
                            request.complete(
                                captureErrorResult(
                                    request.taskId,
                                    "Invalid capture response",
                                ),
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
                            captureErrorResult(
                                request.taskId,
                                errorMessage ?: errorCode,
                            ),
                        )
                    }

                    override fun notImplemented() {
                        request.complete(
                            captureErrorResult(
                                request.taskId,
                                "Capture method unavailable",
                            ),
                        )
                    }
                },
            )
        } catch (error: RuntimeException) {
            request.complete(
                captureErrorResult(
                    request.taskId,
                    error.message ?: "Capture channel failed",
                ),
            )
        }
    }

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
        var timeout: ScheduledCaptureTask? = null
        private var completed = false

        fun complete(result: Map<String, Any?>) {
            if (completed) return
            completed = true
            callback(result)
        }
    }

    private companion object {
        const val QUEUED_TIMEOUT_MILLIS = 10_000L
    }
}

private fun captureErrorResult(
    taskId: String,
    message: String,
): Map<String, Any?> =
    mapOf(
        "status" to "error",
        "message" to message,
        "taskId" to taskId,
    )
