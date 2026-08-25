package com.inbox.inbox_app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AndroidCaptureBridgeTest {
    private lateinit var messenger: RecordingBinaryMessenger
    private lateinit var scheduler: FakeCaptureScheduler
    private lateinit var bridge: AndroidCaptureBridgeCoordinator
    private var nextTaskId = 0

    @Before
    fun setUp() {
        messenger = RecordingBinaryMessenger()
        scheduler = FakeCaptureScheduler()
        bridge = AndroidCaptureBridgeCoordinator(
            MethodChannel(messenger, CHANNEL_NAME),
            scheduler,
        ) { "task-${++nextTaskId}" }
    }

    @Test
    fun `pre-ready requests drain to Dart in FIFO order`() {
        bridge.capture(mapOf("text" to "first")) {}
        bridge.capture(mapOf("text" to "second")) {}
        bridge.capture(mapOf("text" to "third")) {}

        assertTrue(messenger.outgoingCalls.isEmpty())

        messenger.callFromDart("coreReady")

        assertEquals(
            listOf("first", "second", "third"),
            messenger.outgoingCalls.map { it.arguments.stringMap()["text"] },
        )
        assertEquals(
            listOf("task-1", "task-2", "task-3"),
            messenger.outgoingCalls.map { it.arguments.stringMap()["taskId"] },
        )
    }

    @Test
    fun `ten second timeout completes and removes queued request`() {
        val results = mutableListOf<Map<String, Any?>>()
        bridge.capture(mapOf("text" to "late"), results::add)

        scheduler.advanceBy(9_999)
        assertTrue(results.isEmpty())
        scheduler.advanceBy(1)

        assertEquals(
            listOf(
                mapOf(
                    "status" to "error",
                    "message" to "Capture core readiness timed out",
                    "taskId" to "task-1",
                ),
            ),
            results,
        )

        messenger.callFromDart("coreReady")
        assertTrue(messenger.outgoingCalls.isEmpty())
    }

    @Test
    fun `successful Flutter result reaches callback once`() {
        val results = readyCapture()
        val taskId = messenger.taskIdAt(0)

        messenger.replySuccess(
            0,
            mapOf("status" to "saved", "captureId" to "capture-1", "taskId" to taskId),
        )
        messenger.replySuccess(0, mapOf("status" to "error", "taskId" to taskId))

        assertEquals(
            listOf(
                mapOf("status" to "saved", "captureId" to "capture-1", "taskId" to taskId),
            ),
            results,
        )
    }

    @Test
    fun `Flutter error maps to one native error result`() {
        val results = readyCapture()

        messenger.replyError(0, "capture_failed", "write denied")

        assertEquals(
            listOf(
                mapOf(
                    "status" to "error",
                    "message" to "write denied",
                    "taskId" to messenger.taskIdAt(0),
                ),
            ),
            results,
        )
    }

    @Test
    fun `not implemented maps to one native error result`() {
        val results = readyCapture()

        messenger.replyNotImplemented(0)

        assertEquals(
            listOf(
                mapOf(
                    "status" to "error",
                    "message" to "Capture method unavailable",
                    "taskId" to messenger.taskIdAt(0),
                ),
            ),
            results,
        )
    }

    @Test
    fun `invalid Flutter result maps to native error`() {
        val results = readyCapture()

        messenger.replySuccess(0, "not-a-map")

        assertEquals("error", results.single()["status"])
        assertEquals("Invalid capture response", results.single()["message"])
        assertEquals(messenger.taskIdAt(0), results.single()["taskId"])
    }

    @Test
    fun `mismatched taskId maps to native error`() {
        val results = readyCapture()

        messenger.replySuccess(0, mapOf("status" to "saved", "taskId" to "another-task"))

        assertEquals("error", results.single()["status"])
        assertEquals("Invalid capture response", results.single()["message"])
        assertEquals(messenger.taskIdAt(0), results.single()["taskId"])
    }

    @Test
    fun `ready wins timeout race and late duplicate result cannot complete twice`() {
        val results = mutableListOf<Map<String, Any?>>()
        bridge.capture(mapOf("text" to "queued"), results::add)

        messenger.callFromDart("coreReady")
        scheduler.advanceBy(10_000)
        assertTrue(results.isEmpty())

        val taskId = messenger.taskIdAt(0)
        messenger.replySuccess(0, mapOf("status" to "saved", "taskId" to taskId))
        messenger.replyError(0, "late_error", "too late")

        assertEquals(listOf(mapOf("status" to "saved", "taskId" to taskId)), results)
    }

    private fun readyCapture(): MutableList<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        messenger.callFromDart("coreReady")
        bridge.capture(mapOf("text" to "hello"), results::add)
        return results
    }

    private companion object {
        const val CHANNEL_NAME = "com.inbox.app/android_capture"
    }
}

private class FakeCaptureScheduler : CaptureScheduler {
    private data class Scheduled(
        val dueAt: Long,
        val action: () -> Unit,
        var cancelled: Boolean = false,
    )

    private val scheduled = mutableListOf<Scheduled>()
    private var now = 0L

    override fun runOnMain(action: () -> Unit) = action()

    override fun schedule(delayMillis: Long, action: () -> Unit): ScheduledCaptureTask {
        val task = Scheduled(now + delayMillis, action)
        scheduled.add(task)
        return ScheduledCaptureTask { task.cancelled = true }
    }

    fun advanceBy(millis: Long) {
        now += millis
        scheduled
            .filter { !it.cancelled && it.dueAt <= now }
            .sortedBy { it.dueAt }
            .forEach {
                it.cancelled = true
                it.action()
            }
    }
}

private class RecordingBinaryMessenger : BinaryMessenger {
    private val codec = StandardMethodCodec.INSTANCE
    private var incomingHandler: BinaryMessenger.BinaryMessageHandler? = null
    val outgoingCalls = mutableListOf<MethodCall>()
    private val outgoingReplies = mutableListOf<BinaryMessenger.BinaryReply?>()

    override fun send(channel: String, message: ByteBuffer?) {
        send(channel, message, null)
    }

    override fun send(
        channel: String,
        message: ByteBuffer?,
        callback: BinaryMessenger.BinaryReply?,
    ) {
        assertEquals("com.inbox.app/android_capture", channel)
        outgoingCalls.add(codec.decodeMethodCall(message!!.flipped()))
        outgoingReplies.add(callback)
    }

    override fun setMessageHandler(
        channel: String,
        handler: BinaryMessenger.BinaryMessageHandler?,
    ) {
        assertEquals("com.inbox.app/android_capture", channel)
        incomingHandler = handler
    }

    fun callFromDart(method: String) {
        val handler = checkNotNull(incomingHandler)
        handler.onMessage(
            codec.encodeMethodCall(MethodCall(method, null)).flipped(),
        ) {}
    }

    fun taskIdAt(index: Int): String =
        outgoingCalls[index].arguments.stringMap()["taskId"] as String

    fun replySuccess(index: Int, value: Any?) {
        checkNotNull(outgoingReplies[index]).reply(
            codec.encodeSuccessEnvelope(value).flipped(),
        )
    }

    fun replyError(index: Int, code: String, message: String) {
        checkNotNull(outgoingReplies[index]).reply(
            codec.encodeErrorEnvelope(code, message, null).flipped(),
        )
    }

    fun replyNotImplemented(index: Int) {
        checkNotNull(outgoingReplies[index]).reply(null)
    }
}

private fun Any?.stringMap(): Map<*, *> = this as Map<*, *>

private fun ByteBuffer.flipped(): ByteBuffer = apply { flip() }
