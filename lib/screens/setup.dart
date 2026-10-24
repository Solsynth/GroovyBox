import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Connection screen for a music library.
///
/// Shown instead of the shell whenever no library is connected, and pushed from
/// settings to add another one. "Test connection" and "Connect" run the same
/// adapter call; the test button exists so the user can validate an address
/// without committing to it.
@RoutePage()
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  LibraryKind _kind = LibraryKind.subsonic;
  bool _busy = false;
  String? _error;
  String? _success;

  /// Whether the app already had a library when this screen opened: adding a
  /// second one returns to settings, the first one just enters the app.
  late final bool _hadSources;

  @override
  void initState() {
    super.initState();
    _hadSources = ref.read(librarySourcesProvider).isNotEmpty;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SolSpace.xxxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: IslandCard(
              cornerRadius: SolRadius.xxl,
              padding: const EdgeInsets.all(SolSpace.xxl),
              emphasised: true,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Symbols.graphic_eq_rounded,
                      size: 44,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: SolSpace.lg),
                    Text(
                      'Connect a library',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SolSpace.sm),
                    Text(
                      'GroovyBox streams from your own music servers. '
                      'Nothing is copied to this device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: SolSpace.xl),
                    SegmentedButton<LibraryKind>(
                      segments: [
                        for (final kind in LibraryKind.values)
                          ButtonSegment(value: kind, label: Text(kind.label)),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (selection) => setState(() {
                        _kind = selection.first;
                        _error = null;
                        _success = null;
                      }),
                    ),
                    const SizedBox(height: SolSpace.lg),
                    TextFormField(
                      controller: _serverController,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Server address',
                        hintText: _kind.addressHint,
                        prefixIcon: const Icon(Symbols.dns_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Enter your server address';
                        }
                        final uri = Uri.tryParse(
                          text.contains('://') ? text : 'https://$text',
                        );
                        if (uri == null || uri.host.isEmpty) {
                          return 'That does not look like a server address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: SolSpace.md),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Symbols.person_rounded),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter your username'
                          : null,
                    ),
                    const SizedBox(height: SolSpace.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      onFieldSubmitted: (_) => _connect(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Symbols.lock_rounded),
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? 'Enter your password'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: SolSpace.lg),
                      _Banner(
                        icon: Symbols.error_rounded,
                        message: _error!,
                        color: colorScheme.error,
                      ),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: SolSpace.lg),
                      _Banner(
                        icon: Symbols.check_circle_rounded,
                        message: _success!,
                        color: colorScheme.primary,
                      ),
                    ],
                    const SizedBox(height: SolSpace.xl),
                    FilledButton(
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                    const SizedBox(height: SolSpace.sm),
                    TextButton(
                      onPressed: _busy ? null : _test,
                      child: const Text('Test connection'),
                    ),
                    const SizedBox(height: SolSpace.lg),
                    Text(
                      'Your password is never stored: only a token, the way each '
                      'API expects clients to authenticate.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Runs the adapter's connect flow, or returns null when the form is
  /// invalid or the server rejected the credentials (in which case the error
  /// banner is already set).
  Future<SourceConfig?> _connectConfig() async {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final adapter = libraryAdapters[_kind]!;
    return adapter.connect(
      baseUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final config = await _connectConfig();
      if (config == null || !mounted) return;
      setState(() => _success = 'Server responded. You can connect now.');
    } on LibraryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final config = await _connectConfig();
      if (config == null) return;
      await ref.read(sourceStoreProvider.notifier).add(config);
      TextInput.finishAutofillContext();
      // With a library already connected this was pushed from settings, so
      // the user needs to go back; on first run the app swaps the shell in
      // underneath and popping would leave nothing.
      if (mounted && _hadSources) context.router.maybePop();
    } on LibraryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _Banner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SolSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: SolRadius.controlRadius,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: SolSpace.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
