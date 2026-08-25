package com.inbox.inbox_app

import android.content.Intent
import android.text.SpannableString
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareIntentParserTest {
    private val parser = ShareIntentParser(
        ApplicationProvider.getApplicationContext<android.content.Context>().contentResolver,
    )

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
}
