import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../library_sync/providers.dart';
import '../library_sync/store.dart';
import '../solarpass/providers.dart';
import '../widgets/common.dart';

/// The Library Sync block of the settings page: a signed-in gate, the switch,
/// a manual run, and what the last run and the account's mirror say.
class LibrarySyncSection extends ConsumerWidget {
  const LibrarySyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(solarpassSessionProvider).value;
    final syncState = ref.watch(librarySyncStateProvider);
    final view = ref.watch(librarySyncStatusViewProvider);
    final isSignedIn = session != null;
    final running = view.running;
    final subtitle = _subtitle(syncState, view);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('settingsSectionLibrarySync'.tr()),
        IslandCard(
          margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
          padding: const EdgeInsets.all(SolSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Symbols.sync_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: SolSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'settingsLibrarySync'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SolSpace.xs),
                        Text(
                          'settingsLibrarySyncSubtitle'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SolSpace.lg),
              if (!isSignedIn)
                Text(
                  'settingsLibrarySyncNeedsSignIn'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: syncState.enabled,
                  onChanged: (value) => ref
                      .read(librarySyncStateProvider.notifier)
                      .setEnabled(value),
                  title: Text(
                    'settingsLibrarySync'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: subtitle == null
                      ? null
                      : Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: !syncState.enabled
                        ? null
                        : () => ref
                              .read(librarySyncStatusViewProvider.notifier)
                              .run(),
                    icon: const Icon(Symbols.sync_rounded, size: 16),
                    label: Text(
                      running
                          ? 'settingsLibrarySyncProgress'.tr()
                          : 'settingsLibrarySyncNow'.tr(),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Synced 3 minutes ago · 2 devices", or why there is nothing to report.
  ///
  /// Null before the first run: there is nothing true to say yet, and an empty
  /// line is better than a wrong one.
  String? _subtitle(
    LibrarySyncState syncState,
    LibrarySyncStatusViewState view,
  ) {
    if (!syncState.enabled) return 'settingsLibrarySyncDisabled'.tr();
    final lastRun = view.lastRun;
    if (lastRun == null) return null;
    if (!lastRun.succeeded) return 'settingsLibrarySyncFailed'.tr();

    final minutes = DateTime.now().difference(lastRun.at).inMinutes;
    final parts = <String>[
      'settingsLibrarySyncLastSync'.plural(minutes < 1 ? 0 : minutes),
    ];
    final devices = view.status?.deviceCount;
    if (devices != null && devices > 0) {
      parts.add('settingsLibrarySyncDevices'.plural(devices));
    }
    return parts.join(' · ');
  }
}
