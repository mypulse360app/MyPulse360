import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/pharmacist/presentation/widgets/verification_checklist.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  testWidgets('renders every verification step', (tester) async {
    await tester.pumpWidget(
      wrap(VerificationChecklist(checked: const {}, onChanged: (_) {})),
    );

    for (final step in kVerificationSteps) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('tapping a step reports its index via onChanged', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(VerificationChecklist(checked: const {}, onChanged: (i) => tapped = i)),
    );

    await tester.tap(find.text(kVerificationSteps[1]));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('checked steps render as checked checkboxes', (tester) async {
    await tester.pumpWidget(
      wrap(VerificationChecklist(checked: const {0, 2}, onChanged: (_) {})),
    );

    // We use a custom checkbox UI with Icons.check_rounded, so we expect exactly 2
    // of them for the 2 checked items.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    
    // The top-level summary also has a checklist icon or a verified icon depending on state, 
    // but the list items themselves use check_rounded.
  });
}
