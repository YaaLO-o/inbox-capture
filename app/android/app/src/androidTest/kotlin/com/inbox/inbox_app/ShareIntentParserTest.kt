package com.inbox.inbox_app

import android.content.Intent
import android.content.ClipData
import android.net.Uri
import android.provider.DocumentsContract
import android.text.SpannableString
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.provider.ProviderTestRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareIntentParserTest {
    private val parser = ShareIntentParser(
        ApplicationProvider.getApplicationContext<android.content.Context>().contentResolver,
    )

    @get:Rule
    val providerRule = ProviderTestRule.Builder(
        TestDocumentsProvider::class.java,
        TEST_AUTHORITY,
    ).build()

    @Test
    fun parsesNonblankTextAndPreservesOriginalValue() {
        val text = "  https://example.com/article  "
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }

        assertEquals(text, parser.parse(intent)?.text)
        assertEquals(emptyList<SharedUri>(), parser.parse(intent)?.attachments)
    }

    @Test
    fun parsesStyledTextAndPreservesCharacters() {
        val text = SpannableString("https://example.com/styled").apply {
            setSpan(android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, length, 0)
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }

        assertEquals(text.toString(), parser.parse(intent)?.text)
    }

    @Test
    fun rejectsWhitespaceOnlyText() {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, "  \n\t ")
        }

        assertNull(parser.parse(intent))
    }

    @Test
    fun rejectsMissingText() {
        val intent = Intent(Intent.ACTION_SEND).apply { type = "text/plain" }

        assertNull(parser.parse(intent))
    }

    @Test
    fun rejectsUnsupportedAction() {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, "https://example.com/article")
        }

        assertNull(parser.parse(intent))
    }

    @Test
    fun rejectsUnsupportedMimeType() {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/html"
            putExtra(Intent.EXTRA_TEXT, "<p>article</p>")
        }

        assertNull(parser.parse(intent))
    }

    @Test
    fun parsesSingleStreamWithProviderMetadata() {
        val source = createSource("截图.PNG")
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, source)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val item = ShareIntentParser(providerRule.resolver).parse(intent)!!.attachments.single()

        assertEquals(source, item.uri)
        assertEquals("截图.PNG", item.displayName)
        assertEquals("image/png", item.mimeType)
        assertEquals("png", item.extension)
    }

    @Test
    fun parsesAllCarriersInOrderAndDeduplicatesUris() {
        val image = createSource("first.png")
        val pdf = createSource("document.pdf")
        val video = createSource("clip.mp4")
        val binary = createSource("LICENSE")
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "*/*"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(image, pdf))
            clipData = ClipData("attachments", arrayOf("*/*"), ClipData.Item(image)).apply {
                addItem(ClipData.Item(video))
                addItem(ClipData.Item(binary))
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val attachments = ShareIntentParser(providerRule.resolver).parse(intent)!!.attachments

        assertEquals(listOf(image, pdf, video, binary), attachments.map { it.uri })
        assertEquals(listOf("png", "pdf", "mp4", ""), attachments.map { it.extension })
        assertEquals(
            listOf("image/png", "application/pdf", "video/mp4", "application/octet-stream"),
            attachments.map { it.mimeType },
        )
    }

    private fun createSource(name: String): Uri {
        val treeUri = DocumentsContract.buildTreeDocumentUri(
            TEST_AUTHORITY,
            TestDocumentsProvider.ROOT_DOCUMENT_ID,
        )
        val documentUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            TestDocumentsProvider.ROOT_DOCUMENT_ID,
        )
        return DocumentsContract.createDocument(
            providerRule.resolver,
            documentUri,
            "application/octet-stream",
            name,
        )!!
    }

    private companion object {
        const val TEST_AUTHORITY = "com.inbox.inbox_app.test.share.documents"
    }
}
