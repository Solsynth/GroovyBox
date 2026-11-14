import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../pulsar/providers.dart';
import '../widgets/common.dart';
import '../widgets/pulsar_upload.dart';

/// The Pulsar block of the settings page: what the account keeps in the
/// cloud, and the one write that keeps it current.
///
/// Favourites are the interesting half. The device's heart is the record; the
/// fleet's copy is what a second device reads. This section is where a user
/// pushes every decision the fleet is missing, and where the count of what the
/// account has is visible at all.
class PulsarCloudSection extends ConsumerWidget {
  const PulsarCloudSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    final favourites = ref.watch(pulsarFavouritesProvider);
    final count = favourites.value?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('settingsSectionPulsar'.tr()),
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
                          'settingsPulsarFavourites'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !signedIn
                              ? 'settingsPulsarSignedOut'.tr()
                              : count == null
                              ? 'settingsPulsarFavouritesLoading'.tr()
                              : 'settingsPulsarFavouritesCount'.plural(
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
              FilledButton.tonalIcon(
                onPressed: !signedIn
                    ? null
                    : () => PulsarUpload.syncFavourites(context, ref),
                icon: const Icon(Symbols.cloud_upload_rounded, size: 18),
                label: Text('settingsPulsarSyncFavourites'.tr()),
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
}
