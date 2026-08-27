package com.inbox.inbox_app

import org.junit.Assert.assertEquals
import org.junit.Test

class ShareCaptureCoordinatorTest {
    private val request = ShareRequest("https://example.com", emptyList())

    @Test
    fun successfulResult_emitsOneSuccessOutcome() {
        val outcomes = mutableListOf<Boolean>()
        val coordinator = ShareCaptureCoordinator(
            capture = { _, callback ->
                callback(mapOf("status" to "saved"))
                callback(mapOf("status" to "error"))
            },
            onOutcome = outcomes::add,
        )

        coordinator.submit(request)

        assertEquals(listOf(true), outcomes)
    }

    @Test
    fun bridgeError_emitsOneErrorOutcome() {
        val outcomes = mutableListOf<Boolean>()
        val coordinator = ShareCaptureCoordinator(
            capture = { _, callback -> callback(mapOf("status" to "error")) },
            onOutcome = outcomes::add,
        )

        coordinator.submit(request)

        assertEquals(listOf(false), outcomes)
    }

    @Test
    fun tenSecondReadinessTimeout_emitsOneErrorOutcome() {
        val outcomes = mutableListOf<Boolean>()
        val coordinator = ShareCaptureCoordinator(
            capture = { _, callback ->
                callback(
                    mapOf(
                        "status" to "error",
                        "message" to "Capture core readiness timed out",
                    ),
                )
            },
            onOutcome = outcomes::add,
        )

        coordinator.submit(request)

        assertEquals(listOf(false), outcomes)
    }
}
