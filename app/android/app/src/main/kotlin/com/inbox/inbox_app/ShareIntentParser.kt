package com.inbox.inbox_app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns

data class ShareRequest(
    val text: String?,
    val attachments: List<SharedUri>,
)

data class SharedUri(
    val uri: Uri,
    val displayName: String?,
    val mimeType: String?,
    val extension: String,
)

class ShareIntentParser(
    private val contentResolver: ContentResolver,
) {
    fun parse(intent: Intent): ShareRequest? {
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }

        val attachments = linkedSetOf<Uri>().apply {
            when (intent.action) {
                Intent.ACTION_SEND -> intent.parcelableUri(Intent.EXTRA_STREAM)?.let(::add)
                Intent.ACTION_SEND_MULTIPLE -> intent.parcelableUriList(Intent.EXTRA_STREAM).forEach(::add)
            }
            intent.clipData?.let { clipData ->
                for (index in 0 until clipData.itemCount) {
                    clipData.getItemAt(index).uri?.let(::add)
                }
            }
        }.map(::sharedUri)

        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?.takeUnless(String::isBlank)
        if (attachments.isEmpty() && (intent.type != "text/plain" || text == null)) return null
        return ShareRequest(text = text, attachments = attachments)
    }

    @Suppress("DEPRECATION")
    private fun Intent.parcelableUri(key: String): Uri? = getParcelableExtra(key)

    @Suppress("DEPRECATION")
    private fun Intent.parcelableUriList(key: String): List<Uri> =
        getParcelableArrayListExtra<Uri>(key).orEmpty()

    private fun sharedUri(uri: Uri): SharedUri {
        val displayName = displayName(uri)
        val mimeType = runCatching { contentResolver.getType(uri) }.getOrNull()
        val extension = extensionFrom(displayName)
            .ifEmpty { MIME_EXTENSIONS[mimeType] ?: "" }
        return SharedUri(uri, displayName, mimeType, extension)
    }

    private fun displayName(uri: Uri): String? = runCatching {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
    }.getOrNull() ?: uri.lastPathSegment

    private fun extensionFrom(displayName: String?): String {
        val candidate = displayName?.substringAfterLast('.', "")?.lowercase().orEmpty()
        return candidate.takeIf { SAFE_EXTENSION.matches(it) }.orEmpty()
    }

    private companion object {
        val SAFE_EXTENSION = Regex("[a-z0-9]+")
        val MIME_EXTENSIONS = mapOf(
            "image/png" to "png",
            "image/jpeg" to "jpg",
            "image/gif" to "gif",
            "image/webp" to "webp",
            "application/pdf" to "pdf",
            "video/mp4" to "mp4",
            "video/quicktime" to "mov",
        )
    }
}
