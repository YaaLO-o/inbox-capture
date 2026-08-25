package com.inbox.inbox_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

/**
 * Foreground service that hosts the floating capture bubble.
 *
 * The bubble is a 32dp black circle inside a 48dp transparent touch target.
 * Tapping it launches [ClipboardCaptureActivity]; dragging snaps to the nearer
 * horizontal edge on release. The service is started/stopped by the Flutter
 * settings page and never auto-restarts after the process is killed
 * ([START_NOT_STICKY]).
 */
class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var handler: Handler
    private lateinit var bubbleView: FrameLayout
    private lateinit var dotView: View

    private var layoutParams: WindowManager.LayoutParams? = null
    private var added = false
    private var downRawX = 0f
    private var downRawY = 0f
    private var downX = 0
    private var downY = 0
    private var moved = false
    private var touchSlop = 12

    private var feedbackRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        handler = Handler(Looper.getMainLooper())
        touchSlop = ViewConfiguration.get(this).scaledTouchSlop

        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        bubbleView = createBubbleView()
        addOverlay()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP || intent?.action == ACTION_STOP_OVERLAY) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_CAPTURE_RESULT) {
            val status = intent.getStringExtra(EXTRA_STATUS) ?: "error"
            showFeedback(status)
        }
        return START_NOT_STICKY
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (added) {
            val params = layoutParams ?: return
            val (width, height) = currentDisplaySizePx()
            params.x = OverlayPositioner.nearestEdgeX(
                x = params.x,
                screenWidth = width,
                bubbleWidth = bubbleView.width.takeIf { it > 0 } ?: BUBBLE_TOUCH_DP.dp(),
            )
            params.y = OverlayPositioner.clampY(
                y = params.y,
                topInset = 0,
                bottomInset = 0,
                screenHeight = height,
                bubbleHeight = bubbleView.height.takeIf { it > 0 } ?: BUBBLE_TOUCH_DP.dp(),
            )
            try {
                windowManager.updateViewLayout(bubbleView, params)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to re-clamp overlay", e)
            }
        }
    }

    override fun onDestroy() {
        removeOverlay()
        handler.removeCallbacksAndMessages(null)
        isRunning = false
        super.onDestroy()
    }

    private fun createBubbleView(): FrameLayout {
        val touch = BUBBLE_TOUCH_DP.dp()
        val dot = BUBBLE_DOT_DP.dp()
        val container = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(touch, touch)
            isClickable = true
        }
        val dotView = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(dot, dot).apply {
                gravity = Gravity.CENTER
            }
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.OVAL
                setColor(0xFF111111.toInt())
            }
        }
        container.addView(dotView)
        this.dotView = dotView
        container.setOnTouchListener(::onTouch)
        return container
    }

    private fun addOverlay() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedSide = prefs.getString(KEY_SIDE, SIDE_RIGHT) ?: SIDE_RIGHT
        val savedY = prefs.getInt(KEY_Y, Int.MIN_VALUE)

        val (width, height) = currentDisplaySizePx()
        val size = BUBBLE_TOUCH_DP.dp()
        val initialX = if (savedSide == SIDE_LEFT) 0 else width - size
        val initialY = if (savedY == Int.MIN_VALUE) {
            (height - size) / 2
        } else {
            OverlayPositioner.clampY(savedY, 0, 0, height, size)
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            size,
            size,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initialX
            y = initialY
        }
        layoutParams = params
        try {
            windowManager.addView(bubbleView, params)
            added = true
        } catch (e: Exception) {
            Log.e(TAG, "Unable to add overlay view", e)
            stopSelf()
        }
    }

    private fun removeOverlay() {
        if (added) {
            try {
                windowManager.removeView(bubbleView)
            } catch (_: Exception) {
                // Already removed by the system.
            }
            added = false
        }
    }

    private fun onTouch(view: View, event: MotionEvent): Boolean {
        val params = layoutParams ?: return false
        return when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                downX = params.x
                downY = params.y
                moved = false
                true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = (event.rawX - downRawX)
                val dy = (event.rawY - downRawY)
                if (!moved && (dx > touchSlop || dy > touchSlop || dx < -touchSlop || dy < -touchSlop)) {
                    moved = true
                }
                if (moved) {
                    params.x = OverlayPositioner.clamp(
                        (downX + dx).roundToInt(),
                        0,
                        (currentDisplaySizePx().first - BUBBLE_TOUCH_DP.dp()).coerceAtLeast(0),
                    )
                    params.y = OverlayPositioner.clamp(
                        (downY + dy).roundToInt(),
                        0,
                        (currentDisplaySizePx().second - BUBBLE_TOUCH_DP.dp()).coerceAtLeast(0),
                    )
                    try {
                        windowManager.updateViewLayout(bubbleView, params)
                    } catch (_: Exception) {
                    }
                }
                true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val isClick = OverlayPositioner.isClick(
                    downX = downRawX,
                    downY = downRawY,
                    upX = event.rawX,
                    upY = event.rawY,
                    thresholdPx = touchSlop.toFloat(),
                )
                if (!moved && isClick) {
                    try {
                        ClipboardCaptureActivity.launch(this)
                    } catch (e: Exception) {
                        Log.w(TAG, "Unable to launch capture activity", e)
                    }
                } else {
                    snapAndPersist(params)
                }
                true
            }
            else -> false
        }
    }

    private fun snapAndPersist(params: WindowManager.LayoutParams) {
        val (width, height) = currentDisplaySizePx()
        val size = BUBBLE_TOUCH_DP.dp()
        val snappedX = OverlayPositioner.nearestEdgeX(params.x, width, size)
        val clampedY = OverlayPositioner.clampY(params.y, 0, 0, height, size)
        params.x = snappedX
        params.y = clampedY
        try {
            windowManager.updateViewLayout(bubbleView, params)
        } catch (_: Exception) {
        }
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SIDE, if (snappedX == 0) SIDE_LEFT else SIDE_RIGHT)
            .putInt(KEY_Y, clampedY)
            .apply()
    }

    private fun showFeedback(status: String) {
        val color = when (status) {
            "saved" -> 0xFF2E7D32.toInt() // green
            "empty" -> 0xFFF9A825.toInt() // amber
            else -> 0xFFC62828.toInt()    // red
        }
        feedbackRunnable?.let { handler.removeCallbacks(it) }
        (dotView.background as? android.graphics.drawable.GradientDrawable)?.setColor(color)
        dotView.scaleX = 1.25f
        dotView.scaleY = 1.25f
        val reset = Runnable {
            (dotView.background as? android.graphics.drawable.GradientDrawable)
                ?.setColor(0xFF111111.toInt())
            dotView.scaleX = 1f
            dotView.scaleY = 1f
        }
        feedbackRunnable = reset
        handler.postDelayed(reset, FEEDBACK_DURATION_MILLIS)
    }

    private fun currentDisplaySizePx(): Pair<Int, Int> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            @Suppress("DEPRECATION")
            val point = android.graphics.Point()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealSize(point)
            point.x to point.y
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "INbox 悬浮 Capture",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "悬浮 Capture 运行状态"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = PendingIntent.getService(
            this,
            REQUEST_STOP,
            Intent(this, OverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("INbox 悬浮 Capture")
            .setContentText("点击悬浮球保存最新剪贴板")
            .setSmallIcon(android.R.drawable.ic_menu_crop)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "停止悬浮球", stopIntent)
            .build()
    }

    private fun Int.dp(): Int = (this * resources.displayMetrics.density).roundToInt()

    companion object {
        private const val TAG = "INboxOverlay"
        const val ACTION_CAPTURE_RESULT = "com.inbox.inbox_app.action.CAPTURE_RESULT"
        const val ACTION_STOP_OVERLAY = "com.inbox.inbox_app.action.STOP_OVERLAY"
        private const val ACTION_STOP = "com.inbox.inbox_app.action.STOP"
        private const val EXTRA_STATUS = "status"
        private const val CHANNEL_ID = "inbox_overlay"
        private const val NOTIFICATION_ID = 4101
        private const val REQUEST_STOP = 4102
        private const val PREFS_NAME = "inbox_overlay_prefs"
        private const val KEY_SIDE = "side"
        private const val KEY_Y = "y"
        private const val SIDE_LEFT = "left"
        private const val SIDE_RIGHT = "right"
        private const val BUBBLE_TOUCH_DP = 48
        private const val BUBBLE_DOT_DP = 32
        private const val FEEDBACK_DURATION_MILLIS = 750L

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OverlayService::class.java))
        }
    }
}
