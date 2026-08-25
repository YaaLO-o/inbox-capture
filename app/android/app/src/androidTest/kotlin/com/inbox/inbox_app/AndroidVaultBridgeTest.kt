package com.inbox.inbox_app

import android.content.Context
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidVaultBridgeTest {
    private lateinit var context: Context
    private lateinit var bridge: AndroidVaultBridge
    private lateinit var preferences: VaultPreferences

    @Before
    fun setUp() {
        val application = ApplicationProvider.getApplicationContext<InboxApplication>()
        context = application
        bridge = application.vaultBridge
        preferences = VaultPreferences(context)
        preferences.clear()
    }

    @Test
    fun pickVaultWithoutVisibleActivityReturnsNoActivity() {
        val result = RecordingResult()

        bridge.handleMethodCall(MethodCall("pickVault", null), result)

        assertEquals("NO_ACTIVITY", result.errorCode)
    }

    @Test
    fun pickerCancellationPreservesPreviousVault() {
        val previousUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        preferences.save(previousUri, "Obsidian")
        val result = RecordingResult()

        bridge.handlePickedVault(null, result)

        assertEquals(previousUri, preferences.load()?.treeUri)
        assertEquals("Obsidian", preferences.load()?.displayName)
        assertEquals(null, result.successValue)
    }

    private class RecordingResult : MethodChannel.Result {
        var errorCode: String? = null
        var successValue: Any? = Unit

        override fun success(result: Any?) {
            successValue = result
        }

        override fun error(
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?,
        ) {
            this.errorCode = errorCode
        }

        override fun notImplemented() = Unit
    }
}
