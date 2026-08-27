package com.inbox.inbox_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OverlayPositionerTest {
    private val positioner = OverlayPositioner

    @Test
    fun nearestEdgeX_snapsLeftWhenNearLeft() {
        assertEquals(0, positioner.nearestEdgeX(x = 100, screenWidth = 1080, bubbleWidth = 48))
    }

    @Test
    fun nearestEdgeX_snapsRightWhenNearRight() {
        assertEquals(1032, positioner.nearestEdgeX(x = 900, screenWidth = 1080, bubbleWidth = 48))
    }

    @Test
    fun nearestEdgeX_honorsStatusAndNavigationInsets() {
        // Simulate a 40px left inset (status/navigation cutout) and a 60px right
        // gesture-bar inset: the left snap target must start after the inset and
        // the right snap target must end before the inset.
        val left = positioner.nearestEdgeX(
            x = 10,
            screenWidth = 1080,
            bubbleWidth = 48,
            leftInset = 40,
            rightInset = 60,
        )
        assertEquals(40, left)

        val right = positioner.nearestEdgeX(
            x = 1000,
            screenWidth = 1080,
            bubbleWidth = 48,
            leftInset = 40,
            rightInset = 60,
        )
        assertEquals(1080 - 60 - 48, right)
    }

    @Test
    fun nearestEdgeX_reclampsAfterRotationToSmallerDisplay() {
        // A bubble saved against a 1080px-wide display at the right edge (x=1032)
        // must be clamped into the new 720px-wide display after rotation.
        val clamped = positioner.nearestEdgeX(
            x = 1032,
            screenWidth = 720,
            bubbleWidth = 48,
        )
        // 1032 is closer to the right of the 720 screen than to the left, so it
        // snaps right at 720 - 48.
        assertEquals(720 - 48, clamped)
    }

    @Test
    fun clampY_staysWithinSafeArea() {
        val topInset = 80
        val bottomInset = 120
        val screenHeight = 2400
        val bubbleHeight = 48

        // Above the top inset is clamped down to the safe top edge.
        assertEquals(
            topInset,
            positioner.clampY(
                y = 0,
                topInset = topInset,
                bottomInset = bottomInset,
                screenHeight = screenHeight,
                bubbleHeight = bubbleHeight,
            ),
        )

        // Below the bottom inset is clamped up to the safe bottom edge.
        assertEquals(
            screenHeight - bottomInset - bubbleHeight,
            positioner.clampY(
                y = 2500,
                topInset = topInset,
                bottomInset = bottomInset,
                screenHeight = screenHeight,
                bubbleHeight = bubbleHeight,
            ),
        )

        // A value already in the safe area is unchanged.
        val inside = 1200
        assertEquals(
            inside,
            positioner.clampY(
                y = inside,
                topInset = topInset,
                bottomInset = bottomInset,
                screenHeight = screenHeight,
                bubbleHeight = bubbleHeight,
            ),
        )
    }

    @Test
    fun clamp_ordersBoundsDefensively() {
        // Even if min > max the helper must return a sensible bound rather than
        // propagate an invalid range (e.g. on a zero-size inset event).
        assertEquals(5, positioner.clamp(value = 10, min = 5, max = 5))
    }

    @Test
    fun isClick_trueForSmallMovement() {
        assertTrue(
            positioner.isClick(
                downX = 20f,
                downY = 20f,
                upX = 24f,
                upY = 23f,
                thresholdPx = 12f,
            ),
        )
    }

    @Test
    fun isClick_falseForDrag() {
        assertFalse(
            positioner.isClick(
                downX = 20f,
                downY = 20f,
                upX = 60f,
                upY = 20f,
                thresholdPx = 12f,
            ),
        )
    }
}
