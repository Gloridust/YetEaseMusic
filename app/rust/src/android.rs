//! 安卓：把 JavaVM 与应用 Context 交给 ndk-context。
//!
//! cpal 的 AAudio 后端开流后会经 JNI 查询 AudioManager，没有初始化时直接 panic，
//! 播放引擎线程随之退出、界面一直停在缓冲中。Dart 用 dlopen 加载本库，不会触发
//! JNI_OnLoad，所以由 `YetEaseApplication.onCreate` 显式调用这里。

use jni_sys::{JNIEnv, JavaVM, jclass, jobject};

#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_gloridust_app_YetEaseApplication_nativeInit(
    env: *mut JNIEnv,
    _class: jclass,
    context: jobject,
) {
    unsafe {
        let mut vm: *mut JavaVM = std::ptr::null_mut();
        if ((**env).v1_2.GetJavaVM)(env, &mut vm) != 0 || vm.is_null() {
            return;
        }
        // 全局引用，生命周期与进程相同
        let context = ((**env).v1_2.NewGlobalRef)(env, context);
        ndk_context::initialize_android_context(vm.cast(), context.cast());
    }
}
