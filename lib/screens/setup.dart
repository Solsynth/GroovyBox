import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Adding a library.
///
/// Pushed from settings and from the browse page's nudge; it is never the app's
/// root any more, so it always has somewhere to go back to. "Test connection"
/// and "Connect" run the same adapter call; the test button exists so the user
/// can validate an address without committing to it.
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

  /// The adapter of the kind currently picked in the picker.
  LibraryAdapter get adapter => libraryAdapters[_kind]!;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _leave() {
    final router = StackRouterScope.of(context)?.controller;
    if (router != null && router.canPop()) {
      router.maybePop();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canLeave =
        (StackRouterScope.of(context)?.controller.canPop() ?? false) ||
        (Navigator.maybeOf(context)?.canPop() ?? false);

    return PopScope(
      canPop: canLeave && !_busy,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (canLeave && !_busy) _leave();
          },
        },
        child: FocusScope(
          child: Scaffold(
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
                          if (canLeave) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: const Icon(Symbols.arrow_back_rounded),
                                tooltip: 'commonBack'.tr(),
                                onPressed: _busy ? null : _leave,
                              ),
                            ),
                            const SizedBox(height: SolSpace.xs),
                          ],
                          Icon(
                            Symbols.graphic_eq_rounded,
                            size: 44,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: SolSpace.lg),
                          Text(
                            'setupTitle'.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: SolSpace.sm),
                          Text(
                            'setupSubtitle'.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: SolSpace.xl),
                          SegmentedButton<LibraryKind>(
                            segments: [
                              // Only kinds this platform can run: the local
                              // library is not a connection and has nothing to
                              // set up, and Apple Music needs iOS or macOS 14.
                              for (final entry in libraryAdapters.entries)
                                if (entry.value.isAvailable)
                                  ButtonSegment(
                                    value: entry.key,
                                    label: Text(entry.key.label),
                                  ),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (selection) => setState(() {
                              _kind = selection.first;
                              _error = null;
                              _success = null;
                            }),
                          ),
                          const SizedBox(height: SolSpace.lg),
                          if (!adapter.needsCredentials) ...[
                            Text(
                              'setupAppleMusicNote'.tr(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: SolSpace.lg),
                          ],
                          if (adapter.needsCredentials) ...[
                            TextFormField(
                              controller: _serverController,
                              autofocus: true,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'setupServerAddress'.tr(),
                                hintText: _kind.addressHint,
                                prefixIcon: const Icon(Symbols.dns_rounded),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'setupServerAddressError'.tr();
                                }
                                final uri = Uri.tryParse(
                                  text.contains('://') ? text : 'https://$text',
                                );
                                if (uri == null || uri.host.isEmpty) {
                                  return 'setupServerAddressInvalid'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: SolSpace.md),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'setupUsername'.tr(),
                                prefixIcon: const Icon(Symbols.person_rounded),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'setupUsernameError'.tr()
                                  : null,
                            ),
                            const SizedBox(height: SolSpace.md),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              onFieldSubmitted: (_) => _connect(),
                              decoration: InputDecoration(
                                labelText: 'setupPassword'.tr(),
                                prefixIcon: const Icon(Symbols.lock_rounded),
                              ),
                              validator: (value) => (value?.isEmpty ?? true)
                                  ? 'setupPasswordError'.tr()
                                  : null,
                            ),
                          ],
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('setupConnect'.tr()),
                          ),
                          if (adapter.needsCredentials) ...[
                            const SizedBox(height: SolSpace.sm),
                            TextButton(
                              onPressed: _busy ? null : _test,
                              child: Text('setupTestConnection'.tr()),
                            ),
                          ],
                          if (canLeave) ...[
                            const SizedBox(height: SolSpace.xs),
                            TextButton(
                              onPressed: _busy ? null : _leave,
                              child: Text('commonCancel'.tr()),
                            ),
                          ],
                          const SizedBox(height: SolSpace.lg),
                          if (adapter.needsCredentials)
                            Text(
                              'setupSecurityNote'.tr(),
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
          ),
        ),
      ),
    );
  }

  /// Runs the adapter's connect flow, or returns null when the form is
  /// invalid or the server rejected the credentials (in which case the error
  /// banner is already set).
  Future<SourceConfig?> _connectConfig() async {
    // A kind that signs in through the system has no fields to validate:
    // validating them would fail on the empty address the form never asked for.
    if (adapter.needsCredentials &&
        !(_formKey.currentState?.validate() ?? false)) {
      return null;
    }
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
      setState(() => _success = 'setupTestSuccess'.tr());
    } catch (error) {
      // Not only [LibraryException]: a timeout, a socket error or a bad
      // response would otherwise end the test with the spinner stopping and
      // nothing said, which reads as a button that does not work.
      if (!mounted) return;
      setState(() => _error = describeServerError(error));
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
      // The screen was pushed over the shell, so the shell is always there to
      // return to; a first connection is no different from a fifth.
      if (mounted) _leave();
    } catch (error) {
      // Same reason as [_test]: an unlisted failure must say something
      // rather than leave the form looking idle after a tap.
      if (!mounted) return;
      setState(() => _error = describeServerError(error));
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
