package io.github.gloridust.app

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service 需要由它的 Activity 持有 Flutter 引擎，后台播放时引擎才不会被销毁
class MainActivity : AudioServiceActivity() {
    // 测试用：adb shell am start … --esa yetease_args "--autoplay=<id>"
    // （Flutter 自带的 dart_entrypoint_args 只认 ArrayList，adb 传不了）
    override fun getDartEntrypointArgs(): List<String>? =
        intent?.getStringArrayExtra("yetease_args")?.toList() ?: super.getDartEntrypointArgs()
}
