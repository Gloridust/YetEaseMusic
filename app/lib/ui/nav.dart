import 'package:flutter/material.dart';

/// 内容区的嵌套导航。侧边栏切换会清空栈，页面内跳转（歌单、搜索）压栈，返回键出栈。
class Nav {
  static final key = GlobalKey<NavigatorState>();
  static final location = ValueNotifier<String>('home');
  static final canPop = ValueNotifier(false);

  static Route<void> _route(String name, Widget page) => PageRouteBuilder(
    settings: RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );

  /// 侧边栏入口：替换整个栈
  static void root(String name, Widget page) {
    key.currentState?.pushAndRemoveUntil(_route(name, page), (_) => false);
  }

  static void push(String name, Widget page) {
    if (location.value == name) return;
    key.currentState?.push(_route(name, page));
  }

  static void back() => key.currentState?.maybePop();
}

class NavObserver extends NavigatorObserver {
  void _update(Route<dynamic>? r) {
    final name = r?.settings.name;
    if (name != null) Nav.location.value = name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Nav.canPop.value = Nav.key.currentState?.canPop() ?? false;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _update(newRoute);
}
