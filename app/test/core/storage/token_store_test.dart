// TokenStore contract tests. SecureTokenStore is intentionally not exercised
// here — it talks to the OS keychain/keystore, which isn't available on the
// test host (and the app degrades gracefully when it isn't). The in-memory
// implementation and the value semantics of AuthTokens are what feature code
// depends on.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/storage/token_store.dart';

void main() {
  group('AuthTokens', () {
    test('value equality is by both fields', () {
      const a = AuthTokens(accessToken: 'x', refreshToken: 'y');
      const b = AuthTokens(accessToken: 'x', refreshToken: 'y');
      const c = AuthTokens(accessToken: 'x', refreshToken: 'z');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith replaces only the named field', () {
      const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

      expect(
        tokens.copyWith(accessToken: 'a2'),
        const AuthTokens(accessToken: 'a2', refreshToken: 'r'),
      );
      expect(
        tokens.copyWith(refreshToken: 'r2'),
        const AuthTokens(accessToken: 'a', refreshToken: 'r2'),
      );
    });
  });

  group('InMemoryTokenStore', () {
    test('starts empty unless seeded', () async {
      expect(await InMemoryTokenStore().read(), isNull);
      const seed = AuthTokens(accessToken: 'a', refreshToken: 'r');
      expect(await InMemoryTokenStore(seed).read(), seed);
    });

    test('save overwrites and clear removes', () async {
      final store = InMemoryTokenStore();

      await store.save(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
      expect(await store.read(),
          const AuthTokens(accessToken: 'a', refreshToken: 'r'));

      await store.save(const AuthTokens(accessToken: 'a2', refreshToken: 'r2'));
      expect(await store.read(),
          const AuthTokens(accessToken: 'a2', refreshToken: 'r2'));

      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
