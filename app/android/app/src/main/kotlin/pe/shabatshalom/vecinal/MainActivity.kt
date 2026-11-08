package pe.shabatshalom.vecinal

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pe.shabatshalom.vecinal/pantalla_sensible"
        ).setMethodCallHandler { call, result ->
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
    }
}
