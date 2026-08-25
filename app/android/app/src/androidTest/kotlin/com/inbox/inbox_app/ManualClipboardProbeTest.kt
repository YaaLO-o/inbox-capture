package com.inbox.inbox_app

import android.content.Intent
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.concurrent.TimeUnit
import org.junit.Assume.assumeTrue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * App-owned manual harness for the real clipboard probe. It is deliberately skipped unless
 * invoked with `-e manualClipboardProbe true`; normal connected tests must not consume the
 * user's current clipboard or launch a transient production Activity.
 */
@RunWith(AndroidJUnit4::class)
class ManualClipboardProbeTest {
    @Test
    fun launchesRealClipboardActivityAndWaitsForExit() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(arguments.getString("manualClipboardProbe") == "true")

        val targetContext = InstrumentationRegistry.getInstrumentation().targetContext
        val scenario: ActivityScenario<ClipboardCaptureActivity> = ActivityScenario.launch(
            Intent(targetContext, ClipboardCaptureActivity::class.java),
        )

        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(20)
        while (scenario.state != androidx.lifecycle.Lifecycle.State.DESTROYED &&
            System.nanoTime() < deadline
        ) {
            Thread.sleep(100)
        }

        assertEquals(androidx.lifecycle.Lifecycle.State.DESTROYED, scenario.state)
        assertTrue("clipboard probe did not finish within 20 seconds", System.nanoTime() < deadline)
    }
}
