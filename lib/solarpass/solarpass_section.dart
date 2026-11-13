import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'login_dialog.dart';
import 'models.dart';
import 'providers.dart';

class SolarpassSettingsSection extends ConsumerWidget {
  const SolarpassSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sessionAsync = ref.watch(solarpassSessionProvider);
    final accountAsync = ref.watch(solarpassAccountProvider);
    final config = ref.watch(solarpassConfigProvider);
    final scrobbleStatus = ref.watch(solarpassScrobbleStatusProvider);

    final session = sessionAsync.value;
    final account = accountAsync.value;
    final isSignedIn = session != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('settingsSectionSolarNetwork'.tr()),
        IslandCard(
          margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
          padding: const EdgeInsets.all(SolSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isSignedIn) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Symbols.wb_sunny_rounded,
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
                            'solarpassCardTitle'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: SolSpace.xs),
                          Text(
                            'solarpassCardSubtitle'.tr(),
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
                FilledButton.icon(
                  onPressed: () => SolarpassLoginDialog.show(context),
                  icon: const Icon(Symbols.login_rounded),
                  label: Text('solarpassConnectButton'.tr()),
                ),
              ] else ...[
                Row(
                  children: [
                    _UserAvatar(
                      avatarUrl: account?.avatarUrl,
                      name: account?.displayName ?? 'User',
                    ),
                    const SizedBox(width: SolSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account?.displayName ?? 'Solarpass Account',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: SolSpace.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'solarpassStatusConnected'.tr(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (account?.name.isNotEmpty == true)
                            Text(
                              '@${account!.name}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'solarpassDisconnectButton'.tr(),
                      icon: const Icon(Symbols.logout_rounded),
                      onPressed: () => _confirmSignOut(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: SolSpace.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.scrobbleEnabled,
                  onChanged: (val) => ref
                      .read(solarpassConfigProvider.notifier)
                      .setScrobbleEnabled(val),
                  title: Text(
                    'solarpassScrobbleToggleTitle'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'solarpassScrobbleToggleSubtitle'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (config.scrobbleEnabled && scrobbleStatus.isScrobbling) ...[
                  const SizedBox(height: SolSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.md,
                      vertical: SolSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: SolSpace.sm),
                        Expanded(
                          child: Text(
                            'solarpassNowScrobbling'.tr(
                              args: [scrobbleStatus.currentTrack ?? ''],
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: SolSpace.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showConfigSheet(context, ref),
                  icon: const Icon(Symbols.tune_rounded, size: 16),
                  label: Text(
                    'solarpassConfigureServer'.tr(),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('solarpassDisconnectDialogTitle'.tr()),
        content: Text('solarpassDisconnectDialogBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('commonCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('solarpassDisconnectButton'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(solarpassSessionProvider.notifier).signOut();
    }
  }

  void _showConfigSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SolarpassConfigSheet(),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return ClipOval(
      child: Container(
        width: 44,
        height: 44,
        color: scheme.primaryContainer,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SolarpassConfigSheet extends ConsumerStatefulWidget {
  const _SolarpassConfigSheet();

  @override
  ConsumerState<_SolarpassConfigSheet> createState() =>
      _SolarpassConfigSheetState();
}

class _SolarpassConfigSheetState extends ConsumerState<_SolarpassConfigSheet> {
  late final TextEditingController _serverUrlController;
  late final TextEditingController _clientIdController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(solarpassConfigProvider);
    _serverUrlController = TextEditingController(text: config.serverUrl);
    _clientIdController = TextEditingController(text: config.clientId);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  void _save() {
    final current = ref.read(solarpassConfigProvider);
    final updated = current.copyWith(
      serverUrl: _serverUrlController.text.trim().isNotEmpty
          ? _serverUrlController.text.trim()
          : SolarpassConfig.defaultServerUrl,
      clientId: _clientIdController.text.trim().isNotEmpty
          ? _clientIdController.text.trim()
          : SolarpassConfig.defaultClientId,
    );
    ref.read(solarpassConfigProvider.notifier).update(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SolSpace.xl,
        SolSpace.xl,
        SolSpace.xl,
        SolSpace.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'solarpassConfigSheetTitle'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: SolSpace.md),
          TextField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: 'solarpassConfigServerUrl'.tr(),
              hintText: SolarpassConfig.defaultServerUrl,
              prefixIcon: const Icon(Symbols.dns_rounded),
            ),
          ),
          const SizedBox(height: SolSpace.md),
          TextField(
            controller: _clientIdController,
            decoration: InputDecoration(
              labelText: 'solarpassConfigClientId'.tr(),
              hintText: SolarpassConfig.defaultClientId,
              prefixIcon: const Icon(Symbols.badge_rounded),
            ),
          ),
          const SizedBox(height: SolSpace.lg),
          FilledButton(onPressed: _save, child: Text('commonSave'.tr())),
        ],
      ),
    );
  }
}
