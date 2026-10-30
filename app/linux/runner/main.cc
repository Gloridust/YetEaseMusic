#include "my_application.h"

#include <string.h>

// NVIDIA 驱动在 Wayland 下默认优先用新的 libnvidia-egl-wayland2。实测它会把每帧的
// wl_buffer.release 事件排进一个从不处理的队列，长时间运行后积压到几 GB 内存
// （0.2.9 连续开 3 天约 4 GB）。机器上同时装着旧版 libnvidia-egl-wayland 时，
// 启动前把 wayland2 从 EGL 外部平台列表里去掉，改用旧版。
// 用户自己设置了这两个变量，或设 YETEASE_EGL_WAYLAND2=1 时不干预。
static void avoid_nvidia_egl_wayland2() {
  if (g_getenv("__EGL_EXTERNAL_PLATFORM_CONFIG_FILENAMES") != nullptr ||
      g_getenv("__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS") != nullptr ||
      g_strcmp0(g_getenv("YETEASE_EGL_WAYLAND2"), "1") == 0) {
    return;
  }
  // libglvnd 的默认搜索目录，/etc 下的同名文件优先
  const char* dirs[] = {"/etc/egl/egl_external_platform.d",
                        "/usr/share/egl/egl_external_platform.d"};
  g_autoptr(GHashTable) seen = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, nullptr);
  g_autoptr(GPtrArray) keep = g_ptr_array_new_with_free_func(g_free);
  gboolean has_wayland2 = FALSE;
  gboolean has_wayland1 = FALSE;
  for (const char* dir : dirs) {
    g_autoptr(GDir) d = g_dir_open(dir, 0, nullptr);
    if (d == nullptr) continue;
    const char* name;
    while ((name = g_dir_read_name(d)) != nullptr) {
      if (!g_str_has_suffix(name, ".json") || g_hash_table_contains(seen, name)) continue;
      g_hash_table_add(seen, g_strdup(name));
      g_autofree char* path = g_build_filename(dir, name, nullptr);
      g_autofree char* text = nullptr;
      if (!g_file_get_contents(path, &text, nullptr, nullptr)) continue;
      if (strstr(text, "libnvidia-egl-wayland2") != nullptr) {
        has_wayland2 = TRUE;
        continue;
      }
      if (strstr(text, "libnvidia-egl-wayland.so") != nullptr) has_wayland1 = TRUE;
      g_ptr_array_add(keep, g_steal_pointer(&path));
    }
  }
  // 没有旧版可退时保持原样，否则 Wayland 下就没有 EGL 平台可用了
  if (!has_wayland2 || !has_wayland1) return;
  g_ptr_array_add(keep, nullptr);
  g_autofree char* list = g_strjoinv(":", reinterpret_cast<char**>(keep->pdata));
  g_setenv("__EGL_EXTERNAL_PLATFORM_CONFIG_FILENAMES", list, TRUE);
}

int main(int argc, char** argv) {
  avoid_nvidia_egl_wayland2();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
