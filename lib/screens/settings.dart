import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Settings: theme, connected libraries, and the only way to disconnect one.
@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final sources = ref.watch(librarySourcesProvider);
    final failures = ref.watch(sourceFailuresProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          PageHeader(
            title: 'Settings',
            actions: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.router.maybePop(),
                icon: const Icon(Symbols.arrow_back_rounded),
              ),
              const SizedBox(width: SolSpace.sm),
            ],
          ),
          const SectionLabel('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SolSpace.xxl),
            child: SegmentedButton<AppThemeMode>(
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
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).set(selection.first),
            ),
          ),
          const GroupDivider(),
          const SectionLabel('Libraries'),
          for (final source in sources)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SolSpace.xxl,
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
                onPressed: () => _confirmRemove(context, ref, source.id),
                icon: const Icon(Symbols.delete_outline_rounded),
              ),
            ),
          if (sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: SolSpace.xxl),
              child: Text('Not connected to a library.'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.xxl,
              SolSpace.md,
              SolSpace.xxl,
              SolSpace.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.router.push(const SetupRoute()),
                icon: const Icon(Symbols.add_rounded),
                label: const Text('Add library'),
              ),
            ),
          ),
          const GroupDivider(),
          const SectionLabel('Library'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SolSpace.xxl,
            ),
            leading: const Icon(Symbols.refresh_rounded),
            title: const Text('Refresh everything'),
            subtitle: const Text(
              'Reload albums, playlists and the random shelf from every library.',
            ),
            onTap: () {
              ref.invalidate(recentAlbumsProvider);
              ref.invalidate(randomSongsProvider);
              ref.invalidate(playlistsProvider);
            },
          ),
          const GroupDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SolSpace.xxl),
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
  }
}
