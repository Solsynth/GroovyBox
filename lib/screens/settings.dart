import 'package:auto_route/auto_route.dart';
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
              title: 'Settings',
              leading: HeaderBackButton(
                onPressed: () => context.router.maybePop(),
              ),
            ),
            const SectionLabel('Appearance'),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              padding: const EdgeInsets.all(SolSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Theme',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SolSpace.md),
                  SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        icon: Icon(Symbols.brightness_auto_rounded),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Symbols.light_mode_rounded),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: Icon(Symbols.dark_mode_rounded),
                        label: Text('Dark'),
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
                    title: const Text('Liquid glass'),
                    subtitle: const Text(
                      'Floating chrome refracts the page behind it. Turn off '
                      'to paint the same bars as flat surfaces, which costs '
                      'less on every scroll frame.',
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('Playback'),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              padding: const EdgeInsets.all(SolSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Volume',
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
                    'The player page does not show this: level is set once and '
                    'rarely touched. Arrow keys still change it while the '
                    'player has focus.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('Libraries'),
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
                        tooltip: 'Remove',
                        onPressed: () =>
                            _confirmRemove(context, ref, source.id),
                        icon: const Icon(Symbols.delete_outline_rounded),
                      ),
                    ),
                  if (sources.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: SolSpace.lg,
                        vertical: SolSpace.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Not connected to a library.'),
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
                        label: const Text('Add library'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SectionLabel('Library'),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SolSpace.lg,
                ),
                leading: const Icon(Symbols.refresh_rounded),
                title: const Text('Refresh everything'),
                subtitle: const Text(
                  'Reload albums, playlists and the random shelf from every '
                  'library.',
                ),
                onTap: () {
                  ref.invalidate(recentAlbumsProvider);
                  ref.invalidate(randomSongsProvider);
                  ref.invalidate(playlistsProvider);
                },
              ),
            ),
            const SectionLabel('Lyrics'),
            IslandCard(
              margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SolSpace.lg,
                ),
                leading: const Icon(Symbols.lyrics_rounded),
                title: const Text('Stored lyrics'),
                subtitle: Text(switch (ref.watch(storedLyricsProvider).value) {
                  final count? =>
                    '$count song${count == 1 ? '' : 's'} cached on this '
                        'device. They show without asking the server again, '
                        'and stay available offline.',
                  null =>
                    'Lyrics downloaded from the library and LRCLIB '
                        'stay available offline.',
                }),
                trailing: TextButton(
                  onPressed: () => _confirmClearLyrics(context, ref),
                  child: const Text('Clear'),
                ),
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
                'GroovyBox streams from your own music servers. '
                'Nothing is copied to this device.',
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
        title: const Text('Remove this library?'),
        content: const Text(
          'The server address and signed-in account are removed from this '
          'device. Your music is untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(sourceStoreProvider.notifier).remove(sourceId);
    // Its downloaded lyrics point at a library that is gone; nothing will
    // ever ask for them again.
    await ref.read(lyricsMaintenanceProvider.notifier).forgetSource(sourceId);
  }

  Future<void> _confirmClearLyrics(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear stored lyrics?'),
        content: const Text(
          'Every downloaded lyric is removed from this device. They are '
          'fetched again the next time each song plays, so nothing is lost — '
          'only the offline copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(lyricsMaintenanceProvider.notifier).clear();
  }
}
