import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../library/providers.dart';
import '../library/source.dart';
import '../pulsar/favourites.dart';
import '../pulsar/providers.dart';
import '../widgets/common.dart';

/// The Solar Network block of the settings page: the account's favourites,
/// the run that keeps them current, and the providers whose own favourites
/// can be imported into it.
///
/// The sync is automatic — on launch, on resume and when a track ends — so the
/// button here is a catch-up, not the only way it happens. Importing is the
/// explicit half: only the user knows which of their accounts already holds
/// the hearts worth carrying over.
class SolarFavouritesSection extends ConsumerStatefulWidget {
  const SolarFavouritesSection({super.key});

  @override
  ConsumerState<SolarFavouritesSection> createState() =>
      _SolarFavouritesSectionState();
}

class _SolarFavouritesSectionState
    extends ConsumerState<SolarFavouritesSection> {
  bool _running = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    final favourites = ref.watch(pulsarFavouritesProvider);
    final count = favourites.value?.length;
    final lastRun = ref.watch(solarFavouritesStatusProvider);
    final sources = [
      for (final source in ref.watch(librarySourcesProvider))
        if (source is RatedSource) source,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('settingsSectionSolarFavourites'.tr()),
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
                      Symbols.favorite_rounded,
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
                          'settingsSolarFavourites'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !signedIn
                              ? 'settingsSolarSignedOut'.tr()
                              : count == null
                              ? 'settingsSolarFavouritesLoading'.tr()
                              : 'settingsSolarFavouritesCount'.plural(
                                  count,
                                  args: ['$count'],
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SolSpace.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: !signedIn || _running
                          ? null
                          : () => _sync(context),
                      icon: Icon(
                        _running
                            ? Symbols.sync_rounded
                            : Symbols.cloud_upload_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _running
                            ? 'settingsSolarSyncing'.tr()
                            : 'settingsSolarSyncNow'.tr(),
                      ),
                    ),
                  ),
                  if (sources.isNotEmpty) ...[
                    const SizedBox(width: SolSpace.sm),
                    MenuAnchor(
                      menuChildren: [
                        for (final source in sources)
                          MenuItemButton(
                            leadingIcon: const Icon(
                              Symbols.download_rounded,
                              size: 18,
                            ),
                            onPressed: !signedIn || _importing
                                ? null
                                : () => _import(context, source),
                            child: Text(
                              'settingsSolarImportFrom'.tr(
                                args: [source.displayName],
                              ),
                            ),
                          ),
                      ],
                      builder: (context, controller, _) => IconButton.filledTonal(
                        tooltip: 'settingsSolarImport'.tr(),
                        onPressed: !signedIn || _importing
                            ? null
                            : () => controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                        icon: Icon(
                          _importing
                              ? Symbols.sync_rounded
                              : Symbols.input_rounded,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: SolSpace.sm),
              Text(
                _status(lastRun),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: lastRun?.succeeded == false
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
              if (signedIn && favourites.hasError) ...[
                const SizedBox(height: SolSpace.sm),
                Text(
                  describeServerError(favourites.error!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// What the last run did, or the promise that one will happen on its own.
  String _status(SolarFavouriteRun? lastRun) {
    if (lastRun == null) return 'settingsSolarFavouritesAuto'.tr();
    if (!lastRun.succeeded) return 'settingsSolarFavouritesFailed'.tr();
    final minutes = DateTime.now().difference(lastRun.at).inMinutes;
    return [
      'settingsSolarLastSync'.plural(minutes < 1 ? 0 : minutes),
      if (lastRun.pushed > 0)
        'settingsSolarPushed'.plural(
          lastRun.pushed,
          args: ['${lastRun.pushed}'],
        ),
      if (lastRun.pulled > 0)
        'settingsSolarPulled'.plural(
          lastRun.pulled,
          args: ['${lastRun.pulled}'],
        ),
    ].join(' · ');
  }

  Future<void> _sync(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _running = true);
    try {
      final result = await ref
          .read(solarFavouritesStatusProvider.notifier)
          .runNow();
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            result.succeeded
                ? 'settingsSolarSyncDone'.tr(
                    args: ['${result.pushed}', '${result.pulled}'],
                  )
                : 'settingsSolarFavouritesFailed'.tr(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _import(BuildContext context, RatedSource source) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _importing = true);
    try {
      final result = await ref
          .read(solarFavouritesStatusProvider.notifier)
          .importFrom(source.id);
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            result.succeeded
                ? 'settingsSolarImportDone'.tr(
                    args: [
                      source.displayName,
                      '${result.found}',
                      '${result.pushed}',
                    ],
                  )
                : 'settingsSolarImportFailed'.tr(args: [source.displayName]),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}
