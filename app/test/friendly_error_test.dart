import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/state.dart';

void main() {
  AnyhowException raw(String chain) => AnyhowException(
    'network: error sending request for url (https://music.163.com/x)\n\nCaused by:\n$chain\n\nStack backtrace:\n   0: foo::bar',
  );

  test('网络错误换成一句人话', () {
    expect(friendlyError(raw('    2: dns error\n    3: failed to lookup address information')), '无法解析服务器地址，请检查网络');
    expect(
      friendlyError(raw('    3: tcp connect error\n    4: Connection refused (os error 111)')),
      '无法连接服务器，请检查网络或代理设置',
    );
    expect(friendlyError(raw('    1: operation timed out')), '网络连接超时，请稍后重试');
    expect(friendlyError(raw('    1: something else')), '网络连接失败，请检查网络后重试');
  });

  test('其它错误去掉包装和调用栈', () {
    expect(friendlyError(AnyhowException('api error 405: 操作过于频繁\n\nStack backtrace:\n 0: x')), '操作过于频繁');
    expect(
      friendlyError(AnyhowException('无法连接 GitHub，请检查网络或代理后重试\n\nStack backtrace:\n 0: x')),
      '无法连接 GitHub，请检查网络或代理后重试',
    );
    expect(friendlyError('x' * 300).length, 121);
  });
}
