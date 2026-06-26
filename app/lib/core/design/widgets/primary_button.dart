import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';
import 'package:gymbuddy/core/design/tokens/app_spacing.dart';

/// The app's canonical call-to-action.
///
/// A full-width, pill-shaped accent button sized to the ≥48dp touch target.
/// Purely presentational: it renders [label] and reports taps via [onPressed].
/// Passing `null` for [onPressed] disables it; setting [isLoading] shows a
/// spinner and also blocks taps (so callers can't double-submit while a request
/// is in flight) without having to also null out the callback.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    super.key,
  });

  /// Button text.
  final String label;

  /// Tap handler. `null` renders the disabled state.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// When true, shows a spinner and ignores taps.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              // While loading the button is disabled, so its background is the
              // muted surface; an accent spinner stays visible against it where
              // an onAccent (near-black) one would vanish.
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(label, style: theme.textTheme.labelLarge),
              ],
            ),
    );
  }
}
