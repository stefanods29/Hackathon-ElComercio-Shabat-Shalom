package pe.shabatshalom.vecinal

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    /** The contact picker in progress answers here once. */
    private var contactResult: MethodChannel.Result? = null

    /** The simulated notice waiting for the neighbor to answer the notifications permission. */
    private var pendingNotice: PendingNotice? = null

    private class PendingNotice(
        val title: String,
        val body: String,
        val delay: Long,
        val result: MethodChannel.Result,
    )

    /** Android 13 and later ask before the first notification; the call waits for the answer. */
    private val askNotifications =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            val pending = pendingNotice ?: return@registerForActivityResult
            pendingNotice = null
            if (granted) {
                schedule(pending.title, pending.body, pending.delay, pending.result)
            } else {
                pending.result.success("denied")
            }
        }

    /** The phone's own picker of numbers: the result grants reading only the chosen one. */
    private val pickPhone =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { picked ->
            val pending = contactResult ?: return@registerForActivityResult
            contactResult = null
            val uri = picked.data?.data
            if (picked.resultCode != Activity.RESULT_OK || uri == null) {
                pending.success(null)
                return@registerForActivityResult
            }
            try {
                contentResolver.query(
                    uri,
                    arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ),
                    null,
                    null,
                    null,
                ).use { cursor ->
                    if (cursor != null && cursor.moveToFirst()) {
                        pending.success(
                            mapOf(
                                "name" to (cursor.getString(0) ?: ""),
                                "phones" to listOfNotNull(cursor.getString(1)),
                            )
                        )
                    } else {
                        pending.success(null)
                    }
                }
            } catch (error: Exception) {
                pending.error("unavailable", error.message, null)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "pe.shabatshalom.vecinal/pantalla_sensible").setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> when (call.arguments as? Boolean) {
                    true -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    false -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    null -> result.error("invalid_arguments", null, null)
                }
                "foregroundReady" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "pe.shabatshalom.vecinal/agenda").setMethodCallHandler { call, result ->
            if (call.method != "pickContact") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (contactResult != null) {
                result.error("busy", null, null)
                return@setMethodCallHandler
            }
            contactResult = result
            try {
                pickPhone.launch(
                    Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                )
            } catch (error: ActivityNotFoundException) {
                contactResult = null
                result.error("unavailable", error.message, null)
            }
        }
        MethodChannel(messenger, "pe.shabatshalom.vecinal/avisos_locales").setMethodCallHandler { call, result ->
            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val title = call.argument<String>("title")
            val body = call.argument<String>("body")
            if (title == null || body == null) {
                result.error("invalid_arguments", null, null)
                return@setMethodCallHandler
            }
            if (pendingNotice != null) {
                result.error("busy", null, null)
                return@setMethodCallHandler
            }
            val delay = (call.argument<Int>("delayMs") ?: 0).toLong()
            if (Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) {
                pendingNotice = PendingNotice(title, body, delay, result)
                askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                return@setMethodCallHandler
            }
            schedule(title, body, delay, result)
        }
    }

    private fun schedule(title: String, body: String, delay: Long, result: MethodChannel.Result) {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager == null || !manager.areNotificationsEnabled()) {
            result.success("denied")
            return
        }
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(SIMULATED_CHANNEL, "Avisos simulados", NotificationManager.IMPORTANCE_HIGH)
            )
            // The neighbor may have silenced only this kind of notification.
            if (manager.getNotificationChannel(SIMULATED_CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) {
                result.success("denied")
                return
            }
        }
        // The app's context outlives this screen if the neighbor closes Winki before it arrives.
        val context = applicationContext
        Handler(Looper.getMainLooper()).postDelayed({ notify(context, manager, title, body) }, delay)
        result.success("scheduled")
    }

    /** A notification made on the phone itself; it never travels through a server. */
    private fun notify(context: Context, manager: NotificationManager, title: String, body: String) {
        // Tapping it brings Winki back as it was, like opening it from its icon.
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, SIMULATED_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }

    private companion object {
        const val SIMULATED_CHANNEL = "avisos_simulados"
    }
}
