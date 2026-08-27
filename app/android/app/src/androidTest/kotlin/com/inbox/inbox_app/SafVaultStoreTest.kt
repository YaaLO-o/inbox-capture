package com.inbox.inbox_app

import android.content.ContentResolver
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.DocumentsContract
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.provider.ProviderTestRule
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SafVaultStoreTest {
    @get:Rule
    val providerRule = ProviderTestRule.Builder(
        TestDocumentsProvider::class.java,
        TEST_AUTHORITY,
    ).build()

    private lateinit var context: Context
    private lateinit var resolver: ContentResolver
    private lateinit var treeUri: Uri
    private lateinit var rootDocumentUri: Uri
    private lateinit var store: SafVaultStore

    @Before
    fun setUp() {
        val targetContext = ApplicationProvider.getApplicationContext<Context>()
        resolver = providerRule.resolver
        context = object : ContextWrapper(targetContext) {
            override fun getContentResolver(): ContentResolver = resolver

            override fun checkCallingOrSelfUriPermission(uri: Uri, modeFlags: Int): Int =
                PackageManager.PERMISSION_GRANTED
        }
        treeUri = DocumentsContract.buildTreeDocumentUri(
            TEST_AUTHORITY,
            TestDocumentsProvider.ROOT_DOCUMENT_ID,
        )
        rootDocumentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            TestDocumentsProvider.ROOT_DOCUMENT_ID,
        )
        store = SafVaultStore(context)
        child(rootDocumentUri, TestDocumentsProvider.REJECT_APPEND_SENTINEL)?.let {
            DocumentsContract.deleteDocument(resolver, it)
        }
        child(rootDocumentUri, "Universal Capture")?.let {
            DocumentsContract.deleteDocument(resolver, it)
        }
    }

    @Test
    fun createsLayoutImportsBytesAppendsTwiceAndDeletesAttachment() {
        val source = DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            "application/octet-stream",
            "source.bin",
        )!!
        resolver.openOutputStream(source, "wt")!!.use {
            it.write(byteArrayOf(0, 1, 2, 255.toByte()))
        }

        store.ensureLayout(treeUri)
        store.importUri(treeUri, source, "capture.bin")
        store.appendMarkdown(treeUri, "2026-08-24", "first\n")
        store.appendMarkdown(treeUri, "2026-08-24", "second\n")

        val captureDirectory = child(rootDocumentUri, "Universal Capture")!!
        val attachments = child(captureDirectory, "attachments")!!
        val imported = child(attachments, "capture.bin")!!
        assertArrayEquals(
            byteArrayOf(0, 1, 2, 255.toByte()),
            resolver.openInputStream(imported)!!.use { it.readBytes() },
        )
        val markdown = child(captureDirectory, "2026-08-24.md")!!
        assertEquals(
            "first\nsecond\n",
            resolver.openInputStream(markdown)!!.bufferedReader().use {
                it.readText()
            },
        )

        store.deleteAttachment(treeUri, "capture.bin")
        assertNull(child(attachments, "capture.bin"))
    }

    @Test
    fun readsExistingMarkdownBeforeFallbackTruncateWrite() {
        DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            "application/octet-stream",
            TestDocumentsProvider.REJECT_APPEND_SENTINEL,
        )

        store.appendMarkdown(treeUri, "2026-08-24", "first\n")
        store.appendMarkdown(treeUri, "2026-08-24", "second\n")

        val captureDirectory = child(rootDocumentUri, "Universal Capture")!!
        val markdown = child(captureDirectory, "2026-08-24.md")!!
        assertEquals(
            "first\nsecond\n",
            resolver.openInputStream(markdown)!!.bufferedReader().use {
                it.readText()
            },
        )
    }

    @Test
    fun reusesExactExistingLayoutWhenChildQueriesAreEmpty() {
        val captureDirectory = DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            "Universal Capture",
        )!!
        val attachments = DocumentsContract.createDocument(
            resolver,
            captureDirectory,
            DocumentsContract.Document.MIME_TYPE_DIR,
            "attachments",
        )!!
        val markdown = DocumentsContract.createDocument(
            resolver,
            captureDirectory,
            "text/markdown",
            "2026-08-25.md",
        )!!
        resolver.openOutputStream(markdown, "wt")!!.use {
            it.write("existing\n".toByteArray())
        }
        val sentinel = DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            "application/octet-stream",
            TestDocumentsProvider.XIAOMI_EMPTY_CHILD_QUERY_SENTINEL,
        )!!

        val firstLayout = store.ensureLayout(treeUri)
        val secondLayout = store.ensureLayout(treeUri)
        store.appendMarkdown(treeUri, "2026-08-25", "first\n")
        store.appendMarkdown(treeUri, "2026-08-25", "second\n")

        assertEquals(captureDirectory, firstLayout.capture.uri)
        assertEquals(captureDirectory, secondLayout.capture.uri)
        assertEquals(attachments, firstLayout.attachments.uri)
        assertEquals(attachments, secondLayout.attachments.uri)
        assertEquals(
            "existing\nfirst\nsecond\n",
            resolver.openInputStream(markdown)!!.bufferedReader().use { it.readText() },
        )
        DocumentsContract.deleteDocument(resolver, sentinel)
        assertTrue(
            childNames(rootDocumentUri).none {
                it.startsWith("Universal Capture (")
            },
        )
    }

    @Test
    fun rejectsAutoRenamedDirectoryFromProvider() {
        DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            "application/octet-stream",
            TestDocumentsProvider.AUTO_RENAME_DIRECTORY_SENTINEL,
        )

        assertThrows(IOException::class.java) {
            store.ensureLayout(treeUri)
        }
        assertNull(child(rootDocumentUri, "Universal Capture"))
        assertTrue(
            childNames(rootDocumentUri).none {
                it.startsWith("Universal Capture (")
            },
        )
    }

    // Regression for the 2026-08-26 P1: with the capture directory already
    // present but the day's Markdown not yet created, HyperOS
    // ExternalStorageProvider returns IllegalArgumentException with no cause on
    // a direct-id query for the missing file. Its message includes the remote
    // FileNotFoundException details. The first capture must still create the
    // file; the second must append to it without producing a duplicate.
    @Test
    fun firstCaptureCreatesDailyMarkdownAndSecondAppendsUnderHyperOSMissingQuery() {
        DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            "application/octet-stream",
            TestDocumentsProvider.HYPEROS_ILLEGAL_ARGUMENT_SENTINEL,
        )!!
        val captureDirectory = DocumentsContract.createDocument(
            resolver,
            rootDocumentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            "Universal Capture",
        )!!
        DocumentsContract.createDocument(
            resolver,
            captureDirectory,
            DocumentsContract.Document.MIME_TYPE_DIR,
            "attachments",
        )!!

        store.appendMarkdown(treeUri, "2026-08-26", "first-capture\n")
        store.appendMarkdown(treeUri, "2026-08-26", "second-capture\n")

        val markdown = child(captureDirectory, "2026-08-26.md")
        assertTrue("2026-08-26.md must be created", markdown != null)
        val markdownChildren = childNames(captureDirectory).filter {
            it.startsWith("2026-08-26")
        }
        assertEquals(
            "exactly one 2026-08-26 markdown file, no duplicate variant",
            listOf("2026-08-26.md"),
            markdownChildren,
        )
        assertEquals(
            "first-capture\nsecond-capture\n",
            resolver.openInputStream(markdown!!)!!.bufferedReader().use { it.readText() },
        )
    }

    private fun child(parent: Uri, displayName: String): Uri? {
        val parentDocumentId = DocumentsContract.getDocumentId(parent)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            parent,
            parentDocumentId,
        )
        resolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null,
            null,
            null,
        )!!.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == displayName) {
                    return DocumentsContract.buildDocumentUriUsingTree(
                        parent,
                        cursor.getString(0),
                    )
                }
            }
        }
        return null
    }

    private fun childNames(parent: Uri): List<String> {
        val parentDocumentId = DocumentsContract.getDocumentId(parent)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            parent,
            parentDocumentId,
        )
        return resolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )!!.use { cursor ->
            buildList {
                while (cursor.moveToNext()) add(cursor.getString(0))
            }
        }
    }

    private companion object {
        const val TEST_AUTHORITY = "com.android.externalstorage.documents"
    }
}
