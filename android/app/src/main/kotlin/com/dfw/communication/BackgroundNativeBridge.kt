package com.dfw.communication

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.ContactsContract
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BackgroundNativeBridge(
    private val context: Context,
    engine: FlutterEngine
) {
    private val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    init {
        createChannels()
        val methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.dfw.communication/native")
        AudioRouteManager.attach(context, methodChannel)
        methodChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> result.success(null)
                    "stopService" -> {
                        context.stopService(Intent(context, CommunicationService::class.java))
                        result.success(null)
                    }
                    "startRinging" -> {
                        startRinging(call.argument<String>("caller") ?: "Incoming call")
                        result.success(null)
                    }
                    "stopRinging" -> { stopRinging(); result.success(null) }
                    "startCallAudio" -> result.success(AudioRouteManager.start())
                    "stopCallAudio" -> { AudioRouteManager.stop(); result.success(null) }
                    "getAudioRoutes" -> result.success(AudioRouteManager.state())
                    "setAudioRoute" -> runCatching {
                        AudioRouteManager.select(call.argument<String>("route") ?: error("Missing route"))
                    }.fold(result::success) { result.error("audio_route", it.message, null) }
                    "addContact" -> runCatching {
                        context.startActivity(Intent(ContactsContract.Intents.Insert.ACTION).apply {
                            type = ContactsContract.RawContacts.CONTENT_TYPE
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            putExtra(ContactsContract.Intents.Insert.PHONE, call.argument<String>("number"))
                        })
                    }.fold({ result.success(null) }) { result.error("contacts", it.message, null) }
                    "showMessage" -> {
                        showMessage(call.argument<String>("title") ?: "New message", call.argument<String>("body") ?: "")
                        result.success(null)
                    }
                    "requestFullScreenAccess" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        notifications.createNotificationChannels(listOf(
            NotificationChannel("incoming_calls", "Incoming calls", NotificationManager.IMPORTANCE_HIGH).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build()
                )
            },
            NotificationChannel("messages", "Messages", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
            }
        ))
    }

    private fun startRinging(caller: String) {
        stopRinging()
        CallAlertController.start(context)
        val callScreen = Intent(context, IncomingCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("caller", caller)
        }
        val fullScreen = PendingIntent.getActivity(context, 20, callScreen, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val answer = actionPendingIntent("answerCall", 21)
        val decline = actionPendingIntent("rejectCall", 22)
        notifications.notify(2001, NotificationCompat.Builder(context, "incoming_calls")
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle("Incoming call")
            .setContentText(caller)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(fullScreen)
            .addAction(android.R.drawable.sym_action_call, "Answer", answer)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", decline)
            .setFullScreenIntent(fullScreen, true)
            .setTimeoutAfter(120_000)
            .build())
    }

    private fun actionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)!!.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("native_action", action)
        }
        return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun stopRinging() {
        CallAlertController.stop(context)
    }

    private fun showMessage(title: String, body: String) {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = PendingIntent.getActivity(context, 30, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        notifications.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), NotificationCompat.Builder(context, "messages")
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build())
    }
}
