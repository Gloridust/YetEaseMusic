import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../src/rust/api/library.dart' as lib;

/// 封面图片：网络地址走 Rust 磁盘缓存（同一张图只下载一次，重启后直接读本地），
/// 本地路径（本地音乐里提取出的封面）直接读文件。
ImageProvider cachedImage(String url) => url.startsWith('/') ? FileImage(File(url)) : RustImage(url);

class RustImage extends ImageProvider<RustImage> {
  const RustImage(this.url);

  final String url;

  @override
  Future<RustImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(RustImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1.0, debugLabel: url);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await lib.imageBytes(url: url);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is RustImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'RustImage("$url")';
}
