package com.dfw.communication

import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.*
import android.provider.Settings
import android.provider.ContactsContract
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var notifications: NotificationManager
    private lateinit var methodChannel: MethodChannel

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get("dfw_main_engine")

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        FlutterEngineCache.getInstance().put("dfw_main_engine", engine)
        notifications = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        createChannels()
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.dfw.communication/native")
        AudioRouteManager.attach(this, methodChannel)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> { ContextCompat.startForegroundService(this, Intent(this, CommunicationService::class.java)); result.success(null) }
                "stopService" -> { stopService(Intent(this, CommunicationService::class.java)); result.success(null) }
                "startRinging" -> { startRinging(call.argument<String>("caller") ?: "Incoming call"); result.success(null) }
                "stopRinging" -> { stopRinging(); result.success(null) }
                "startCallAudio" -> result.success(AudioRouteManager.start())
                "stopCallAudio" -> { AudioRouteManager.stop(); result.success(null) }
                "getAudioRoutes" -> result.success(AudioRouteManager.state())
                "setAudioRoute" -> runCatching {
                    AudioRouteManager.select(call.argument<String>("route") ?: error("Missing route"))
                }.fold(result::success) { result.error("audio_route", it.message, null) }
                "addContact" -> runCatching {
                    startActivity(Intent(ContactsContract.Intents.Insert.ACTION).apply {
                        type = ContactsContract.RawContacts.CONTENT_TYPE
                        putExtra(ContactsContract.Intents.Insert.PHONE, call.argument<String>("number"))
                    })
                }.fold({ result.success(null) }) { result.error("contacts", it.message, null) }
                "showMessage" -> { showMessage(call.argument<String>("title") ?: "New message", call.argument<String>("body") ?: ""); result.success(null) }
                "requestFullScreenAccess" -> { requestFullScreenAccess(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestFullScreenAccess() {
        if (Build.VERSION.SDK_INT < 34 || notifications.canUseFullScreenIntent()) return
        val preferences = getSharedPreferences("dfw_native", MODE_PRIVATE)
        if (preferences.getBoolean("full_screen_prompted", false)) return
        preferences.edit().putBoolean("full_screen_prompted", true).apply()
        try {
            startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:$packageName")
            })
        } catch (_: Exception) { }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val calls = NotificationChannel("incoming_calls", "Incoming calls", NotificationManager.IMPORTANCE_HIGH).apply {
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            enableVibration(true)
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build())
        }
        val messages = NotificationChannel("messages", "Messages", NotificationManager.IMPORTANCE_HIGH).apply {
            enableVibration(true)
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
        }
        notifications.createNotificationChannels(listOf(calls, messages))
    }

    private fun startRinging(caller: String) {
        stopRinging()
        CallAlertController.start(this)
        val callScreen = Intent(this, IncomingCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("caller", caller)
        }
        val pending = PendingIntent.getActivity(this, 20, callScreen, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val answerIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("native_action", "answerCall")
        }
        val declineIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("native_action", "rejectCall")
        }
        val answer = PendingIntent.getActivity(this, 21, answerIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val decline = PendingIntent.getActivity(this, 22, declineIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, "incoming_calls")
            .setSmallIcon(android.R.drawable.sym_call_incoming).setContentTitle("Incoming call").setContentText(caller)
            .setCategory(NotificationCompat.CATEGORY_CALL).setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC).setOngoing(true).setContentIntent(pending)
            .setTimeoutAfter(120_000)
            .addAction(android.R.drawable.sym_action_call, "Answer", answer)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", decline)
            .setFullScreenIntent(pending, true).build()
        notifications.notify(2001, notification)
    }

    private fun stopRinging() {
        CallAlertController.stop(this)
    }

    private fun showMessage(title: String, body: String) {
        val pending = PendingIntent.getActivity(this, 30, packageManager.getLaunchIntentForPackage(packageName), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        notifications.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), NotificationCompat.Builder(this, "messages")
            .setSmallIcon(android.R.drawable.sym_action_chat).setContentTitle(title).setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body)).setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true).setContentIntent(pending).build())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNativeAction(intent)
    }

    override fun onPostResume() {
        super.onPostResume()
        handleNativeAction(intent)
    }

    private fun handleNativeAction(source: Intent?) {
        val action = source?.getStringExtra("native_action") ?: return
        source.removeExtra("native_action")
        if (::methodChannel.isInitialized) methodChannel.invokeMethod(action, null)
    }
}
