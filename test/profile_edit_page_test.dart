import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/main/profile_edit_page.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(home: ProfileEditPage());
  }

  Future<void> pumpLoaded(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
  }

  group('ProfileEditPage', () {
    testWidgets('shows loading first and then renders the profile form', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('프로필 정보'), findsOneWidget);
      expect(find.text('개인정보 수정'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
    });

    testWidgets('keeps the new password field obscured', (tester) async {
      await pumpLoaded(tester);

      final passwordField = find.widgetWithText(TextFormField, '새 비밀번호를 입력하세요');
      final editableText = tester.widget<EditableText>(
        find.descendant(of: passwordField, matching: find.byType(EditableText)),
      );

      expect(editableText.obscureText, isTrue);
    });

    testWidgets('validates invalid height after update confirmation', (
      tester,
    ) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '키(cm)를 입력하세요'),
        '300',
      );
      await tester.tap(find.text('개인정보 수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();

      expect(find.text('키는 1~299cm 범위로 입력해주세요.'), findsOneWidget);
      expect(find.byType(ProfileEditPage), findsOneWidget);
    });

    testWidgets('validates invalid weight after update confirmation', (
      tester,
    ) async {
      await pumpLoaded(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '몸무게(kg)를 입력하세요'),
        '500',
      );
      await tester.tap(find.text('개인정보 수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();

      expect(find.text('몸무게는 1~499kg 범위로 입력해주세요.'), findsOneWidget);
      expect(find.byType(ProfileEditPage), findsOneWidget);
    });

    testWidgets('dismisses the logout dialog when cancelled', (tester) async {
      await pumpLoaded(tester);

      await tester.ensureVisible(find.text('로그아웃'));
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();

      expect(find.text('정말로 로그아웃 하시겠습니까?'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('정말로 로그아웃 하시겠습니까?'), findsNothing);
      expect(find.byType(ProfileEditPage), findsOneWidget);
    });
  });
}
