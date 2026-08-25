package com.inbox.inbox_app

import android.Manifest
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.FileNotFoundException

class TestDocumentsProvider : DocumentsProvider() {
    private val rootDirectory: File
        get() = InstrumentationRegistry.getInstrumentation().targetContext.cacheDir
            .resolve(TEST_DIRECTORY).apply {
            mkdirs()
        }

    override fun attachInfo(context: Context, info: ProviderInfo) {
        info.exported = true
        info.grantUriPermissions = true
        info.readPermission = Manifest.permission.MANAGE_DOCUMENTS
        info.writePermission = Manifest.permission.MANAGE_DOCUMENTS
        super.attachInfo(
            object : ContextWrapper(context) {
                override fun revokeUriPermission(uri: android.net.Uri, modeFlags: Int) = Unit
            },
            info,
        )
    }

    override fun onCreate(): Boolean {
        rootDirectory.deleteRecursively()
        rootDirectory.mkdirs()
        return true
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val cursor = MatrixCursor(projection ?: ROOT_COLUMNS)
        val row = cursor.newRow()
        addIfRequested(row, cursor, Root.COLUMN_ROOT_ID, ROOT_DOCUMENT_ID)
        addIfRequested(row, cursor, Root.COLUMN_DOCUMENT_ID, ROOT_DOCUMENT_ID)
        addIfRequested(row, cursor, Root.COLUMN_TITLE, "Test Vault")
        addIfRequested(row, cursor, Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE)
        addIfRequested(row, cursor, Root.COLUMN_MIME_TYPES, "*/*")
        return cursor
    }

    override fun queryDocument(
        documentId: String,
        projection: Array<out String>?,
    ): Cursor = MatrixCursor(projection ?: DOCUMENT_COLUMNS).also { cursor ->
        val file = fileForId(documentId)
        if (!file.exists()) {
            if (rootDirectory.resolve(HYPEROS_ILLEGAL_ARGUMENT_SENTINEL).exists()) {
                // HyperOS ExternalStorageProvider wraps a missing direct-id query
                // in IllegalArgumentException whose cause is FileNotFoundException,
                // rather than throwing FileNotFoundException directly.
                throw IllegalArgumentException(
                    "Failed to determine if $documentId is child of $ROOT_DOCUMENT_ID",
                    FileNotFoundException("Missing file for $documentId at ${file.absolutePath}"),
                )
            }
            throw FileNotFoundException("Unknown document $documentId")
        }
        includeDocument(cursor, file)
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?,
    ): Cursor = MatrixCursor(projection ?: DOCUMENT_COLUMNS).also { cursor ->
        if (hasXiaomiEmptyChildQueryBehavior()) return@also
        fileForId(parentDocumentId).listFiles()?.sortedBy(File::getName)?.forEach {
            includeDocument(cursor, it)
        }
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean =
        documentId.startsWith("$parentDocumentId/")

    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String,
    ): String {
        val parent = fileForId(parentDocumentId)
        var target = File(parent, displayName)
        if (
            mimeType == Document.MIME_TYPE_DIR &&
            rootDirectory.resolve(AUTO_RENAME_DIRECTORY_SENTINEL).exists()
        ) {
            target = File(parent, "$displayName (1)")
        } else if (hasXiaomiEmptyChildQueryBehavior() && target.exists()) {
            var suffix = 1
            while (target.exists()) {
                target = File(parent, "$displayName ($suffix)")
                suffix++
            }
        }
        val created = if (mimeType == Document.MIME_TYPE_DIR) {
            target.mkdir()
        } else {
            target.createNewFile()
        }
        if (!created) throw FileNotFoundException("Could not create $displayName")
        return idForFile(target)
    }

