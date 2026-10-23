package io.github.gloridust.app

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service 需要由它的 Activity 持有 Flutter 引擎，后台播放时引擎才不会被销毁
class MainActivity : AudioServiceActivity()
