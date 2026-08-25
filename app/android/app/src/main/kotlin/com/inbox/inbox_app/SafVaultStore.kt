package com.inbox.inbox_app

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
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

    private data class ChildDocument(
        val file: DocumentFile,
        val mimeType: String,
    )

    fun ensureLayout(treeUri: Uri): CaptureDirs {
        val root = DocumentFile.fromTreeUri(context, treeUri)
            ?: throw FileNotFoundException("Vault unavailable")
        if (!root.exists() || !root.isDirectory || !root.canWrite()) {
            throw FileNotFoundException("Vault unavailable")
        }
        val capture = exactDirectory(root, CAPTURE_DIRECTORY)
        val attachments = exactDirectory(capture, ATTACHMENTS_DIRECTORY)
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
        val attachment = exactChild(
            ensureLayout(treeUri).attachments,
            fileName,
            expectedFileMimeType(fileName, "application/octet-stream"),
        ) ?: return
        if (attachment.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            throw IOException("$fileName is a directory")
        }
        if (!DocumentsContract.deleteDocument(contentResolver, attachment.file.uri)) {
            throw IOException("Could not delete attachment")
        }
    }

    private fun writableFile(parent: DocumentFile, fileName: String, mimeType: String): DocumentFile {
        val expectedMimeType = expectedFileMimeType(fileName, mimeType)
        exactChild(parent, fileName, expectedMimeType)?.let { existing ->
            if (existing.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                throw IOException("$fileName is a directory")
            }
            return existing.file
        }
        val created = createExactChild(parent, mimeType, fileName, expectedMimeType)
        if (created.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
            throw IOException("$fileName is a directory")
        }
        return created.file
    }

    private fun exactDirectory(parent: DocumentFile, displayName: String): DocumentFile {
        exactChild(
            parent,
            displayName,
            DocumentsContract.Document.MIME_TYPE_DIR,
        )?.let { existing ->
            if (existing.mimeType != DocumentsContract.Document.MIME_TYPE_DIR) {
                throw IOException("$displayName is not a directory")
            }
            return existing.file
        }
        val created = createExactChild(
            parent,
            DocumentsContract.Document.MIME_TYPE_DIR,
            displayName,
            DocumentsContract.Document.MIME_TYPE_DIR,
        )
        if (created.mimeType != DocumentsContract.Document.MIME_TYPE_DIR) {
            throw IOException("$displayName is not a directory")
        }
        return created.file
    }

    private fun createExactChild(
        parent: DocumentFile,
        mimeType: String,
        displayName: String,
        expectedMimeType: String,
    ): ChildDocument {
        val createdUri = DocumentsContract.createDocument(
            contentResolver,
            parent.uri,
            mimeType,
            displayName,
        ) ?: throw IOException("Could not create $displayName")
        // Re-query the child by exact display name rather than trusting
        // DocumentFile.fromSingleUri(createdUri), whose name/type can be null on
        // some providers (e.g. test/stub providers and certain OEM builds).
        // exactChild enumerates children and, on external storage, falls back to
        // the deterministic document id, so it reliably detects when the provider
        // honored the requested name versus minting a "name (N)" variant.
        val exact = exactChild(parent, displayName, expectedMimeType)
        if (exact != null) {
            // A concurrent create could have produced a duplicate at createdUri;
            // remove it if it is not the exact document we are returning.
            if (exact.file.uri != createdUri) {
                runCatching { DocumentsContract.deleteDocument(contentResolver, createdUri) }
            }
            return exact
        }
        val deleted = runCatching {
            DocumentsContract.deleteDocument(contentResolver, createdUri)
        }.getOrDefault(false)
        if (!deleted) {
            throw IOException("Provider created non-exact $displayName and cleanup failed")
        }
        throw IOException("Provider did not create exact child $displayName")
    }

    private fun exactChild(
        parent: DocumentFile,
        displayName: String,
        expectedMimeType: String,
    ): ChildDocument? {
        val parentDocumentId = DocumentsContract.getDocumentId(parent.uri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parent.uri,
            parentDocumentId,
        )
        val cursor = contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        ) ?: throw IOException("Could not list children of $parentDocumentId")
        cursor.use {
            val idColumn = it.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameColumn = it.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            val mimeTypeColumn = it.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            while (it.moveToNext()) {
                if (it.getString(nameColumn) != displayName) continue
                val childUri = DocumentsContract.buildDocumentUriUsingTree(
                    parent.uri,
                    it.getString(idColumn),
                )
                val child = DocumentFile.fromSingleUri(context, childUri)
                    ?: throw IOException("Could not open exact child $displayName")
                return ChildDocument(child, it.getString(mimeTypeColumn))
            }
        }
        if (parent.uri.authority != EXTERNAL_STORAGE_AUTHORITY) return null
        return exactExternalStorageChild(
            parent,
            parentDocumentId,
            displayName,
            expectedMimeType,
        )
    }

    private fun exactExternalStorageChild(
        parent: DocumentFile,
        parentDocumentId: String,
        displayName: String,
        expectedMimeType: String,
    ): ChildDocument? {
        val expectedDocumentId = "$parentDocumentId/$displayName"
        val childUri = DocumentsContract.buildDocumentUriUsingTree(
            parent.uri,
            expectedDocumentId,
        )
        val cursor = try {
            contentResolver.query(
                childUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                ),
                null,
                null,
                null,
            )
        } catch (_: FileNotFoundException) {
            // Standard Android: querying a document URI that does not exist throws FNFE.
            return null
        } catch (error: IllegalArgumentException) {
            // HyperOS ExternalStorageProvider wraps the same "no such file" condition
            // in IllegalArgumentException ("Failed to determine if ... is child of ...:
            // FileNotFoundException: Missing file for ... at /storage/...") when the
            // direct-id target has never been created. Treat it as "absent" so the
            // caller can create it. A genuinely malformed URI would indicate a
            // programming error, but all ids here derive from provider-returned
            // parent ids, so this exception only represents a missing child.
            if (!error.causeChainContainsFileNotFoundException()) throw error
            return null
        } ?: return null
        cursor.use {
            if (!it.moveToFirst()) return null
            val documentId = it.getString(
                it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
            )
            val actualName = it.getString(
                it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            )
            val actualMimeType = it.getString(
                it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE),
            )
            if (
                documentId != expectedDocumentId ||
                actualName != displayName ||
                actualMimeType != expectedMimeType
            ) {
                throw IOException(
                    "Exact child metadata mismatch for $displayName: " +
                        "$documentId|$actualName|$actualMimeType",
                )
            }
            if (it.moveToNext()) {
                throw IOException("Multiple exact children for $displayName")
            }
            val child = DocumentFile.fromSingleUri(context, childUri)
                ?: throw IOException("Could not open exact child $displayName")
            return ChildDocument(child, actualMimeType)
        }
    }

    private fun expectedFileMimeType(fileName: String, fallback: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: fallback
    }

    private fun Throwable.causeChainContainsFileNotFoundException(): Boolean {
        var cause: Throwable? = this
        while (cause != null) {
            if (cause is FileNotFoundException) return true
            cause = cause.cause
        }
        return false
    }

    companion object {
        private const val CAPTURE_DIRECTORY = "Universal Capture"
        private const val ATTACHMENTS_DIRECTORY = "attachments"
        private const val EXTERNAL_STORAGE_AUTHORITY =
            "com.android.externalstorage.documents"
    }
}
