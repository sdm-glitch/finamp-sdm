// SDM build (patch 0005-player-ui): mini player progress fraction.
import 'package:finamp/sdm/player_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("progress fraction is position/duration, clamped, 0 when unknown", () {
    expect(sdmProgressFraction(const Duration(seconds: 30), const Duration(minutes: 2)), 0.25);
    expect(sdmProgressFraction(const Duration(minutes: 3), const Duration(minutes: 2)), 1.0);
    expect(sdmProgressFraction(null, const Duration(minutes: 2)), 0);
    expect(sdmProgressFraction(const Duration(seconds: 5), null), 0);
    expect(sdmProgressFraction(const Duration(seconds: 5), Duration.zero), 0);
  });
}
