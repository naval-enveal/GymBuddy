import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/sensors/glasses_build_config.dart';

void main() {
  group('kGlassesChannelEnabled', () {
    test('defaults to false — the ordinary build is mock-only', () {
      // The test suite runs without `--dart-define=GLASSES_ENABLED=true`, so the
      // default consumer build must report the glasses channel as off. This is
      // the single source of truth the resolver and the build target key off.
      expect(kGlassesChannelEnabled, isFalse);
    });
  });
}