    override fun deleteDocument(documentId: String) {
        if (!fileForId(documentId).deleteRecursively()) {
            throw FileNotFoundException("Could not delete $documentId")
        }
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?,
    ): ParcelFileDescriptor {
        if (mode == "wa" && rootDirectory.resolve(REJECT_APPEND_SENTINEL).exists()) {
            throw FileNotFoundException("Append mode rejected for fallback test")
        }
        val acceptedMode = when (mode) {
            "r", "w", "wt", "wa" -> mode
            else -> throw FileNotFoundException("Unsupported mode $mode")
        }
        return ParcelFileDescriptor.open(
            fileForId(documentId),
            ParcelFileDescriptor.parseMode(acceptedMode),
        )
    }

    private fun includeDocument(cursor: MatrixCursor, file: File) {
        val row = cursor.newRow()
        addIfRequested(row, cursor, Document.COLUMN_DOCUMENT_ID, idForFile(file))
        addIfRequested(row, cursor, Document.COLUMN_DISPLAY_NAME, file.name)
        addIfRequested(
            row,
            cursor,
            Document.COLUMN_MIME_TYPE,
            if (file.isDirectory) Document.MIME_TYPE_DIR else mimeTypeFor(file.name),
        )
        addIfRequested(
            row,
            cursor,
            Document.COLUMN_FLAGS,
            if (file.isDirectory) {
                Document.FLAG_DIR_SUPPORTS_CREATE or
                    Document.FLAG_SUPPORTS_WRITE or
                    Document.FLAG_SUPPORTS_DELETE
            } else {
                Document.FLAG_SUPPORTS_WRITE or Document.FLAG_SUPPORTS_DELETE
            },
        )
        addIfRequested(row, cursor, Document.COLUMN_SIZE, file.length())
    }

    private fun fileForId(documentId: String): File {
        if (documentId == ROOT_DOCUMENT_ID) return rootDirectory
        if (!documentId.startsWith("$ROOT_DOCUMENT_ID/")) {
            throw FileNotFoundException("Unknown document $documentId")
        }
        val file = rootDirectory.resolve(documentId.removePrefix("$ROOT_DOCUMENT_ID/"))
        if (!file.canonicalPath.startsWith(rootDirectory.canonicalPath + File.separator)) {
            throw FileNotFoundException("Invalid document $documentId")
        }
        return file
    }

    private fun idForFile(file: File): String = if (file == rootDirectory) {
        ROOT_DOCUMENT_ID
    } else {
        "$ROOT_DOCUMENT_ID/${file.relativeTo(rootDirectory).invariantSeparatorsPath}"
    }

    private fun hasXiaomiEmptyChildQueryBehavior(): Boolean =
        rootDirectory.resolve(XIAOMI_EMPTY_CHILD_QUERY_SENTINEL).exists()

    private fun addIfRequested(
        row: MatrixCursor.RowBuilder,
        cursor: MatrixCursor,
        column: String,
        value: Any,
    ) {
        if (cursor.getColumnIndex(column) != -1) row.add(column, value)
    }

    private fun mimeTypeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "png" -> "image/png"
        "jpg", "jpeg" -> "image/jpeg"
        "gif" -> "image/gif"
        "webp" -> "image/webp"
        "md" -> "text/markdown"
        "pdf" -> "application/pdf"
        "mp4" -> "video/mp4"
        "mov" -> "video/quicktime"
        else -> "application/octet-stream"
    }

    companion object {
        const val ROOT_DOCUMENT_ID = "root"
        const val REJECT_APPEND_SENTINEL = ".reject_append"
        const val XIAOMI_EMPTY_CHILD_QUERY_SENTINEL = ".xiaomi_empty_child_query"
        const val AUTO_RENAME_DIRECTORY_SENTINEL = ".auto_rename_directory"
        const val HYPEROS_ILLEGAL_ARGUMENT_SENTINEL = ".hyperos_illegal_argument"
        private const val TEST_DIRECTORY = "saf-vault-test-documents"

        private val ROOT_COLUMNS = arrayOf(
            Root.COLUMN_ROOT_ID,
            Root.COLUMN_DOCUMENT_ID,
            Root.COLUMN_TITLE,
            Root.COLUMN_FLAGS,
            Root.COLUMN_MIME_TYPES,
        )
        private val DOCUMENT_COLUMNS = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_FLAGS,
            Document.COLUMN_SIZE,
        )
    }
}
