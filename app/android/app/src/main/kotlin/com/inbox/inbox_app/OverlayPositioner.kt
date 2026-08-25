package com.inbox.inbox_app

import kotlin.math.abs

/**
 * Pure geometry helpers for the floating capture bubble.
 *
 * These are deliberately free of Android framework types so they can be
 * exercised by plain JVM unit tests. All coordinates are in pixels.
 */
object OverlayPositioner {
    /**
     * Clamp [value] into the closed range [[min], [max]]. When [min] > [max]
     * the bounds are swapped defensively so an inset report never produces an
     * invalid window position.
     */
    fun clamp(value: Int, min: Int, max: Int): Int {
        val lo = if (min <= max) min else max
        val hi = if (min <= max) max else min
        return when {
            value < lo -> lo
            value > hi -> hi
            else -> value
        }
    }

    /**
     * Pick the X coordinate that snaps the bubble to the nearer horizontal
     * edge while staying inside the safe insets.
     *
     * @param leftInset pixels already consumed on the left (status/navigation
     *   cutouts, gesture bars). The bubble's left edge will not go below this.
     * @param rightInset pixels already consumed on the right. The bubble's
     *   right edge will not go past screenWidth - rightInset.
     */
    fun nearestEdgeX(
        x: Int,
        screenWidth: Int,
        bubbleWidth: Int,
        leftInset: Int = 0,
        rightInset: Int = 0,
    ): Int {
        val leftTarget = clamp(leftInset, 0, screenWidth - bubbleWidth)
        val rightTarget = clamp(
            screenWidth - rightInset - bubbleWidth,
            0,
            screenWidth - bubbleWidth,
        )
        val center = x + bubbleWidth / 2
        val distanceLeft = abs(center - (leftTarget + bubbleWidth / 2))
        val distanceRight = abs(center - (rightTarget + bubbleWidth / 2))
        return if (distanceLeft <= distanceRight) leftTarget else rightTarget
    }

    /**
     * Clamp the bubble's vertical position within the top/bottom safe insets.
     */
    fun clampY(
        y: Int,
        topInset: Int,
        bottomInset: Int,
        screenHeight: Int,
        bubbleHeight: Int,
    ): Int = clamp(
        value = y,
        min = topInset,
        max = (screenHeight - bottomInset - bubbleHeight).coerceAtLeast(topInset),
    )

    /**
     * A pointer sequence is treated as a click (rather than a drag) when the
     * total movement between down and up stays within [thresholdPx] on both
     * axes.
     */
    fun isClick(
        downX: Float,
        downY: Float,
        upX: Float,
        upY: Float,
        thresholdPx: Float,
    ): Boolean = abs(upX - downX) <= thresholdPx && abs(upY - downY) <= thresholdPx
}
