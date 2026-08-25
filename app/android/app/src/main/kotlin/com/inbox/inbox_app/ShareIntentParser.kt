package com.inbox.inbox_app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri

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
        if (intent.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        if (text.isBlank()) return null
        return ShareRequest(text = text, attachments = emptyList())
    }
}
