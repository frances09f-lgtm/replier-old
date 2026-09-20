package com.example.auto_reply_assistant.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SelfSentReplyGuardTest {
    private val sent = setOf("sahara.", "canberra.")

    @Test
    fun ignoresContactMessageThatMentionsPastReply() {
        assertFalse(
            SelfSentReplyGuard.isSelfSentMessage(
                message = "Right! Canberra.\n\nNext:\nWhich country has the most time zones?",
                sender = "Meta AI",
                sentReplyTexts = sent,
            ),
        )
    }

    @Test
    fun detectsOwnOutgoingNotification() {
        assertTrue(
            SelfSentReplyGuard.isSelfSentMessage(
                message = "Canberra.",
                sender = "You",
                sentReplyTexts = sent,
            ),
        )
    }

    @Test
    fun doesNotTreatContactExactReplyWordAsSelfSent() {
        assertFalse(
            SelfSentReplyGuard.isSelfSentMessage(
                message = "Sahara.",
                sender = "Meta AI",
                sentReplyTexts = sent,
            ),
        )
    }
}
