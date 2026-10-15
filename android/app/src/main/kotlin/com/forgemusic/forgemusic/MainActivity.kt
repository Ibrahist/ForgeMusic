package com.forgemusic.forgemusic

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentUris
import android.media.AudioManager
import android.os.Build
import android.provider.MediaStore
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.roundToInt

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryVideos" -> {
                        try {
                            result.success(queryVideos())
                        } catch (error: SecurityException) {
                            result.error("permission", "Video access is still off.", null)
                        }
                    }
                    "getVolume" -> result.success(readVolume())
                    "setVolume" -> {
                        val volume = call.argument<Double>("volume") ?: 0.0
                        writeVolume(volume)
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "notify" -> {
                        val title = call.argument<String>("title") ?: "Forgemusic"
                        val body = call.argument<String>("body") ?: ""
                        postArtistNote(title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun queryVideos(): List<Map<String, Any?>> {
        val videos = mutableListOf<Map<String, Any?>>()
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.DATA,
        )
        contentResolver.query(
            collection,
            projection,
            null,
            null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val widthColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val heightColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val path = cursor.getString(dataColumn)
                videos.add(
                    mapOf(
                        "id" to id.toString(),
                        "title" to cursor.getString(titleColumn),
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "durationMs" to cursor.getLong(durationColumn),
                        "sizeBytes" to cursor.getLong(sizeColumn),
                        "width" to cursor.getInt(widthColumn),
                        "height" to cursor.getInt(heightColumn),
                        "folder" to (path?.let { File(it).parent } ?: ""),
                    ),
                )
            }
        }
        return videos
    }

    private fun audioManager(): AudioManager {
        return getSystemService(AUDIO_SERVICE) as AudioManager
    }

    private fun readVolume(): Double {
        val manager = audioManager()
        val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return manager.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    private fun writeVolume(volume: Double) {
        val manager = audioManager()
        val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val level = (volume.coerceIn(0.0, 1.0) * max).roundToInt()
        manager.setStreamVolume(AudioManager.STREAM_MUSIC, level, 0)
    }

    private fun postArtistNote(title: String, body: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ARTIST_CHANNEL,
                "Artist alerts",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            channel.description = "New songs and uploads from artists you follow"
            manager.createNotificationChannel(channel)
        }
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, ARTIST_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        manager.notify(title.hashCode(), notification)
    }

    companion object {
        private const val CHANNEL = "com.forgemusic/device"
        private const val ARTIST_CHANNEL = "com.forgemusic.artists"
    }
}
