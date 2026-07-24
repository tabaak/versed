import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/features/auth/presentation/pages/auth_page.dart';

void main() {
  testWidgets('shows the VERSED introduction and Google sign-in action', (
    tester,
  ) async {
    var signInRequested = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: AuthPage(
          onGoogleSignIn: () {
            signInRequested = true;
          },
        ),
      ),
    );

    expect(find.text('VERSED'), findsOneWidget);
    expect(find.text('Put your style\nto the test.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byKey(const ValueKey('outfit-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('outfit-2')), findsOneWidget);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();

    expect(signInRequested, isTrue);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('outfit-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('outfit-4')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
