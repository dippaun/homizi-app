import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';

void main() {
  testWidgets('sign-in fields take focus and the soft keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HomiziApp()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('splash-sign-in')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final contact = find.byKey(const Key('contact-field'));
    await tester.tap(contact);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    final contactEditable = tester.widget<EditableText>(
      find.descendant(of: contact, matching: find.byType(EditableText)),
    );
    expect(contactEditable.focusNode.hasFocus, isTrue);
    await tester.enterText(contact, '9988776655');
    expect(find.text('9988776655'), findsOneWidget);
    expect(_blocked(tester, contact), isFalse);

    final code = find.byKey(const Key('otp-field'));
    await tester.tap(code);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    final codeEditable = tester.widget<EditableText>(
      find.descendant(of: code, matching: find.byType(EditableText)),
    );
    expect(codeEditable.focusNode.hasFocus, isTrue);
    await tester.enterText(code, '000000');
    expect(find.text('000000'), findsWidgets);
    expect(_blocked(tester, code), isFalse);
  });
}

bool _blocked(WidgetTester tester, Finder field) {
  var blocked = false;
  tester.element(field).visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is AbsorbPointer && widget.absorbing) {
      blocked = true;
    }
    if (widget is IgnorePointer && widget.ignoring) {
      blocked = true;
    }
    return true;
  });
  return blocked;
}
