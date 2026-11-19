package com.dfw.communication

import android.app.*
import android.content.*
import android.media.*
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var notifications: NotificationManager
    private lateinit var audio: AudioManager
    private var ringtone: Ringtone? = null
    private var focusRequest: AudioFocusRequest? = null
    private lateinit var methodChannel: MethodChannel

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get("dfw_main_engine")

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        FlutterEngineCache.getInstance().put("dfw_main_engine", engine)
        notifications = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        audio = getSystemService(AUDIO_SERVICE) as AudioManager
        createChannels()
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.dfw.communication/native")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> { ContextCompat.startForegroundService(this, Intent(this, CommunicationService::class.java)); result.success(null) }
                "stopService" -> { stopService(Intent(this, CommunicationService::class.java)); result.success(null) }
                "startRinging" -> { startRinging(call.argument<String>("caller") ?: "Incoming call"); result.success(null) }
                "stopRinging" -> { stopRinging(); result.success(null) }
                "startCallAudio" -> { startCallAudio(); result.success(null) }
                "stopCallAudio" -> { stopCallAudio(); result.success(null) }
                "showMessage" -> { showMessage(call.argument<String>("title") ?: "New message", call.argument<String>("body") ?: ""); result.success(null) }
                else -> result.notImplemented()
            }
        }
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
        ringtone = RingtoneManager.getRingtone(applicationContext, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))?.apply {
            if (Build.VERSION.SDK_INT >= 28) isLooping = true
            play()
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val pending = PendingIntent.getActivity(this, 20, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
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
            .addAction(android.R.drawable.sym_action_call, "Answer", answer)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", decline)
            .setFullScreenIntent(pending, true).build()
        notifications.notify(2001, notification)
    }

    private fun stopRinging() {
        ringtone?.stop(); ringtone = null; notifications.cancel(2001)
    }

    private fun startCallAudio() {
        stopRinging()
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        @Suppress("DEPRECATION")
        audio.isSpeakerphoneOn = false
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).setAudioAttributes(attributes).build()
            audio.requestAudioFocus(focusRequest!!)
        } else @Suppress("DEPRECATION") audio.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
    }

    private fun stopCallAudio() {
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audio.abandonAudioFocusRequest(it) }
        else @Suppress("DEPRECATION") audio.abandonAudioFocus(null)
        focusRequest = null
        @Suppress("DEPRECATION")
        audio.isSpeakerphoneOn = false
        audio.mode = AudioManager.MODE_NORMAL
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
