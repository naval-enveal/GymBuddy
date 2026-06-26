import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/design.dart';

/// A consistent placeholder body for a shell tab whose feature UI hasn't
/// shipped yet.
///
/// Transitional: each feature replaces its tab with real UI across M3–M6. Lives
/// in the shell feature because it exists only to give the navigation skeleton
/// something on-brand to render in the meantime.
class ComingSoon extends StatelessWidget {
  const ComingSoon({required this.title, required this.icon, super.key});

  /// The tab's display title, shown in the app bar.
  final String title;

  /// A glyph representing the feature.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Coming soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
