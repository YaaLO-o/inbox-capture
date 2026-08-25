package com.inbox.inbox_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException

class AndroidVaultBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val preferences = VaultPreferences(context)
    private val store = SafVaultStore(context)
    private var activity: MainActivity? = null

    init {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(::handleMethodCall)
    }

    fun attachActivity(activity: MainActivity) {
        this.activity = activity
    }

    fun detachActivity(activity: MainActivity) {
        if (this.activity === activity) this.activity = null
    }

    internal fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVault" -> result.success(preferences.load()?.toDescriptor())
            "pickVault" -> pickVault(result)
            "clearVault" -> clearVault(result)
            "ensureLayout" -> runStorage(call, result, "VAULT_UNAVAILABLE") { treeUri, _ ->
                store.ensureLayout(treeUri)
            }
            "importUri" -> runStorage(call, result, "IMPORT_FAILED") { treeUri, args ->
                store.importUri(
                    treeUri,
                    Uri.parse(args.requiredString("sourceUri")),
                    args.requiredString("fileName"),
                )
            }
            "appendMarkdown" -> runStorage(call, result, "APPEND_FAILED") { treeUri, args ->
                store.appendMarkdown(
                    treeUri,
                    args.requiredString("date"),
                    args.requiredString("markdown"),
                )
            }
            "deleteAttachment" -> runStorage(call, result, "IMPORT_FAILED") { treeUri, args ->
                store.deleteAttachment(treeUri, args.requiredString("fileName"))
            }
            else -> result.notImplemented()
        }
    }

    private fun pickVault(result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Vault picker requires a visible Activity", null)
            return
        }
        if (!currentActivity.launchVaultPicker { picked -> handlePickedVault(picked, result) }) {
            result.error("NO_ACTIVITY", "Vault picker is already active", null)
        }
    }

    internal fun handlePickedVault(picked: PickedVault?, result: MethodChannel.Result) {
        if (picked == null) {
            result.success(null)
            return
        }
        val grantFlags = picked.flags and (
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
        if (grantFlags != REQUIRED_GRANT_FLAGS) {
            result.error("PERMISSION_DENIED", "Vault requires read and write access", null)
            return
        }
        val previousUri = preferences.load()?.treeUri
        try {
            context.contentResolver.takePersistableUriPermission(picked.uri, grantFlags)
            store.ensureLayout(picked.uri)
            val displayName = DocumentFile.fromTreeUri(context, picked.uri)?.name
                ?: picked.uri.lastPathSegment
                ?: "Vault"
            preferences.save(picked.uri, displayName)
            result.success(
                mapOf(
                    "id" to picked.uri.toString(),
                    "displayName" to displayName,
                    "accessible" to true,
                ),
            )
        } catch (error: SecurityException) {
            releaseNewPermission(picked.uri, previousUri, grantFlags)
            result.error("PERMISSION_DENIED", error.message, null)
        } catch (error: Exception) {
            releaseNewPermission(picked.uri, previousUri, grantFlags)
            result.error("VAULT_UNAVAILABLE", error.message, null)
        }
    }

    private fun clearVault(result: MethodChannel.Result) {
        val stored = preferences.load()
        preferences.clear()
        if (stored != null) {
            try {
                context.contentResolver.releasePersistableUriPermission(
                    stored.treeUri,
                    REQUIRED_GRANT_FLAGS,
                )
            } catch (_: SecurityException) {
                // The persisted record is cleared even if Android already revoked the grant.
            }
        }
        result.success(null)
    }

    private fun runStorage(
        call: MethodCall,
        result: MethodChannel.Result,
        failureCode: String,
        operation: (Uri, Map<*, *>) -> Unit,
    ) {
        val args = call.arguments as? Map<*, *>
        try {
            val vaultId = args?.requiredString("vaultId")
                ?: throw FileNotFoundException("Vault unavailable")
            val treeUri = Uri.parse(vaultId)
            val stored = preferences.load()
            if (stored?.treeUri != treeUri || !preferences.isAccessible(treeUri)) {
                throw FileNotFoundException("Vault unavailable")
            }
            operation(treeUri, args)
            result.success(null)
        } catch (error: SecurityException) {
            result.error("PERMISSION_DENIED", error.message, null)
        } catch (error: Exception) {
            result.error(failureCode, error.message, null)
        }
    }

    private fun StoredVault.toDescriptor(): Map<String, Any> = mapOf(
        "id" to treeUri.toString(),
        "displayName" to displayName,
        "accessible" to preferences.isAccessible(treeUri),
    )

    private fun Map<*, *>.requiredString(key: String): String =
        this[key] as? String ?: throw IllegalArgumentException("Missing $key")

    private fun releaseNewPermission(uri: Uri, previousUri: Uri?, flags: Int) {
        if (uri == previousUri) return
        try {
            context.contentResolver.releasePersistableUriPermission(uri, flags)
        } catch (_: SecurityException) {
            // No grant was persisted.
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.inbox.app/android_vault"
        private const val REQUIRED_GRANT_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }
}
