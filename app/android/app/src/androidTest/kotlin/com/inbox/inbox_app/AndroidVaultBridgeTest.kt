package com.inbox.inbox_app

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ProviderInfo
import android.net.Uri
import android.provider.DocumentsContract
import android.test.mock.MockContentResolver
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidVaultBridgeTest {
    private lateinit var resolver: RecordingContentResolver
    private lateinit var bridge: AndroidVaultBridge
    private lateinit var preferences: VaultPreferences
    private lateinit var validTreeUri: Uri

    @Before
    fun setUp() {
        val targetContext = ApplicationProvider.getApplicationContext<Context>()
        resolver = RecordingContentResolver()
        val context = object : ContextWrapper(targetContext) {
            override fun getContentResolver() = resolver

            override fun checkCallingOrSelfUriPermission(uri: Uri, modeFlags: Int): Int =
                PackageManager.PERMISSION_GRANTED
        }
        val provider = TestDocumentsProvider()
        provider.attachInfo(
            context,
            ProviderInfo().apply { authority = TEST_AUTHORITY },
        )
        resolver.addProvider(TEST_AUTHORITY, provider)
        bridge = AndroidVaultBridge(context, NoopBinaryMessenger())
        preferences = VaultPreferences(context)
        preferences.clear()
        validTreeUri = DocumentsContract.buildTreeDocumentUri(
            TEST_AUTHORITY,
            TestDocumentsProvider.ROOT_DOCUMENT_ID,
        )
    }

    @Test
    fun pickVaultWithoutVisibleActivityReturnsNoActivity() {
        val result = RecordingResult()

        bridge.handleMethodCall(MethodCall("pickVault", null), result)

        assertEquals("NO_ACTIVITY", result.errorCode)
    }

    @Test
    fun successfulReselectionReleasesPreviousGrantAfterPersistingNewVault() {
        val previousUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        storePreviousVault(previousUri)
        val result = RecordingResult()

        bridge.handlePickedVault(PickedVault(validTreeUri, REQUIRED_FLAGS), result)

        assertEquals(validTreeUri, preferences.load()?.treeUri)
        assertTrue(resolver.hasGrant(validTreeUri, REQUIRED_FLAGS))
        assertFalse(resolver.hasGrant(previousUri, REQUIRED_FLAGS))
        assertEquals(listOf(ReleasedGrant(previousUri, REQUIRED_FLAGS)), resolver.releases)
        assertEquals(null, result.errorCode)
    }

    @Test
    fun pickerCancellationPreservesPreviousVaultAndGrant() {
        val previousUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        storePreviousVault(previousUri)
        val result = RecordingResult()

        bridge.handlePickedVault(null, result)

        assertEquals(previousUri, preferences.load()?.treeUri)
        assertEquals("Obsidian", preferences.load()?.displayName)
        assertTrue(resolver.hasGrant(previousUri, REQUIRED_FLAGS))
        assertTrue(resolver.releases.isEmpty())
        assertEquals(null, result.successValue)
    }

    @Test
    fun failedReselectionPreservesPreviousVaultAndGrant() {
        val previousUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        val invalidTreeUri = DocumentsContract.buildTreeDocumentUri(
            TEST_AUTHORITY,
            "missing",
        )
        storePreviousVault(previousUri)
        val result = RecordingResult()

        bridge.handlePickedVault(PickedVault(invalidTreeUri, REQUIRED_FLAGS), result)

        assertEquals(previousUri, preferences.load()?.treeUri)
        assertTrue(resolver.hasGrant(previousUri, REQUIRED_FLAGS))
        assertFalse(resolver.hasGrant(invalidTreeUri, REQUIRED_FLAGS))
        assertEquals(listOf(ReleasedGrant(invalidTreeUri, REQUIRED_FLAGS)), resolver.releases)
        assertEquals("VAULT_UNAVAILABLE", result.errorCode)
    }

    @Test
    fun sameUriReselectionKeepsItsGrant() {
        storePreviousVault(validTreeUri)
        val result = RecordingResult()

        bridge.handlePickedVault(PickedVault(validTreeUri, REQUIRED_FLAGS), result)

        assertEquals(validTreeUri, preferences.load()?.treeUri)
        assertTrue(resolver.hasGrant(validTreeUri, REQUIRED_FLAGS))
        assertTrue(resolver.releases.isEmpty())
        assertEquals(null, result.errorCode)
    }

    private fun storePreviousVault(uri: Uri) {
        preferences.save(uri, "Obsidian")
        resolver.takePersistableUriPermission(uri, REQUIRED_FLAGS)
    }

    private companion object {
        const val TEST_AUTHORITY = "com.inbox.inbox_app.bridge.test.documents"
        const val REQUIRED_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }
}

private data class ReleasedGrant(val uri: Uri, val flags: Int)

private class RecordingContentResolver : MockContentResolver() {
    private val grants = mutableMapOf<Uri, Int>()
    val releases = mutableListOf<ReleasedGrant>()

    override fun takePersistableUriPermission(uri: Uri, modeFlags: Int) {
        grants[uri] = (grants[uri] ?: 0) or modeFlags
    }

    override fun releasePersistableUriPermission(uri: Uri, modeFlags: Int) {
        releases.add(ReleasedGrant(uri, modeFlags))
        val remaining = (grants[uri] ?: 0) and modeFlags.inv()
        if (remaining == 0) grants.remove(uri) else grants[uri] = remaining
    }

    fun hasGrant(uri: Uri, flags: Int): Boolean = (grants[uri] ?: 0) and flags == flags
}

private class NoopBinaryMessenger : BinaryMessenger {
    override fun send(channel: String, message: ByteBuffer?) = Unit

    override fun send(
        channel: String,
        message: ByteBuffer?,
        callback: BinaryMessenger.BinaryReply?,
    ) = Unit

    override fun setMessageHandler(
        channel: String,
        handler: BinaryMessenger.BinaryMessageHandler?,
    ) = Unit
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
