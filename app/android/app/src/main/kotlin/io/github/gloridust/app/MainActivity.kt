package io.github.gloridust.app

import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity

// audio_service 需要由它的 Activity 持有 Flutter 引擎，后台播放时引擎才不会被销毁
class MainActivity : AudioServiceActivity() {
    // 测试用：adb shell am start … --esa yetease_args "--autoplay=<id>"
    // audio_service 预热引擎时只执行默认入口、不带启动参数，但会带上 initialRoute，
    // 所以参数放进 initialRoute 的查询串里（/?arg=…&arg=…），由 Dart 侧解析
    override fun getInitialRoute(): String? {
        val args = intent?.getStringArrayExtra("yetease_args") ?: return super.getInitialRoute()
        return args.joinToString("&", prefix = "/?") { "arg=" + Uri.encode(it) }
    }
}
