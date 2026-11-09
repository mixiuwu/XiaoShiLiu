import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xiaoshiliu_app/features/common/coming_soon.dart';

void main() {
  testWidgets('ComingSoon 渲染标题与占位文案', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ComingSoon(title: '钱包')),
    );
    expect(find.text('钱包'), findsOneWidget);
    expect(find.text('功能开发中…'), findsOneWidget);
  });
}
