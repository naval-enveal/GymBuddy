import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Static, app-wide metadata.
///
/// Kept tiny on purpose: its real job in M0 is to give the app a first piece of
/// Riverpod-managed state so the [ProviderScope] is exercised end-to-end (a
/// provider is defined here and read by a widget). Feature state lands in later
/// milestones under `lib/features/`.
class AppInfo {
  const AppInfo({required this.name, required this.tagline});

  final String name;
  final String tagline;
}

/// Exposes the app's display name and tagline to the widget tree.
final appInfoProvider = Provider<AppInfo>(
  (ref) => const AppInfo(
    name: 'GymBuddy',
    tagline: 'Your AI training buddy',
  ),
);
