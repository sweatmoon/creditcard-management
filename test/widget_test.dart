import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_sms_ledger/main.dart';

void main() {
  testWidgets('App loads and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 홈 화면 타이틀이 보이는지 확인
    expect(find.text('법인카드 정산'), findsOneWidget);
    // 하단 네비게이션 확인
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('내역'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
  });
}
