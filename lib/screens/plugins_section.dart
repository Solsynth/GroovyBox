import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_plugin_foundation/island_plugin_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../library/plugins/plugin_host.dart';
import '../widgets/common.dart';

/// Settings → Plugins: what is installed, and the two things that change it.
///
/// A plugin is a folder with a `manifest.json` and a `main.js`, installed by
/// copying it into the app's own plugins directory. The app ships none: the
/// resolvers a user wants are theirs to install, which is why this section is
/// a folder picker rather than a catalogue.
class PluginsSection extends ConsumerStatefulWidget {
  const PluginsSection({super.key});

  @override
  ConsumerState<PluginsSection> createState() => _PluginsSectionState();
}

class _PluginsSectionState extends ConsumerState<PluginsSection> {
  /// Held while an install, reload or toggle runs: two of them at once would
  /// race over the same plugins directory.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    // A platform whose build cannot execute plugin JS says so once, instead of
    // offering an install that could never run.
    if (!pluginRuntimeSupported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel('settingsSectionPlugins'.tr()),
          IslandCard(
            margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SolSpace.lg,
              ),
              leading: const Icon(Symbols.extension_off_rounded),
              title: Text('settingsSectionPlugins'.tr()),
              subtitle: Text('settingsPluginsUnsupported'.tr()),
              isThreeLine: true,
            ),
          ),
        ],
      );
    }

    final host = PluginHost.instance;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plugins = host?.installed ?? const <PluginInstance>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('settingsSectionPlugins'.tr()),
        IslandCard(
          margin: const EdgeInsets.symmetric(horizontal: SolSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (plugins.isEmpty)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SolSpace.lg,
                  ),
                  leading: Icon(
                    Symbols.extension_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text('settingsSectionPlugins'.tr()),
                  subtitle: Text('settingsPluginsEmpty'.tr()),
                  isThreeLine: true,
                ),
              for (final plugin in plugins)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SolSpace.lg,
                  ),
                  value: plugin.state != PluginState.disabled,
                  onChanged: _busy || host == null
                      ? null
                      : (value) => _toggle(host, plugin, value),
                  secondary: const Icon(Symbols.extension_rounded),
                  title: Text(plugin.manifest.name),
                  subtitle: Text(
                    [
                      plugin.manifest.version,
                      _stateLabel(plugin),
                      if (plugin.directoryPath.isNotEmpty)
                        plugin.directoryPath,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: plugin.directoryPath.isNotEmpty,
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SolSpace.lg,
                ),
                enabled: !_busy && host != null,
                leading: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.create_new_folder_rounded),
                title: Text('settingsPluginsInstall'.tr()),
                onTap: host == null ? null : () => _install(host),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SolSpace.lg,
                ),
                enabled: !_busy && host != null,
                leading: const Icon(Symbols.refresh_rounded),
                title: Text('settingsPluginsReload'.tr()),
                onTap: host == null ? null : () => _reload(host),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The plugin's own state, in the user's language.
  String _stateLabel(PluginInstance plugin) => switch (plugin.state) {
    PluginState.active || PluginState.loaded => 'settingsPluginsStateActive'
        .tr(),
    PluginState.discovered => 'settingsPluginsStateDiscovered'.tr(),
    PluginState.disabled => 'settingsPluginsStateDisabled'.tr(),
    PluginState.error => 'settingsPluginsStateError'.tr(),
  };

  Future<void> _toggle(
    PluginHost host,
    PluginInstance plugin,
    bool enabled,
  ) async {
    setState(() => _busy = true);
    try {
      await host.setEnabled(plugin.manifest.id, enabled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install(PluginHost host) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'settingsPluginsInstall'.tr(),
    );
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    final installed = await host.installFromFolder(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!installed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settingsPluginsInstallFailed'.tr())),
      );
    }
  }

  Future<void> _reload(PluginHost host) async {
    setState(() => _busy = true);
    try {
      await host.reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
