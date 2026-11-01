import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Settings: theme, glass, connected libraries, and the only way to
/// disconnect one.
///
/// Groups are tonal cards separated by space. Dividers are deliberately not
/// used: a card already says "these rows belong together", and a hairline
/// between two of them would just be a third edge.
@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final glass = ref.watch(glassEffectsEnabledProvider);
    final infinitePlayback = ref.watch(infinitePlaybackEnabledProvider);
    final sources = ref.watch(librarySourcesProvider);
    final failures = ref.watch(sourceFailuresProvider);
    final theme = Theme.of(context);
    // Select the identity, not the state: watching the whole transport would
    // rebuild this page on every position tick, once a second.
    final hasSong = ref.watch(
      playbackProvider.select((state) => state.current != null),
    );
    // Read once, live: the slider must reflect a nudge from the player's
    // arrow keys, and the player page no longer shows a level of its own.
    final volume = ref.watch(playbackProvider.select((state) => state.volume));
    final bottomInset = solBottomChromeInset(context, dockVisible: hasSong);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentFrame(
        maxWidth: kReadingMaxWidth,
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomInset),
          children: [
            PageHeader(
              title: 'tabSettings'.tr(),
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
            ),
            SectionLabel('settingsSectionAppearance'.tr()),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              padding: const EdgeInsets.all(SolSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'settingsThemeLabel'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SolSpace.md),
                  SegmentedButton<AppThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        icon: const Icon(Symbols.brightness_auto_rounded),
                        label: Text('settingsThemeSystem'.tr()),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: const Icon(Symbols.light_mode_rounded),
                        label: Text('settingsThemeLight'.tr()),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: const Icon(Symbols.dark_mode_rounded),
                        label: Text('settingsThemeDark'.tr()),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .set(selection.first),
                  ),
                  const SizedBox(height: SolSpace.lg),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: glass,
                    onChanged: (value) => ref
                        .read(glassEffectsEnabledProvider.notifier)
                        .set(value),
                    secondary: const Icon(Symbols.blur_on_rounded),
                    title: Text('settingsLiquidGlass'.tr()),
                    subtitle: Text('settingsLiquidGlassSubtitle'.tr()),
                  ),
                ],
              ),
            ),
            SectionLabel('settingsSectionPlayback'.tr()),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              padding: const EdgeInsets.all(SolSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'settingsVolumeLabel'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SolSpace.md),
                  Row(
                    children: [
                      Icon(
                        volume <= 0
                            ? Symbols.volume_off_rounded
                            : Symbols.volume_up_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Slider(
                          value: volume.clamp(0, 100),
                          max: 100,
                          onChanged: (value) => ref
                              .read(playbackProvider.notifier)
                              .setVolume(value),
                          onChangeEnd: (value) => saveVolume(ref, value),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'settingsVolumeHint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: SolSpace.lg),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: infinitePlayback,
                    onChanged: (value) => ref
                        .read(infinitePlaybackEnabledProvider.notifier)
                        .set(value),
                    secondary: const Icon(Symbols.all_inclusive_rounded),
                    title: Text('settingsInfinitePlayback'.tr()),
                    subtitle: Text(
                      'settingsInfinitePlaybackSubtitle'.tr(),
                    ),
                  ),
                ],
              ),
            ),
            SectionLabel('settingsSectionLibraries'.tr()),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              child: Column(
                children: [
                  for (final source in sources)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: SolSpace.lg,
                      ),
                      leading: const Icon(Symbols.cloud_rounded),
                      title: Text(source.displayName),
                      subtitle: Text(
                        '${source.kind.label} · ${source.config.baseUrl}'
                        '${failures[source.id] == null ? '' : '\n${failures[source.id]}'}',
                      ),
                      isThreeLine: failures[source.id] != null,
                      trailing: IconButton(
                        tooltip: 'settingsRemoveLibrary'.tr(),
                        onPressed: () =>
                            _confirmRemove(context, ref, source.id),
                        icon: const Icon(Symbols.delete_outline_rounded),
                      ),
                    ),
                  if (sources.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SolSpace.lg,
                        vertical: SolSpace.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('settingsNoLibraries'.tr()),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SolSpace.md,
                      0,
                      SolSpace.md,
                      SolSpace.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.router.push(const SetupRoute()),
                        icon: const Icon(Symbols.add_rounded),
                        label: Text('settingsAddLibrary'.tr()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SectionLabel('settingsSectionLibrary'.tr()),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.lg,
                    ),
                    leading: const Icon(Symbols.storage_rounded),
                    title: Text('settingsOnThisDevice'.tr()),
                    subtitle: Text(
                      switch (ref.watch(libraryStatsProvider).value) {
                        final stats? => _describeLibrary(stats),
                        null => 'settingsOnThisDeviceSubtitleEmpty'.tr(),
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.lg,
                    ),
                    leading: const Icon(Symbols.refresh_rounded),
                    title: Text('settingsRefreshEverything'.tr()),
                    subtitle: Text(
                      'settingsRefreshEverythingSubtitle'.tr(),
                    ),
                    onTap: () {
                      ref.invalidate(recentAlbumsProvider);
                      ref.invalidate(randomSongsProvider);
                      ref.invalidate(playlistsProvider);
                    },
                  ),
                ],
              ),
            ),
            SectionLabel('settingsSectionLyrics'.tr()),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.lg,
                    ),
                    value: ref.watch(lyricsPronunciationEnabledProvider),
                    onChanged: (value) => ref
                        .read(lyricsPronunciationEnabledProvider.notifier)
                        .set(value),
                    secondary: const Icon(Symbols.subtitles_rounded),
                    title: Text('settingsPronunciation'.tr()),
                    subtitle: Text(
                      'settingsPronunciationSubtitle'.tr(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.lg,
                    ),
                    value: ref.watch(lyricsTranslationEnabledProvider),
                    onChanged: (value) => ref
                        .read(lyricsTranslationEnabledProvider.notifier)
                        .set(value),
                    secondary: const Icon(Symbols.translate_rounded),
                    title: Text('settingsTranslation'.tr()),
                    subtitle: Text(
                      'settingsTranslationSubtitle'.tr(),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.lg,
                    ),
                    leading: const Icon(Symbols.lyrics_rounded),
                    title: Text('settingsStoredLyrics'.tr()),
                    subtitle: Text(
                      switch (ref.watch(storedLyricsProvider).value) {
                        final count? => 'settingsStoredLyricsCached'.plural(
                          count,
                        ),
                        null => 'settingsStoredLyricsNone'.tr(),
                      },
                    ),
                    trailing: TextButton(
                      onPressed: () => _confirmClearLyrics(context, ref),
                      child: Text('commonClear'.tr()),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.xxl,
                SolSpace.xl,
                SolSpace.xxl,
                SolSpace.xl,
              ),
              child: Text(
                'settingsStreamsFooter'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String sourceId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settingsRemoveLibraryTitle'.tr()),
        content: Text('settingsRemoveLibraryMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('commonCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('commonRemove'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(sourceStoreProvider.notifier).remove(sourceId);
    // its links go; its songs, lyrics and plays stay, so re-adding the server
    // or adding another with the same tracks finds them again
    await ref.read(lyricsMaintenanceProvider.notifier).forgetSource(sourceId);
  }

  Future<void> _confirmClearLyrics(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settingsClearLyricsTitle'.tr()),
        content: Text('settingsClearLyricsMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('commonCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('commonClear'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(lyricsMaintenanceProvider.notifier).clear();
  }
}

/// One sentence about the local library: how many songs it knows, and how many
/// of them only a removed server could play.
String _describeLibrary(({int tracks, int orphaned}) stats) {
  if (stats.tracks == 0) {
    return 'settingsLibraryEmpty'.tr();
  }
  if (stats.orphaned == 0) {
    return 'settingsLibraryKnown'.plural(stats.tracks);
  }
  return 'settingsLibraryOrphaned'.plural(
    stats.tracks,
    args: ['${stats.tracks}', '${stats.orphaned}'],
  );
}
