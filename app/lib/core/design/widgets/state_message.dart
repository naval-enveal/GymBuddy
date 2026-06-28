import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_spacing.dart';
import 'package:gymbuddy/core/design/widgets/primary_button.dart';

/// A centered, glanceable message for the empty and error states that recur
/// across features — an icon, a title, an optional supporting line, and an
/// optional action button (typically "Try again" or a redirect).
///
/// Presentation only: callers supply the copy and wire the action. The widget
/// is a [Column] (`mainAxisSize.min`), so place it inside a [Center] for a
/// full-screen state or drop it into a scroll view (e.g. under a
/// [RefreshIndicator]) for a pull-to-refresh empty state. Keep state-specific
/// keys on the caller's wrapper so feature tests can target each state.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionKey,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together',
       );

  /// The glyph above the title — pick one that reads at a glance (a broken
  /// cloud for a fetch error, an empty-box glyph for an empty list).
  final IconData icon;

  /// The headline. Short and plain — what happened, not why.
  final String title;

  /// Optional supporting line under the title (e.g. "Check your connection").
  final String? message;

  /// Optional action button label. If set, [onAction] must be set too.
  final String? actionLabel;

  /// Optional leading icon for the action button.
  final IconData? actionIcon;

  /// Invoked when the action button is tapped.
  final VoidCallback? onAction;

  /// Optional key for the action button (so tests can target the retry/CTA).
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: actionKey,
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
