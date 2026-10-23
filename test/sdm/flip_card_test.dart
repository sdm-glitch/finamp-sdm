// SDM build (patch 0002-flipcard-lyrics): flip card + its settings.
import 'package:finamp/sdm/flip_card.dart';
import 'package:finamp/sdm/sdm_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("flip card turns over to the back and back to the front", (tester) async {
    final flipped = ValueNotifier(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SdmFlipCard(flipped: flipped, front: const Text("FRONT"), back: const Text("BACK")),
        ),
      ),
    );
    expect(find.text("FRONT"), findsOneWidget);
    expect(find.text("BACK"), findsNothing);

    flipped.value = true;
    await tester.pump(const Duration(milliseconds: 50)); // first part of the turn: still the front
    expect(find.text("FRONT"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("BACK"), findsOneWidget);
    expect(find.text("FRONT"), findsNothing);

    flipped.value = false;
    await tester.pumpAndSettle();
    expect(find.text("FRONT"), findsOneWidget);
    expect(find.text("BACK"), findsNothing);
  });

  test("prefs: defaults, clamping, persistence", () async {
    SharedPreferences.setMockInitialValues({"sdm.cardLyricsFontSize": 99.0});
    final prefs = SdmPrefs.instance;
    await prefs.ensureLoaded();
    expect(prefs.flipCardEnabled.value, isTrue);
    expect(prefs.cardLyricsFontSize.value, SdmPrefs.maxCardLyricsFontSize);

    await prefs.setCardLyricsFontSize(20);
    expect((await SharedPreferences.getInstance()).getDouble("sdm.cardLyricsFontSize"), 20);

    prefs.cardFlipped.value = true;
    await prefs.setFlipCardEnabled(false);
    expect(prefs.cardFlipped.value, isFalse);
    expect((await SharedPreferences.getInstance()).getBool("sdm.flipCardEnabled"), isFalse);
  });
}
