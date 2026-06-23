package com.example.auto_reply_assistant.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

/**
 * AccessibilityService for sending replies when direct reply API is unavailable.
 * 
 * IMPORTANT: This service is only used as a fallback when the official notification
 * direct reply API is not available. It requires explicit user permission and is
 * designed to assist users with disabilities.
 * 
 * WARNING: Automated interaction with WhatsApp or Instagram may violate their Terms of Service.
 * This implementation should be used carefully and only with user consent.
 */
class AutoReplyAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AccessibilityService"
        private const val CHANNEL = "com.example.auto_reply_assistant/accessibility"
        private var methodChannel: MethodChannel? = null
        private var instance: AutoReplyAccessibilityService? = null
        private var pendingReply: PendingReply? = null

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        fun getInstance(): AutoReplyAccessibilityService? {
            return instance
        }

        fun sendReply(packageName: String, replyText: String) {
            instance?.performReply(packageName, replyText)
        }

        data class PendingReply(
            val packageName: String,
            val replyText: String
        )
    }

    private val supportedPackages = listOf(
        "com.whatsapp",
        "com.instagram.android"
    )

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "AccessibilityService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "AccessibilityService destroyed")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        when (event.eventType) {
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                val packageName = event.packageName?.toString()
                if (supportedPackages.contains(packageName)) {
                    Log.d(TAG, "Notification event from $packageName")
                }
            }
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                // Check if we need to perform a pending reply
                pendingReply?.let { reply ->
                    if (event.packageName?.toString() == reply.packageName) {
                        performReply(reply.packageName, reply.replyText)
                        pendingReply = null
                    }
                }
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "AccessibilityService interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "AccessibilityService connected")
        methodChannel?.invokeMethod("onServiceConnected", null)
    }

    /**
     * Perform reply using accessibility features.
     * This is a fallback method when direct reply API is unavailable.
     * 
     * WARNING: This method simulates user interaction and may violate app ToS.
     * Use only with explicit user consent.
     */
    private fun performReply(packageName: String, replyText: String) {
        try {
            val rootInActiveWindow = rootInActiveWindow ?: run {
                Log.e(TAG, "Root node not available")
                methodChannel?.invokeMethod("onReplyFailed", "Root node not available")
                return
            }

            Log.d(TAG, "Attempting to send reply to $packageName")

            // Find the input field and send button
            val inputField = findInputField(rootInActiveWindow)
            val sendButton = findSendButton(rootInActiveWindow)

            if (inputField != null) {
                // Focus on input field
                inputField.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                
                // Set text
                val bundle = Bundle()
                bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, replyText)
                inputField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
                
                Log.d(TAG, "Text set in input field")
                
                // Click send button if found
                if (sendButton != null) {
                    sendButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    Log.d(TAG, "Send button clicked")
                    methodChannel?.invokeMethod("onReplySuccess", null)
                } else {
                    // Try to find and click send button by text
                    clickSendButtonByText(rootInActiveWindow)
                }
            } else {
                Log.e(TAG, "Input field not found")
                methodChannel?.invokeMethod("onReplyFailed", "Input field not found")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error performing reply", e)
            methodChannel?.invokeMethod("onReplyFailed", e.message)
        }
    }

    private fun findInputField(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val result = findInputField(child)
            if (result != null) {
                return result
            }
        }
        return null
    }

    private fun findSendButton(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isClickable && node.text?.toString()?.lowercase()?.contains("send") == true) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val result = findSendButton(child)
            if (result != null) {
                return result
            }
        }
        return null
    }

    private fun clickSendButtonByText(node: AccessibilityNodeInfo) {
        val sendButtonTexts = listOf("send", "→", "➤")
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val text = child.text?.toString()?.lowercase() ?: ""
            
            if (sendButtonTexts.any { text.contains(it) } && child.isClickable) {
                child.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                Log.d(TAG, "Send button clicked by text")
                methodChannel?.invokeMethod("onReplySuccess", null)
                return
            }
            
            clickSendButtonByText(child)
        }
    }

    /**
     * Perform a gesture to click on a specific node
     */
    private fun performClick(node: AccessibilityNodeInfo) {
        val bounds = android.graphics.Rect()
        node.getBoundsInScreen(bounds)
        val path = Path()
        path.moveTo(bounds.centerX().toFloat(), bounds.centerY().toFloat())
        
        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 100))
        
        dispatchGesture(gestureBuilder.build(), null, null)
    }
}
