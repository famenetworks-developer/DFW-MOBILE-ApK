package com.dfw.communication

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.MethodChannel

object AudioRouteManager {
    private lateinit var appContext: Context
    private lateinit var audio: AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var channel: MethodChannel? = null
    private var callbackRegistered = false
    private var preferredRoute: String? = null
    private var proximityLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) = devicesChanged()
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) = devicesChanged()
    }

    @Synchronized
    fun attach(context: Context, methodChannel: MethodChannel) {
        appContext = context.applicationContext
        audio = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        channel = methodChannel
    }

    @Synchronized
    fun start(): Map<String, Any?> {
        audio.mode = AudioManager.MODE_IN_COMMUNICATION
        requestFocus()
        if (!callbackRegistered) {
            audio.registerAudioDeviceCallback(deviceCallback, mainHandler)
            callbackRegistered = true
        }
        val routes = availableRoutes()
        val requested = preferredRoute
        val target = when {
            requested != null && routes.any { it["id"] == requested } -> requested
            routes.any { it["id"] == "bluetooth" } -> "bluetooth"
            routes.any { it["id"] == "wired" } -> "wired"
            routes.any { it["id"] == "earpiece" } -> "earpiece"
            else -> "speaker"
        }
        select(target)
        return state()
    }

    @Synchronized
    fun stop() {
        if (!::audio.isInitialized) return
        if (callbackRegistered) {
            audio.unregisterAudioDeviceCallback(deviceCallback)
            callbackRegistered = false
        }
        if (Build.VERSION.SDK_INT >= 31) audio.clearCommunicationDevice()
        @Suppress("DEPRECATION")
        if (audio.isBluetoothScoOn) {
            audio.isBluetoothScoOn = false
            audio.stopBluetoothSco()
        }
        @Suppress("DEPRECATION")
        run { audio.isSpeakerphoneOn = false }
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let(audio::abandonAudioFocusRequest)
        else @Suppress("DEPRECATION") audio.abandonAudioFocus(null)
        focusRequest = null
        preferredRoute = null
        updateProximity(false)
        audio.mode = AudioManager.MODE_NORMAL
    }

    @Synchronized
    fun select(route: String): Map<String, Any?> {
        val available = availableRoutes()
        require(available.any { it["id"] == route }) { "Audio route is not available: $route" }

        if (Build.VERSION.SDK_INT >= 31) {
            val device = audio.availableCommunicationDevices.firstOrNull { routeId(it) == route }
                ?: throw IllegalStateException("Audio route disappeared: $route")
            check(audio.setCommunicationDevice(device)) { "Android rejected audio route: $route" }
        } else {
            @Suppress("DEPRECATION")
            when (route) {
                "speaker" -> {
                    if (audio.isBluetoothScoOn) audio.stopBluetoothSco()
                    audio.isBluetoothScoOn = false
                    audio.isSpeakerphoneOn = true
                }
                "bluetooth" -> {
                    audio.isSpeakerphoneOn = false
                    audio.startBluetoothSco()
                    audio.isBluetoothScoOn = true
                }
                else -> {
                    if (audio.isBluetoothScoOn) audio.stopBluetoothSco()
                    audio.isBluetoothScoOn = false
                    audio.isSpeakerphoneOn = false
                }
            }
        }
        preferredRoute = route
        updateProximity(route == "earpiece")
        publishState()
        return state()
    }

    @Synchronized
    fun state(): Map<String, Any?> {
        val routes = availableRoutes()
        val selected = if (Build.VERSION.SDK_INT >= 31) {
            audio.communicationDevice?.let(::routeId)
        } else @Suppress("DEPRECATION") {
            when {
                audio.isBluetoothScoOn -> "bluetooth"
                audio.isSpeakerphoneOn -> "speaker"
                routes.any { it["id"] == "wired" } -> "wired"
                else -> "earpiece"
            }
        }
        return mapOf("routes" to routes, "selected" to selected)
    }

    private fun requestFocus() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest?.let(audio::abandonAudioFocusRequest)
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(attributes)
                .setAcceptsDelayedFocusGain(false)
                .build()
            audio.requestAudioFocus(focusRequest!!)
        } else @Suppress("DEPRECATION") {
            audio.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun availableRoutes(): List<Map<String, String>> {
        val devices = if (Build.VERSION.SDK_INT >= 31) {
            audio.availableCommunicationDevices
        } else {
            audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
        }
        val found = linkedMapOf<String, String>()
        devices.forEach { device ->
            val id = routeId(device) ?: return@forEach
            found.putIfAbsent(id, routeLabel(id))
        }
        if (!found.containsKey("speaker")) found["speaker"] = routeLabel("speaker")
        return found.map { (id, label) -> mapOf("id" to id, "label" to label) }
    }

    private fun routeId(device: AudioDeviceInfo): String? = when (device.type) {
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLE_HEADSET -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET -> "wired"
        else -> null
    }

    private fun routeLabel(id: String): String = when (id) {
        "earpiece" -> "Phone"
        "speaker" -> "Speaker"
        "bluetooth" -> "Bluetooth"
        "wired" -> "Wired headset"
        else -> id
    }

    private fun devicesChanged() {
        synchronized(this) {
            val routes = availableRoutes()
            if (preferredRoute != null && routes.none { it["id"] == preferredRoute }) {
                preferredRoute = null
                val fallback = when {
                    routes.any { it["id"] == "wired" } -> "wired"
                    routes.any { it["id"] == "earpiece" } -> "earpiece"
                    else -> "speaker"
                }
                runCatching { select(fallback) }
            }
            publishState()
        }
    }

    private fun publishState() {
        val snapshot = state()
        mainHandler.post { channel?.invokeMethod("audioRoutesChanged", snapshot) }
    }

    private fun updateProximity(enabled: Boolean) {
        if (enabled) {
            if (proximityLock?.isHeld == true) return
            val power = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
            proximityLock = power.newWakeLock(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                "DFWCommunication:call-proximity"
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        } else {
            proximityLock?.takeIf { it.isHeld }?.release()
            proximityLock = null
        }
    }
}
