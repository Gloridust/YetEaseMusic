package io.github.gloridust.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// audio_service 需要由它的 Activity 持有 Flutter 引擎，后台播放时引擎才不会被销毁
class MainActivity : AudioServiceActivity() {
    // 测试用：adb shell am start … --esa yetease_args "--autoplay=<id>"
    // audio_service 预热引擎时只执行默认入口、不带启动参数，但会带上 initialRoute，
    // 所以参数放进 initialRoute 的查询串里（/?arg=…&arg=…），由 Dart 侧解析
    override fun getInitialRoute(): String? {
        val args = intent?.getStringArrayExtra("yetease_args") ?: return super.getInitialRoute()
        return args.joinToString("&", prefix = "/?") { "arg=" + Uri.encode(it) }
    }

    // Dart 侧 lib/system.dart 调用：打开网址、安装更新包
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yetease/system").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openUrl" -> {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                        result.success(null)
                    }
                    "installApk" -> result.success(installApk(File(call.arguments as String)))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("system", e.message, null)
            }
        }
    }

    /** 调起系统安装器。还没允许本应用安装应用时先打开对应的设置页，返回 false */
    private fun installApk(file: File): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            return false
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.update", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }
}
