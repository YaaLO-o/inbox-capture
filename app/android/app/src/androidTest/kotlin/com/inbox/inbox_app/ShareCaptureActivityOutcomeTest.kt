package com.inbox.inbox_app

import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareCaptureActivityOutcomeTest {
    private val outcomes = mutableListOf<Boolean>()
    private var finishes = 0

    @Before
    fun setUp() {
        ShareCaptureActivityTestHooks.reset()
        ShareCaptureActivityTestHooks.outcome = outcomes::add
        ShareCaptureActivityTestHooks.finish = { finishes += 1 }
    }

    @After
    fun tearDown() {
        ShareCaptureActivityTestHooks.reset()
    }

    @Test
    fun successFeedbackFinishesActivityExactlyOnce() {
        ShareCaptureActivityTestHooks.capture = { _, callback ->
            callback(mapOf("status" to "saved"))
        }
        val scenario = launchScenario()
        awaitDestroyed(scenario, 2, TimeUnit.SECONDS)
        assertEquals(listOf(true), outcomes)
        assertEquals(1, finishes)
    }

    @Test
    fun bridgeErrorFeedbackFinishesActivityExactlyOnce() {
        ShareCaptureActivityTestHooks.capture = { _, callback ->
            callback(mapOf("status" to "error"))
        }
        val scenario = launchScenario()
        awaitDestroyed(scenario, 2, TimeUnit.SECONDS)
        assertEquals(listOf(false), outcomes)
        assertEquals(1, finishes)
    }

    @Test
    fun tenSecondTimeoutFeedbackFinishesActivityExactlyOnce() {
        ShareCaptureActivityTestHooks.capture = { _, callback ->
            Handler(Looper.getMainLooper()).postDelayed(
                { callback(mapOf("status" to "error", "message" to "Capture core readiness timed out")) },
                10_000L,
            )
        }
        val scenario = launchScenario()
        awaitDestroyed(scenario, 12, TimeUnit.SECONDS)
        assertEquals(listOf(false), outcomes)
        assertEquals(1, finishes)
    }

    @Test
    fun duplicateBridgeCallbacksStillProduceOneFeedbackAndFinish() {
        ShareCaptureActivityTestHooks.capture = { _, callback ->
            callback(mapOf("status" to "saved"))
            callback(mapOf("status" to "error"))
        }
        val scenario = launchScenario()
        awaitDestroyed(scenario, 2, TimeUnit.SECONDS)
        assertEquals(listOf(true), outcomes)
        assertEquals(1, finishes)
    }

    private fun launchScenario(): ActivityScenario<ShareCaptureActivity> =
        ActivityScenario.launch(
            Intent(
                ApplicationProvider.getApplicationContext(),
                ShareCaptureActivity::class.java,
            ).apply {
                action = Intent.ACTION_SEND
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, "https://example.com/activity-test")
            },
        )

    private fun awaitDestroyed(
        scenario: ActivityScenario<ShareCaptureActivity>,
        timeout: Long,
        unit: TimeUnit,
    ) {
        val deadline = System.nanoTime() + unit.toNanos(timeout)
        while (scenario.state != androidx.lifecycle.Lifecycle.State.DESTROYED &&
            System.nanoTime() < deadline
        ) {
            Thread.sleep(50)
        }
        assertTrue(scenario.state == androidx.lifecycle.Lifecycle.State.DESTROYED)
    }
}
