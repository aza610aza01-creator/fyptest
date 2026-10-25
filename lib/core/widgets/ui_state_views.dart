import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/theme/design_tokens.dart';

/// Complete production UI State components (`@ui-states` & `@design-ux`):
/// 1. First-Use State (`FirstUseStateCard`)
/// 2. Filtered-to-Nothing State (`NoResultsStateCard`)
/// 3. Steady Layout Skeleton Placeholder (`SkeletonShimmerCard`)
/// 4. Non-Blocking Offline / Partial-Data Banner (`OfflineSyncStatusBanner`)
/// 5. Permission / Plan Missing State (`PermissionStateCard`)
/// 6. Idempotent Busy Action Button (`BusyActionButton`)

class FirstUseStateCard extends StatelessWidget {
  const FirstUseStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
              ),
              child: Icon(icon, size: 28, color: scheme.primary),
            ),
            const SizedBox(height: AppDesignTokens.space3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppDesignTokens.space2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDesignTokens.space4),
            Wrap(
              spacing: AppDesignTokens.space2,
              runSpacing: AppDesignTokens.space2,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onPrimaryAction,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(primaryActionLabel),
                ),
                if (secondaryActionLabel != null && onSecondaryAction != null)
                  OutlinedButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Displayed when a search query or muscle/equipment filter returns zero items.
/// Distinct from FirstUseStateCard: explains which filter matched nothing and
/// provides a 1-tap "Clear Filters" button.
class NoResultsStateCard extends StatelessWidget {
  const NoResultsStateCard({
    super.key,
    required this.queryOrFilterSummary,
    required this.onClearFilters,
    required this.isZh,
  });

  final String queryOrFilterSummary;
  final VoidCallback onClearFilters;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppDesignTokens.space5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 38, color: scheme.primary),
          const SizedBox(height: AppDesignTokens.space2),
          Text(
            isZh ? '找不到符合篩選條件的結果' : 'No Matching Results',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            isZh
                ? '目前篩選條件「$queryOrFilterSummary」沒有對應項目。'
                : 'No items matched "$queryOrFilterSummary".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDesignTokens.space3),
          OutlinedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
            label: Text(isZh ? '清除篩選條件' : 'Clear Filters'),
          ),
        ],
      ),
    );
  }
}

/// Steady-geometry skeleton placeholder card preventing layout shift (CLS) while
/// async data loads.
class SkeletonShimmerCard extends StatelessWidget {
  const SkeletonShimmerCard({
    super.key,
    this.lines = 3,
    this.height = 108,
  });

  final int lines;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return Semantics(
      label: 'Loading content placeholder',
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(AppDesignTokens.space4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List<Widget>.generate(lines, (idx) {
            final widthFactor = idx == 0 ? 0.55 : (idx == lines - 1 ? 0.75 : 0.92);
            return FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Non-blocking banner for Offline Mode or Partial Data fallback so already
/// loaded workout/health records remain 100% usable.
class OfflineSyncStatusBanner extends StatelessWidget {
  const OfflineSyncStatusBanner({
    super.key,
    required this.isOnline,
    required this.pendingCount,
    required this.isSyncing,
    required this.lastSyncText,
    required this.onRetrySync,
    required this.isZh,
  });

  final bool isOnline;
  final int pendingCount;
  final bool isSyncing;
  final String lastSyncText;
  final VoidCallback onRetrySync;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isOnline
        ? (isDark ? AppDesignTokens.postureCorrectDark : AppDesignTokens.postureCorrectLight)
        : (isDark ? AppDesignTokens.postureAdjustDark : AppDesignTokens.postureAdjustLight);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.space3,
          vertical: AppDesignTokens.space2,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSyncing
                      ? Icons.sync_rounded
                      : (isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isOnline
                        ? (isZh
                            ? '雲端連線正常 • 待同步: $pendingCount 筆'
                            : 'Cloud Connected • Pending queue: $pendingCount')
                        : (isZh
                            ? '離線優先模式 — 訓練紀錄已安全保存於本機 (待同步: $pendingCount)'
                            : 'Offline-First Mode — Local workouts saved safely ($pendingCount pending)'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (pendingCount > 0 || !isOnline)
              TextButton.icon(
                onPressed: isSyncing ? null : onRetrySync,
                icon: const Icon(Icons.refresh, size: 15),
                label: Text(isZh ? '立即同步' : 'Retry Sync'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Idempotent button wrapper that disables itself and displays a compact spinner
/// while an async mutation is in flight (`@design-ux` idempotency on submit).
class BusyActionButton extends StatelessWidget {
  const BusyActionButton({
    super.key,
    required this.isBusy,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final bool isBusy;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isBusy ? null : onPressed,
      icon: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
