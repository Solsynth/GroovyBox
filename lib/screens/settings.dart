import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/app.dart';
import '../core/server_data.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Settings: theme, connection details, and the only way to disconnect.
@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final server = ref.watch(serverConnectionProvider);
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
          const SectionLabel('Server'),
          if (server != null) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SolSpace.xxl,
              ),
              leading: const Icon(Symbols.dns_rounded),
              title: const Text('Address'),
              subtitle: Text(server.baseUrl),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SolSpace.xxl,
              ),
              leading: const Icon(Symbols.person_rounded),
              title: const Text('Signed in as'),
              subtitle: Text(server.username),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.xxl,
                SolSpace.md,
                SolSpace.xxl,
                SolSpace.md,
              ),
              child: OutlinedButton.icon(
                onPressed: () => _confirmDisconnect(context, ref),
                icon: const Icon(Symbols.logout_rounded),
                label: const Text('Disconnect'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: SolSpace.xxl),
              child: Text('Not connected.'),
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
              'Reload albums, playlists and the random shelf from the server.',
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
              'GroovyBox streams from any OpenSubsonic-compatible server. '
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

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect?'),
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
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(serverConnectionProvider.notifier).clear();
  }
}
