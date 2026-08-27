package com.inbox.inbox_app

import android.content.Context
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class VaultPreferencesTest {
    private lateinit var context: Context
    private lateinit var preferences: VaultPreferences

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        preferences = VaultPreferences(context)
        preferences.clear()
    }

    @Test
    fun storesExactlyTreeUriAndDisplayNameAndClearsBoth() {
        preferences.save(
            Uri.parse("content://provider/tree/primary%3AObsidian"),
            "Obsidian",
        )

        val stored = preferences.load()!!
        assertEquals("content://provider/tree/primary%3AObsidian", stored.treeUri.toString())
        assertEquals("Obsidian", stored.displayName)
        assertEquals(
            setOf("vaultTreeUri", "vaultDisplayName"),
            context.getSharedPreferences("androidVault", Context.MODE_PRIVATE).all.keys,
        )

        preferences.clear()
        assertNull(preferences.load())
    }

    @Test
    fun inaccessibleWithoutMatchingPersistedReadWritePermission() {
        val treeUri = Uri.parse("content://provider/tree/primary%3AObsidian")
        preferences.save(treeUri, "Obsidian")

        assertFalse(preferences.isAccessible(treeUri))
    }
}
