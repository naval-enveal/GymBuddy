import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/vitals/vitals_controller.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_gate.dart';

/// Home tab — the vitals dashboard.
///
/// Access to health data is gated by [VitalsPermissionGate]: until the user
/// connects, Home shows the graceful locked state; once granted it renders the
/// live dashboard ([_VitalsDashboard]) — a readiness ring, a StatRing + 7-day
/// sparkline per metric, per-metric empty states, and pull-to-refresh.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const SafeArea(
        child: VitalsPermissionGate(
          child: _VitalsDashboard(),
        ),
      ),
    );
  }
}

/// The granted-state dashboard. Watches [vitalsControllerProvider] and renders
/// its [AsyncValue]: a spinner while loading, a retryable error, or the loaded
/// dashboard. All data I/O lives in the controller per no-logic-in-widgets.
class _VitalsDashboard extends ConsumerWidget {
  const _VitalsDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vitalsControllerProvider);
    return async.when(
      loading: () => const Center(
        key: Key('vitals-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (_e, _) => _DashboardError(
        onRetry: () => ref.invalidate(vitalsControllerProvider),
      ),
      data: (snapshot) => _DashboardBody(
        snapshot: snapshot,
        onRefresh: () =>
            ref.read(vitalsControllerProvider.notifier).refresh(),
      ),
    );
  }
}

/// Retryable error state — the reader is contracted not to throw, so this is a
/// belt-and-braces fallback that still gives the user a way back.
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('vitals-error'),
      child: StateMessage(
        icon: Icons.error_outline,
        title: 'Couldn’t load your vitals',
        actionKey: const Key('vitals-error-retry'),
        actionLabel: 'Try again',
        actionIcon: Icons.refresh,
        onAction: onRetry,
      ),
    );
  }
}

/// The loaded dashboard: readiness hero ring + a card per metric, scrollable so
/// pull-to-refresh works even when the content fits the screen.
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.snapshot, required this.onRefresh});

  final VitalsSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final reading = snapshot.reading;
    final series = snapshot.series;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('vitals-dashboard'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ReadinessHero(readiness: snapshot.readiness),
          const SizedBox(height: AppSpacing.lg),
          _VitalCard(
            id: 'resting-hr',
            icon: Icons.favorite_outline,
            label: 'Resting HR',
            unit: 'bpm',
            value: _whole(reading.restingHeartRate),
            progress: _fraction(reading.restingHeartRate, low: 80, high: 40),
            series: series.restingHeartRate,
          ),
          const SizedBox(height: AppSpacing.sm),
          _VitalCard(
            id: 'hrv',
            icon: Icons.monitor_heart_outlined,
            label: 'HRV',
            unit: 'ms',
            value: _whole(reading.hrv),
            progress: _fraction(reading.hrv, low: 20, high: 100),
            series: series.hrv,
          ),
          const SizedBox(height: AppSpacing.sm),
          _VitalCard(
            id: 'sleep',
            icon: Icons.bedtime_outlined,
            label: 'Sleep',
            unit: 'h',
            value: _oneDecimal(reading.sleepHours),
            progress: _fraction(reading.sleepHours, low: 0, high: 8),
            series: series.sleepHours,
          ),
          const SizedBox(height: AppSpacing.sm),
          _VitalCard(
            id: 'steps',
            icon: Icons.directions_walk_outlined,
            label: 'Steps',
            unit: '',
            value: reading.steps?.toString(),
            progress: _fraction(
              reading.steps?.toDouble(),
              low: 0,
              high: 10000,
            ),
            series: series.steps,
          ),
        ],
      ),
    );
  }

  static String? _whole(double? v) => v?.round().toString();

  static String? _oneDecimal(double? v) => v?.toStringAsFixed(1);

  /// Maps a metric onto a [0, 1] ring fill between [low] (→0) and [high] (→1).
  /// [low] may exceed [high] for "lower is better" metrics. Null → 0 (empty).
  static double _fraction(double? value, {required double low, required double high}) {
    if (value == null || low == high) return 0;
    final t = (value - low) / (high - low);
    return t.clamp(0.0, 1.0).toDouble();
  }
}

/// The headline readiness ring. Shows an em dash when there's no recovery
/// signal to compute a proxy from.
class _ReadinessHero extends StatelessWidget {
  const _ReadinessHero({required this.readiness});

  final int? readiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('vitals-readiness'),
      children: [
        StatRing(
          size: 148,
          strokeWidth: 12,
          progress: (readiness ?? 0) / 100,
          value: readiness?.toString() ?? '—',
          label: 'Readiness',
          semanticLabel: readiness == null
              ? 'Readiness not available yet'
              : 'Readiness, $readiness out of 100',
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          readiness == null
              ? 'Connect recovery metrics to see your readiness'
              : 'Your recovery, at a glance',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// A single metric: a StatRing gauge, the current value (or a per-metric empty
/// state), and a 7-day sparkline when there's enough history.
class _VitalCard extends StatelessWidget {
  const _VitalCard({
    required this.id,
    required this.icon,
    required this.label,
    required this.unit,
    required this.value,
    required this.progress,
    required this.series,
  });

  final String id;
  final IconData icon;
  final String label;
  final String unit;

  /// Formatted current value, or null when the user hasn't recorded this metric.
  final String? value;
  final double progress;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = value != null;
    return Container(
      key: Key('vital-$id'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        children: [
          StatRing(
            size: 64,
            strokeWidth: 6,
            progress: hasData ? progress : 0,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(label, style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (hasData)
                  ..._loaded(theme)
                else
                  Text(
                    'No data yet',
                    key: Key('vital-empty-$id'),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _loaded(ThemeData theme) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value!, style: AppTypography.numericMedium),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xxs),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit, style: theme.textTheme.bodyMedium),
            ),
          ],
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      if (series.length >= 2)
        Sparkline(
          key: Key('vital-spark-$id'),
          values: series,
          semanticLabel: '$label, 7-day trend',
        )
      else
        Text('Not enough history yet', style: theme.textTheme.bodyMedium),
    ];
  }
}
