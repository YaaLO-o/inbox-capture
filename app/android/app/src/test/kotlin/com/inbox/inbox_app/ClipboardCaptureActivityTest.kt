package com.inbox.inbox_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ClipboardCaptureActivityTest {
    @Test
    fun readsOnceOnlyAfterFocus() {
        var reads = 0
        val submitted = mutableListOf<Map<String, Any?>>()
        val finished = mutableListOf<String>()
        val probe = ClipboardCaptureProbe(
            read = {
                reads += 1
                ClipboardProbeRead(1, "known text")
            },
            capture = { request, callback ->
                submitted += request
                callback(mapOf("status" to "saved"))
            },
            finish = finished::add,
        )

        probe.onWindowFocusChanged(false)
        probe.onWindowFocusChanged(true)
        probe.onWindowFocusChanged(false)
        probe.onWindowFocusChanged(true)

        assertEquals(1, reads)
        assertEquals(
            mapOf("source" to "clipboard", "text" to "known text", "attachments" to emptyList<Any>()),
            submitted.single(),
        )
        assertEquals(listOf("saved"), finished)
    }

    @Test
    fun blankOrEmptyClipboardFinishesWithoutBridgeSubmission() {
        val submissions = mutableListOf<Map<String, Any?>>()
        val outcomes = mutableListOf<String>()
        val probe = ClipboardCaptureProbe(
            read = { ClipboardProbeRead(0, "   ") },
            capture = { request, _ -> submissions += request },
            finish = outcomes::add,
        )

        probe.onWindowFocusChanged(true)

        assertTrue(submissions.isEmpty())
        assertEquals(listOf("empty"), outcomes)
    }

    @Test
    fun bridgeResultIsReportedAndFinishesOnce() {
        val outcomes = mutableListOf<String>()
        val probe = ClipboardCaptureProbe(
            read = { ClipboardProbeRead(1, "text") },
            capture = { _, callback ->
                callback(mapOf("status" to "error"))
                callback(mapOf("status" to "saved"))
            },
            finish = outcomes::add,
        )

        probe.onWindowFocusChanged(true)

        assertEquals(listOf("error"), outcomes)
    }
}
