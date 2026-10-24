import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/app.dart';
import '../core/theme.dart';
import '../server/models.dart';
import '../server/subsonic.dart';

/// First-run connection screen for a Subsonic-compatible server.
///
/// Shown instead of the shell whenever no authenticated server is stored.
/// "Test connection" and "Connect" run the same request; the test button exists
/// so the user can validate an address without committing to it.
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
  bool _busy = false;
  String? _error;
  String? _success;

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SolSpace.xxxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                    'Connect your server',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SolSpace.sm),
                  Text(
                    'GroovyBox plays from any Subsonic-compatible server: '
                    'Navidrome, Jellyfin, Gonic, Airsonic and friends.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: SolSpace.xxl),
                  TextFormField(
                    controller: _serverController,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'https://music.example.com',
                      prefixIcon: Icon(Symbols.dns_rounded),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter your server address';
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
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Enter your username' : null,
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
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'Enter your password' : null,
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
                    'Your password is never stored: only a salted token, '
                    'the way the Subsonic API expects clients to authenticate.',
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
    );
  }

  SubsonicClient? _buildClient() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final password = _passwordController.text;
    return SubsonicClient(
      ServerConfig(
        baseUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
      ).withPassword(password),
    );
  }

  Future<void> _test() async {
    final client = _buildClient();
    if (client == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await client.ping();
      if (!mounted) return;
      setState(() => _success = 'Server responded. You can connect now.');
    } on SubsonicException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final client = _buildClient();
    if (client == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await client.ping();
      await ref.read(serverConnectionProvider.notifier).save(client.config);
      TextInput.finishAutofillContext();
      // The app rebuilds onto the shell as soon as the connection lands; no
      // navigation is needed here.
    } on SubsonicException catch (error) {
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
