package com.dfw.communication

import android.app.NotificationManager
import android.content.Context
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build

object CallAlertController {
    private var ringtone: Ringtone? = null

    @Synchronized
    fun start(context: Context) {
        stop(context)
        ringtone = RingtoneManager.getRingtone(
            context.applicationContext,
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        )?.apply {
            if (Build.VERSION.SDK_INT >= 28) isLooping = true
            play()
        }
    }

    @Synchronized
    fun stop(context: Context) {
        ringtone?.stop()
        ringtone = null
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(2001)
    }
}
