package com.inbox.inbox_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
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
    private var overlayChannel: MethodChannel? = null

    init {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        overlayChannel = channel
        channel.setMethodCallHandler(::handleMethodCall)
    }

    fun attachActivity(activity: MainActivity) {
        this.activity = activity
    }

    fun detachActivity(activity: MainActivity) {
        if (this.activity === activity) this.activity = null
    }

    fun notifyOverlayStateChanged() {
        overlayChannel?.invokeMethod("overlayStateChanged", overlayState())
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
            "getOverlayState" -> result.success(overlayState())
            "requestOverlayPermission" -> result.success(requestOverlayPermission())
            "requestNotificationPermission" -> result.success(requestNotificationPermission())
            "startOverlay" -> startOverlay(result)
            "stopOverlay" -> {
                OverlayService.stop(context)
                result.success(null)
            }
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun overlayState(): Map<String, Any> = mapOf(
        "running" to OverlayService.isRunning,
        "overlayPermission" to canDrawOverlays(),
        "notificationPermission" to hasNotificationPermission(),
        "vaultConfigured" to (preferences.load() != null),
    )

    private fun canDrawOverlays(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }

    private fun hasNotificationPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

    private fun requestOverlayPermission(): Boolean {
        if (canDrawOverlays()) return true
        val currentActivity = activity
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && currentActivity != null) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                currentActivity.startActivity(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Unable to open overlay permission settings", e)
            }
        }
        return canDrawOverlays()
    }

    private fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        if (hasNotificationPermission()) return true
        val currentActivity = activity ?: return hasNotificationPermission()
        currentActivity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            MainActivity.NOTIFICATION_PERMISSION_REQUEST,
        )
        return hasNotificationPermission()
    }

    private fun openNotificationSettings() {
        val currentActivity = activity ?: return
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:${context.packageName}"))
            }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            currentActivity.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Unable to open notification settings", e)
        }
    }

    private fun startOverlay(result: MethodChannel.Result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Overlay requires a visible Activity", null)
            return
        }
        if (!canDrawOverlays()) {
            result.error("OVERLAY_PERMISSION_DENIED", "Overlay permission denied", null)
            return
        }
        if (preferences.load() == null) {
            result.error("VAULT_UNAVAILABLE", "No Vault configured", null)
            return
        }
        // Notification denial on API 33+ is non-fatal per the MVP brief.
        try {
            OverlayService.start(context)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start overlay service", e)
            result.error("OVERLAY_START_FAILED", e.message, null)
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
            when (preferences.save(picked.uri, displayName)) {
                VaultSaveResult.SAVED -> Unit
                VaultSaveResult.RESTORED_PREVIOUS -> {
                    releaseNewPermission(picked.uri, previousUri, grantFlags)
                    result.error("VAULT_UNAVAILABLE", "Could not persist Vault", null)
                    return
                }
                VaultSaveResult.DURABILITY_UNKNOWN -> {
                    result.error("VAULT_UNAVAILABLE", "Could not persist Vault", null)
                    return
                }
            }
            releasePreviousPermission(previousUri, picked.uri)
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

    private fun releasePreviousPermission(previousUri: Uri?, currentUri: Uri) {
        if (previousUri == null || previousUri == currentUri) return
        try {
            context.contentResolver.releasePersistableUriPermission(
                previousUri,
                REQUIRED_GRANT_FLAGS,
            )
        } catch (_: SecurityException) {
            // The new Vault stays selected if Android already revoked the previous grant.
        }
    }

    companion object {
        private const val TAG = "INboxVaultBridge"
        private const val CHANNEL_NAME = "com.inbox.app/android_vault"
        private const val REQUIRED_GRANT_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }
}
