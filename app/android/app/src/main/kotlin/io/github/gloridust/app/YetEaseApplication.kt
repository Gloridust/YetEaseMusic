package io.github.gloridust.app

import android.app.Application

class YetEaseApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Rust 内核（cpal 的 AAudio 后端等）需要 JavaVM 与 Context，必须在 Dart 调用 Rust 之前交过去。
        // 与 Dart 侧 dlopen 的是同一个库文件，两边共享同一份状态。
        System.loadLibrary("rust_lib_app")
        nativeInit(this)
    }

    private external fun nativeInit(context: android.content.Context)
}
