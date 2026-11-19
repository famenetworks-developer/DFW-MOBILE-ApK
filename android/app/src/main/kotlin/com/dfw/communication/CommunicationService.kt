package com.dfw.communication

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class CommunicationService : Service() {
    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("connection", "Communication connection", NotificationManager.IMPORTANCE_LOW))
        val pending = PendingIntent.getActivity(this, 10, packageManager.getLaunchIntentForPackage(packageName), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        startForeground(1001, NotificationCompat.Builder(this, "connection")
            .setSmallIcon(android.R.drawable.stat_sys_phone_call).setContentTitle("DFW Communication is connected")
            .setContentText("Calls and messages are available").setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE).setContentIntent(pending).build())
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null
}
