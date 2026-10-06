import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_vault_app/main.dart';

void main() {
  testWidgets('LoginVaultApp renders login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LoginVaultApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
  });
}
