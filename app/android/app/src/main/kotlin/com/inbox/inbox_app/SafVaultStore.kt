package com.inbox.inbox_app

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException

data class CaptureDirs(
    val capture: DocumentFile,
    val attachments: DocumentFile,
)

class SafVaultStore(private val context: Context) {
    private val contentResolver: ContentResolver = context.contentResolver

    fun ensureLayout(treeUri: Uri): CaptureDirs {
        val root = DocumentFile.fromTreeUri(context, treeUri)
            ?: throw FileNotFoundException("Vault unavailable")
        if (!root.exists() || !root.isDirectory || !root.canWrite()) {
            throw FileNotFoundException("Vault unavailable")
        }
        val capture = root.findFile(CAPTURE_DIRECTORY)
            ?: root.createDirectory(CAPTURE_DIRECTORY)
            ?: throw IOException("Could not create capture directory")
        if (!capture.isDirectory) throw IOException("Capture path is not a directory")
        val attachments = capture.findFile(ATTACHMENTS_DIRECTORY)
            ?: capture.createDirectory(ATTACHMENTS_DIRECTORY)
            ?: throw IOException("Could not create attachments directory")
        if (!attachments.isDirectory) throw IOException("Attachments path is not a directory")
        return CaptureDirs(capture, attachments)
    }

    fun importUri(treeUri: Uri, sourceUri: Uri, fileName: String) {
        val target = writableFile(ensureLayout(treeUri).attachments, fileName, "application/octet-stream")
        try {
            contentResolver.openInputStream(sourceUri)?.use { input ->
                contentResolver.openOutputStream(target.uri, "w")?.use { output ->
                    input.copyTo(output)
                    output.flush()
                } ?: throw FileNotFoundException("Could not open attachment target")
            } ?: throw FileNotFoundException("Could not open attachment source")
        } catch (error: Exception) {
            target.delete()
            throw error
        }
    }

    fun appendMarkdown(treeUri: Uri, date: String, markdown: String) {
        val target = writableFile(ensureLayout(treeUri).capture, "$date.md", "text/markdown")
        val descriptor = try {
            contentResolver.openFileDescriptor(target.uri, "wa")
                ?: throw FileNotFoundException("Could not append Markdown")
        } catch (_: FileNotFoundException) {
            null
        } catch (_: UnsupportedOperationException) {
            null
        }

        if (descriptor != null) {
            descriptor.use {
                FileOutputStream(it.fileDescriptor).use { output ->
                    output.write(markdown.toByteArray(Charsets.UTF_8))
                    output.flush()
                }
            }
            return
        }

        val existing = contentResolver.openInputStream(target.uri)?.use { it.readBytes() }
            ?: throw FileNotFoundException("Could not read existing Markdown")
        contentResolver.openFileDescriptor(target.uri, "wt")?.use { outputDescriptor ->
            FileOutputStream(outputDescriptor.fileDescriptor).use { output ->
                output.write(existing)
                output.write(markdown.toByteArray(Charsets.UTF_8))
                output.flush()
            }
        } ?: throw FileNotFoundException("Could not rewrite Markdown")
    }

    fun deleteAttachment(treeUri: Uri, fileName: String) {
        val attachment = ensureLayout(treeUri).attachments.findFile(fileName) ?: return
        if (!DocumentsContract.deleteDocument(contentResolver, attachment.uri)) {
            throw IOException("Could not delete attachment")
        }
    }

    private fun writableFile(parent: DocumentFile, fileName: String, mimeType: String): DocumentFile {
        return parent.findFile(fileName)
            ?: parent.createFile(mimeType, fileName)
            ?: throw IOException("Could not create $fileName")
    }

    companion object {
        private const val CAPTURE_DIRECTORY = "Universal Capture"
        private const val ATTACHMENTS_DIRECTORY = "attachments"
    }
}
