import 'package:flutter/material.dart';

/// 设计规范：颜色、圆角、字号集中在这里，页面里不写魔法数。
class Tokens {
  static const accent = Color(0xFFF23D4C);
  static const accentSoft = Color(0x1AF23D4C);

  static const radiusS = 6.0;
  static const radiusM = 10.0;
  static const radiusL = 14.0;

  static const sidebarWidth = 240.0;
  static const sidebarMinWidth = 200.0;
  static const sidebarMaxWidth = 420.0;
  static const playerBarHeight = 68.0;
  static const topBarHeight = 52.0;
}

/// 随明暗主题变化的颜色
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.hover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.field,
  });

  final Color background;
  final Color sidebar;
  final Color surface;
  final Color hover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color field;

  static const light = Palette(
    background: Color(0xFFF7F9FC),
    sidebar: Color(0xFFF0F3F6),
    surface: Colors.white,
    hover: Color(0xFFE8ECF1),
    textPrimary: Color(0xFF283248),
    textSecondary: Color(0xFF6E7787),
    textTertiary: Color(0xFFA5ACB8),
    divider: Color(0xFFE6E9EF),
    field: Color(0xFFEDF0F4),
  );

  static const dark = Palette(
    background: Color(0xFF16171C),
    sidebar: Color(0xFF1C1D23),
    surface: Color(0xFF22232A),
    hover: Color(0xFF2B2C34),
    textPrimary: Color(0xFFE9EAEE),
    textSecondary: Color(0xFFA0A3AD),
    textTertiary: Color(0xFF6C6F79),
    divider: Color(0xFF2C2D35),
    field: Color(0xFF26272E),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      background: l(background, other.background),
      sidebar: l(sidebar, other.sidebar),
      surface: l(surface, other.surface),
      hover: l(hover, other.hover),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      divider: l(divider, other.divider),
      field: l(field, other.field),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// Linux 上优先用思源黑体（Noto Sans CJK），其他平台回落到系统中文字体
const _fontFallback = [
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'PingFang SC',
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'sans-serif',
];

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Tokens.accent,
      brightness: b,
      primary: Tokens.accent,
      surface: p.surface,
    ),
    scaffoldBackgroundColor: p.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.hover,
    dividerColor: p.divider,
    fontFamilyFallback: _fontFallback,
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
      fontFamilyFallback: _fontFallback,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: p.textPrimary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(Tokens.radiusS),
      ),
      textStyle: TextStyle(color: p.surface, fontSize: 12),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.all(p.textTertiary.withValues(alpha: 0.4)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.textPrimary,
      contentTextStyle: TextStyle(color: p.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusM)),
      width: 420,
    ),
  );
}

String formatMs(int ms) {
  final s = ms ~/ 1000;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

String formatCount(int n) {
  if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(n >= 100000 ? 0 : 1)}万';
  return '$n';
}

/// 网易云图片地址支持 `?param=WxH` 缩放，按显示尺寸取图省流量
String? sizedImage(String? url, int px) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('/')) return url; // 本地封面文件
  final u = url.replaceFirst('http://', 'https://');
  return '$u?param=${px}y$px';
}
