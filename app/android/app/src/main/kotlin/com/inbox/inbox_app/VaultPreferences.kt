package com.inbox.inbox_app

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile

data class StoredVault(
    val treeUri: Uri,
    val displayName: String,
)

enum class VaultSaveResult {
    SAVED,
    RESTORED_PREVIOUS,
    DURABILITY_UNKNOWN,
}

class VaultPreferences(private val context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun load(): StoredVault? {
        val treeUri = preferences.getString(KEY_TREE_URI, null) ?: return null
        val displayName = preferences.getString(KEY_DISPLAY_NAME, null) ?: return null
        return StoredVault(Uri.parse(treeUri), displayName)
    }

    fun save(treeUri: Uri, displayName: String): VaultSaveResult {
        val previous = load()
        val committed = preferences.edit()
            .putString(KEY_TREE_URI, treeUri.toString())
            .putString(KEY_DISPLAY_NAME, displayName)
            .commit()
        if (committed) return VaultSaveResult.SAVED

        val rollback = preferences.edit().clear()
        if (previous != null) {
            rollback
                .putString(KEY_TREE_URI, previous.treeUri.toString())
                .putString(KEY_DISPLAY_NAME, previous.displayName)
        }
        return if (rollback.commit()) {
            VaultSaveResult.RESTORED_PREVIOUS
        } else {
            VaultSaveResult.DURABILITY_UNKNOWN
        }
    }

    fun clear() {
        preferences.edit().clear().apply()
    }

    fun isAccessible(treeUri: Uri): Boolean {
        val permission = context.contentResolver.persistedUriPermissions.firstOrNull {
            it.uri == treeUri && it.isReadPermission && it.isWritePermission
        } ?: return false
        return permission.isReadPermission &&
            permission.isWritePermission &&
            DocumentFile.fromTreeUri(context, treeUri)?.let {
                it.exists() && it.canWrite()
            } == true
    }

    companion object {
        private const val PREFERENCES_NAME = "androidVault"
        private const val KEY_TREE_URI = "vaultTreeUri"
        private const val KEY_DISPLAY_NAME = "vaultDisplayName"
    }
}
