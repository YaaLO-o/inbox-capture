package com.inbox.inbox_app

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.SharedPreferences
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
    private lateinit var events: MutableList<String>
    private lateinit var sharedPreferences: RecordingSharedPreferences
    private lateinit var resolver: RecordingContentResolver
    private lateinit var bridge: AndroidVaultBridge
    private lateinit var preferences: VaultPreferences
    private lateinit var validTreeUri: Uri

    @Before
    fun setUp() {
        val targetContext = ApplicationProvider.getApplicationContext<Context>()
        events = mutableListOf()
        sharedPreferences = RecordingSharedPreferences(events)
        resolver = RecordingContentResolver(events)
        val context = object : ContextWrapper(targetContext) {
            override fun getContentResolver() = resolver

            override fun getSharedPreferences(name: String, mode: Int) = sharedPreferences

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
        events.clear()
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
        events.clear()
        val result = RecordingResult()

        bridge.handlePickedVault(PickedVault(validTreeUri, REQUIRED_FLAGS), result)

        assertEquals(validTreeUri, preferences.load()?.treeUri)
        assertTrue(resolver.hasGrant(validTreeUri, REQUIRED_FLAGS))
        assertFalse(resolver.hasGrant(previousUri, REQUIRED_FLAGS))
        assertEquals(listOf(ReleasedGrant(previousUri, REQUIRED_FLAGS)), resolver.releases)
        assertEquals(
            listOf("commit:$validTreeUri", "release:$previousUri"),
            events,
        )
        assertEquals(null, result.errorCode)
    }

    @Test
    fun commitFailureRestoresPreviousVaultAndGrantBeforeRemovingNewGrant() {
        val previousUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        storePreviousVault(previousUri)
        events.clear()
        sharedPreferences.commitsToFail = 1
        val result = RecordingResult()

        bridge.handlePickedVault(PickedVault(validTreeUri, REQUIRED_FLAGS), result)

        assertEquals(previousUri, preferences.load()?.treeUri)
        assertEquals("Obsidian", preferences.load()?.displayName)
        assertTrue(resolver.hasGrant(previousUri, REQUIRED_FLAGS))
        assertFalse(resolver.hasGrant(validTreeUri, REQUIRED_FLAGS))
        assertEquals(listOf(ReleasedGrant(validTreeUri, REQUIRED_FLAGS)), resolver.releases)
        assertEquals(
            listOf(
                "commit:$validTreeUri",
                "commit:$previousUri",
                "release:$validTreeUri",
            ),
            events,
        )
        assertEquals("VAULT_UNAVAILABLE", result.errorCode)
    }

    @Test
    fun doubleCommitFailureRetainsBothGrantsBecauseDurableVaultIsUnknown() {
        val previousUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        storePreviousVault(previousUri)
        events.clear()
        sharedPreferences.commitsToFail = 2
        val result = RecordingResult()

        bridge.handlePickedVault(PickedVault(validTreeUri, REQUIRED_FLAGS), result)

        assertEquals(previousUri, preferences.load()?.treeUri)
        assertTrue(resolver.hasGrant(previousUri, REQUIRED_FLAGS))
        assertTrue(resolver.hasGrant(validTreeUri, REQUIRED_FLAGS))
        assertTrue(resolver.releases.isEmpty())
        assertEquals(
            listOf("commit:$validTreeUri", "commit:$previousUri"),
            events,
        )
        assertEquals("VAULT_UNAVAILABLE", result.errorCode)
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

private class RecordingSharedPreferences(
    private val events: MutableList<String>,
) : SharedPreferences {
    private val values = mutableMapOf<String, Any?>()
    var commitsToFail = 0

    override fun getAll(): Map<String, *> = values.toMap()

    override fun getString(key: String, defaultValue: String?): String? =
        values[key] as? String ?: defaultValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String, defaultValues: Set<String>?): Set<String>? =
        values[key] as? Set<String> ?: defaultValues

    override fun getInt(key: String, defaultValue: Int): Int =
        values[key] as? Int ?: defaultValue

    override fun getLong(key: String, defaultValue: Long): Long =
        values[key] as? Long ?: defaultValue

    override fun getFloat(key: String, defaultValue: Float): Float =
        values[key] as? Float ?: defaultValue

    override fun getBoolean(key: String, defaultValue: Boolean): Boolean =
        values[key] as? Boolean ?: defaultValue

    override fun contains(key: String): Boolean = values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = RecordingEditor()

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    private inner class RecordingEditor : SharedPreferences.Editor {
        private val pending = mutableMapOf<String, Any?>()
        private val removals = mutableSetOf<String>()
        private var clear = false

        override fun putString(key: String, value: String?): SharedPreferences.Editor = apply {
            pending[key] = value
            removals.remove(key)
        }

        override fun putStringSet(
            key: String,
            values: Set<String>?,
        ): SharedPreferences.Editor = apply {
            pending[key] = values
            removals.remove(key)
        }

        override fun putInt(key: String, value: Int): SharedPreferences.Editor = apply {
            pending[key] = value
            removals.remove(key)
        }

        override fun putLong(key: String, value: Long): SharedPreferences.Editor = apply {
            pending[key] = value
            removals.remove(key)
        }

        override fun putFloat(key: String, value: Float): SharedPreferences.Editor = apply {
            pending[key] = value
            removals.remove(key)
        }

        override fun putBoolean(key: String, value: Boolean): SharedPreferences.Editor = apply {
            pending[key] = value
            removals.remove(key)
        }

        override fun remove(key: String): SharedPreferences.Editor = apply {
            removals.add(key)
            pending.remove(key)
        }

        override fun clear(): SharedPreferences.Editor = apply {
            clear = true
        }

        override fun commit(): Boolean {
            record("commit")
            applyChanges()
            if (commitsToFail == 0) return true
            commitsToFail -= 1
            return false
        }

        override fun apply() {
            record("apply")
            applyChanges()
        }

        private fun record(operation: String) {
            val treeUri = pending["vaultTreeUri"]
            events.add("$operation:${treeUri ?: "clear"}")
        }

        private fun applyChanges() {
            if (clear) values.clear()
            removals.forEach(values::remove)
            pending.forEach { (key, value) ->
                if (value == null) values.remove(key) else values[key] = value
            }
        }
    }
}

private class RecordingContentResolver(
    private val events: MutableList<String>,
) : MockContentResolver() {
    private val grants = mutableMapOf<Uri, Int>()
    val releases = mutableListOf<ReleasedGrant>()

    override fun takePersistableUriPermission(uri: Uri, modeFlags: Int) {
        grants[uri] = (grants[uri] ?: 0) or modeFlags
    }

    override fun releasePersistableUriPermission(uri: Uri, modeFlags: Int) {
        events.add("release:$uri")
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
