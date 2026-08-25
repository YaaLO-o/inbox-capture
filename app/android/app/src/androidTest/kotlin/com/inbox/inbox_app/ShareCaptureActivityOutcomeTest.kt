package com.inbox.inbox_app

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareCaptureActivityOutcomeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val targetContext = instrumentation.targetContext
    private lateinit var messenger: ShareCaptureFakeMessenger
    private lateinit var lifecycle: ActivityLifecycleProbe

    @Before
    fun setUp() {
        messenger = ShareCaptureFakeMessenger()
        AndroidCaptureBridge.attach(messenger)
        lifecycle = ActivityLifecycleProbe(targetContext.applicationContext as Application)
        lifecycle.register()
    }

    @After
    fun tearDown() {
        lifecycle.unregister()
        val application = targetContext.applicationContext as InboxApplication
        AndroidCaptureBridge.attach(application.engine.dartExecutor.binaryMessenger)
    }

    @Test
    fun successFeedbackFinishesActivityExactlyOnce() {
        messenger.mode = FakeShareMode.SUCCESS
        messenger.ready()
        val scenario = launchScenario()

        assertDestroyed(scenario, 3, TimeUnit.SECONDS)
        assertEquals(1, messenger.captureCount)
        assertEquals(1, lifecycle.destroyedCount)
    }

    @Test
    fun bridgeErrorFeedbackFinishesActivityExactlyOnce() {
        messenger.mode = FakeShareMode.ERROR
        messenger.ready()
        val scenario = launchScenario()

        assertDestroyed(scenario, 3, TimeUnit.SECONDS)
        assertEquals(1, messenger.captureCount)
        assertEquals(1, lifecycle.destroyedCount)
    }

    @Test
    fun productionBridgeCoordinatorTimeoutFinishesActivityExactlyOnce() {
        messenger.mode = FakeShareMode.TIMEOUT
        val startedAt = System.nanoTime()
        val scenario = launchScenario()

        assertFalse(lifecycle.destroyed.await(9_500, TimeUnit.MILLISECONDS))
        assertTrue(lifecycle.destroyed.await(3, TimeUnit.SECONDS))
        val elapsedMillis = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAt)

        assertTrue(elapsedMillis >= 10_000)
        assertEquals(androidx.lifecycle.Lifecycle.State.DESTROYED, scenario.state)
        assertEquals(0, messenger.captureCount)
        assertEquals(1, lifecycle.destroyedCount)
    }

    @Test
    fun duplicateBridgeCallbacksStillProduceOneFeedbackAndFinish() {
        messenger.mode = FakeShareMode.DUPLICATE
        messenger.ready()
        val scenario = launchScenario()

        assertDestroyed(scenario, 3, TimeUnit.SECONDS)
        assertEquals(1, messenger.captureCount)
        assertEquals(1, lifecycle.destroyedCount)
    }

    private fun launchScenario(): ActivityScenario<ShareCaptureActivity> =
        ActivityScenario.launch(
            Intent(targetContext, ShareCaptureActivity::class.java).apply {
                action = Intent.ACTION_SEND
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, "https://example.com/activity-test")
            },
        )

    private fun assertDestroyed(
        scenario: ActivityScenario<ShareCaptureActivity>,
        timeout: Long,
        unit: TimeUnit,
    ) {
        assertTrue(lifecycle.destroyed.await(timeout, unit))
        assertEquals(androidx.lifecycle.Lifecycle.State.DESTROYED, scenario.state)
    }
}

private enum class FakeShareMode {
    SUCCESS,
    ERROR,
    TIMEOUT,
    DUPLICATE,
}

private class ShareCaptureFakeMessenger : BinaryMessenger {
    private val codec = StandardMethodCodec.INSTANCE
    private var incoming: BinaryMessenger.BinaryMessageHandler? = null
    var mode = FakeShareMode.TIMEOUT
    var captureCount = 0

    fun ready() {
        val handler = checkNotNull(incoming)
        handler.onMessage(codec.encodeMethodCall(MethodCall("coreReady", null)).flipped()) { }
    }

    override fun send(channel: String, message: ByteBuffer?) {
        send(channel, message, null)
    }

    override fun send(
        channel: String,
        message: ByteBuffer?,
        callback: BinaryMessenger.BinaryReply?,
    ) {
        val call = codec.decodeMethodCall(message!!.flipped())
        if (call.method != "capture") return
        captureCount += 1
        val args = call.arguments as Map<*, *>
        val taskId = args["taskId"] as String
        val result = when (mode) {
            FakeShareMode.SUCCESS,
            FakeShareMode.DUPLICATE,
            -> mapOf("status" to "saved", "taskId" to taskId)
            FakeShareMode.ERROR -> mapOf("status" to "error", "taskId" to taskId)
            FakeShareMode.TIMEOUT -> return
        }
        checkNotNull(callback).reply(codec.encodeSuccessEnvelope(result).flipped())
        if (mode == FakeShareMode.DUPLICATE) {
            callback.reply(codec.encodeSuccessEnvelope(mapOf("status" to "error", "taskId" to taskId)).flipped())
        }
    }

    override fun setMessageHandler(
        channel: String,
        handler: BinaryMessenger.BinaryMessageHandler?,
    ) {
        incoming = handler
    }
}

private class ActivityLifecycleProbe(
    private val application: Application,
) : Application.ActivityLifecycleCallbacks {
    val destroyed = CountDownLatch(1)
    var destroyedCount = 0

    fun register() = application.registerActivityLifecycleCallbacks(this)

    fun unregister() = application.unregisterActivityLifecycleCallbacks(this)

    override fun onActivityDestroyed(activity: Activity) {
        if (activity is ShareCaptureActivity) {
            destroyedCount += 1
            destroyed.countDown()
        }
    }

    override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
    override fun onActivityStarted(activity: Activity) = Unit
    override fun onActivityResumed(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivityStopped(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
}

private fun ByteBuffer.flipped(): ByteBuffer = apply { flip() }
