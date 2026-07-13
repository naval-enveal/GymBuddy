import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the non-negotiable secrets rule (CLAUDE.md, M9 task 5):
/// **the app never holds the Gemini API key.** All AI calls go through the
/// backend, which is the single key-holder (server-side `ai.client` seam +
/// `GEMINI_API_KEY` env). The app only ships the *public* RevenueCat SDK key,
/// which is not a secret.
///
/// This test scans the app's shipping sources for the machinery that would only
/// be present if someone wired the Gemini key — or the Google GenAI SDK — into
/// the client. It does NOT forbid prose: comments may freely explain *why* the
/// key stays server-side. A regression (a key define, a hardcoded key, a GenAI
/// SDK dependency) fails the build instead of silently leaking the contract.
void main() {
  // Tokens that should never appear in client-shipped code/config. Each would
  // only show up if the app started holding the key or talking to Gemini
  // directly — never as a side effect of legitimate prose about the contract.
  final forbidden = <RegExp>[
    // The server-only env var name — the app has no business referencing it.
    RegExp('GEMINI_API_KEY'),
    // A live Google API key accidentally hardcoded/committed (the common
    // prefix for Google Cloud/Gemini API keys).
    RegExp('AIzaSy'),
    // A dependency on the Google GenAI SDK (npm `@google/genai`, the Dart
    // `google_generative_ai` package, etc.) — AI must be reached only via the
    // backend.
    RegExp(r'@google/genai'),
    RegExp('package:google_generative_ai'),
  ];

  // The app's shipping surface. `test/` is deliberately excluded — this guard
  // itself names the forbidden tokens, and tests don't ship.
  final roots = <String>['lib', 'android', 'ios', 'macos', 'windows', 'linux'];
  final scannedExtensions = <String>{
    '.dart',
    '.kt',
    '.java',
    '.swift',
    '.m',
    '.h',
    '.xml',
    '.plist',
    '.gradle',
    '.kts',
    '.properties',
    '.yaml',
    '.yml',
    '.json',
    '.cfg',
    '.entitlements',
  };

  Iterable<File> sourceFiles() sync* {
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        // Skip generated/build/dependency output — only first-party sources.
        final path = entity.path.replaceAll(r'\', '/');
        if (path.contains('/build/') ||
            path.contains('/.dart_tool/') ||
            path.contains('/Pods/') ||
            path.contains('/.gradle/') ||
            path.contains('/ephemeral/')) {
          continue;
        }
        final dot = path.lastIndexOf('.');
        final ext = dot == -1 ? '' : path.substring(dot);
        if (scannedExtensions.contains(ext)) yield entity;
      }
    }
  }

  test('app sources never reference the Gemini API key or the GenAI SDK', () {
    // pubspec.yaml is the dependency manifest — scan it explicitly too.
    final files = [
      ...sourceFiles(),
      if (File('pubspec.yaml').existsSync()) File('pubspec.yaml'),
    ];

    // Sanity: the scan must actually be reading the source tree (guards against
    // a silently-empty walk passing vacuously, e.g. wrong working directory).
    expect(
      files.length,
      greaterThan(10),
      reason: 'expected to scan the app source tree; found too few files — is '
          'the test running from the app/ package root?',
    );

    final violations = <String>[];
    for (final file in files) {
      final contents = file.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(contents)) {
          violations.add('${file.path} matches /${pattern.pattern}/');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'The app must never hold the Gemini API key or depend on the '
          'Google GenAI SDK — AI is reached only through the gated backend '
          'endpoints. Offending references:\n  ${violations.join('\n  ')}',
    );
  });
}
