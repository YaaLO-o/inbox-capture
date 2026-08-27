package com.inbox.inbox_app

import android.content.ComponentName
import android.content.Context
import android.content.pm.ActivityInfo
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareCaptureActivityConfigTest {
    @Test
    fun rotationConfigChangesKeepShareActivityInstance() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val info = context.packageManager.getActivityInfo(
            ComponentName(context, ShareCaptureActivity::class.java),
            0,
        )

        assertTrue(info.configChanges and ActivityInfo.CONFIG_ORIENTATION != 0)
        assertTrue(info.configChanges and ActivityInfo.CONFIG_SCREEN_SIZE != 0)
        assertTrue(info.configChanges and ActivityInfo.CONFIG_SMALLEST_SCREEN_SIZE != 0)
    }
}
