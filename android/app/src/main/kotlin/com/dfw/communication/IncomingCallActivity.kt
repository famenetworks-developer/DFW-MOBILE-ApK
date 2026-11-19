package com.dfw.communication

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class IncomingCallActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(buildCallScreen(intent.getStringExtra("caller") ?: "Unknown caller"))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        setContentView(buildCallScreen(intent.getStringExtra("caller") ?: "Unknown caller"))
    }

    private fun buildCallScreen(caller: String): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(64), dp(24), dp(42))
            setBackgroundColor(Color.rgb(8, 24, 30))
        }
        root.addView(TextView(this).apply {
            text = "DFW Communication"
            textSize = 18f
            setTextColor(Color.rgb(165, 179, 184))
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, -2))
        root.addView(TextView(this).apply {
            text = caller
            textSize = 34f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            maxLines = 2
        }, LinearLayout.LayoutParams(-1, 0, 1f).apply { topMargin = dp(26) })
        root.addView(TextView(this).apply {
            text = "Incoming call"
            textSize = 18f
            setTextColor(Color.rgb(190, 201, 205))
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(58) })

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        controls.addView(callButton(android.R.drawable.ic_menu_close_clear_cancel, Color.rgb(238, 62, 54), "Decline") {
            openFlutter("rejectCall")
        }, LinearLayout.LayoutParams(0, -2, 1f))
        controls.addView(callButton(android.R.drawable.sym_action_call, Color.rgb(52, 199, 89), "Answer") {
            openFlutter("answerCall")
        }, LinearLayout.LayoutParams(0, -2, 1f))
        root.addView(controls, LinearLayout.LayoutParams(-1, -2))
        return root
    }

    private fun callButton(icon: Int, color: Int, label: String, action: () -> Unit): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(ImageButton(context).apply {
                setImageResource(icon)
                setColorFilter(Color.WHITE)
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape = android.graphics.drawable.GradientDrawable.OVAL
                    setColor(color)
                }
                setPadding(dp(20), dp(20), dp(20), dp(20))
                contentDescription = label
                setOnClickListener { action() }
            }, LinearLayout.LayoutParams(dp(76), dp(76)))
            addView(TextView(context).apply {
                text = label
                textSize = 16f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
            }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(10) })
        }
    }

    private fun openFlutter(action: String) {
        CallAlertController.stop(this)
        val engine = FlutterEngineCache.getInstance().get("dfw_main_engine")
        if (engine != null) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.dfw.communication/native")
                .invokeMethod(action, null)
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (engine == null) putExtra("native_action", action)
        }
        if (launch != null) startActivity(launch)
        finish()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
