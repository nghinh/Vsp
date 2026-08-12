import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/components/vsp_text_field.dart';

/// A focused field drew two rings: the input's own 2dp border, plus a focus
/// ring wrapped around the entire Column — label and helper text included.
/// On screen that was two concentric rounded rectangles with the label caught
/// inside the outer one, which reads as a rendering fault, not as focus.
void main() {
  Future<void> pumpField(WidgetTester tester, {bool hasError = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VspTextField(
            label: 'Số điện thoại',
            placeholder: '+84 90 123 4567',
            helperText: 'Helper',
            hasError: hasError,
            errorText: hasError ? 'Sai rồi' : null,
          ),
        ),
      ),
    );
  }

  /// Every box inside the field that paints a border of its own.
  int borderedBoxes(WidgetTester tester) {
    return tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(VspTextField),
            matching: find.byType(Container),
          ),
        )
        .where((c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration && decoration.border != null;
        })
        .length;
  }

  testWidgets('draws one outline when focused, not a ring around the label', (
    tester,
  ) async {
    await pumpField(tester);
    expect(borderedBoxes(tester), 1, reason: 'unfocused: the input box only');

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(
      find.byType(TextField).evaluate().single.findAncestorStateOfType(),
      isNotNull,
    );
    expect(
      borderedBoxes(tester),
      1,
      reason: 'focused: still the input box only — no second ring',
    );
  });

  testWidgets('an errored field does not stack a ring either', (tester) async {
    await pumpField(tester, hasError: true);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(borderedBoxes(tester), 1);
    expect(find.text('Sai rồi'), findsOneWidget);
  });

  testWidgets('label and helper stay outside the outlined box', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final box = find.descendant(
      of: find.byType(VspTextField),
      matching: find.byType(TextField),
    );
    // The label sits above the outlined input, never enclosed by it.
    expect(
      tester.getTopLeft(find.text('Số điện thoại')).dy,
      lessThan(tester.getTopLeft(box).dy),
    );
    expect(
      tester.getTopLeft(find.text('Helper')).dy,
      greaterThan(tester.getTopLeft(box).dy),
    );
  });
}
