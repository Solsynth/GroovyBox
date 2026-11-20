import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/plugins/plugin_adapter.dart';
import 'package:groovy_box/library/plugins/plugin_host.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Adding a library.
///
/// Pushed from settings and from the explore page's nudge; it is never the
/// app's root any more, so it always has somewhere to go back to.
///
/// One provider is chosen from a dropdown rather than a row of segments: the
/// set of kinds grows (and shrinks per platform), and a menu holds six names
/// where segments hold three. "Test connection" and "Connect" run the same
/// adapter call; the test exists so an address can be checked without
/// committing to it.
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
  SetupOption _option = const BuiltInOption(LibraryKind.subsonic);
  bool _busy = false;
  String? _error;
  String? _success;

  /// The interactive login in progress, when the adapter has one: the steps
  /// to draw and the stream of the QR step's scan state.
  List<LoginStep>? _loginSteps;
  StreamSubscription<int>? _qrPoll;
  int? _qrState; // 801 waiting, 802 scanned, 803 authorized.

  /// The code the current QR step was minted against: a `data:` URL or an
  /// image URL. Null while it is still being prepared.
  String? _qrCode;

  /// Whether the current adapter signs in through an interactive flow
  /// instead of the three-field form.
  bool get _isInteractive => adapter is InteractiveLoginAdapter;

  /// The adapter of the option currently picked in the picker.
  ///
  /// A built-in kind is looked up in the adapter map; a plugin provider is
  /// wrapped against the live host, because a plugin can be installed while
  /// this screen is open.
  LibraryAdapter get adapter => switch (_option) {
    BuiltInOption(:final kind) => libraryAdapters[kind]!,
    PluginOption(:final provider) => PluginAdapter(
      provider,
      host: PluginHost.instance!,
    ),
  };

  /// The options this platform can actually run, in display order. The local
  /// library is not a connection and never appears; a plugin contributes one
  /// row per provider it declares.
  List<SetupOption> get _options =>
      setupOptions(ref.watch(pluginProvidersProvider));

  @override
  void initState() {
    super.initState();
    // A verdict belongs to the address it was about; editing the address
    // retires it instead of leaving a stale banner under a new host.
    _serverController.addListener(_clearOutcome);
  }

  @override
  void dispose() {
    _serverController.removeListener(_clearOutcome);
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _qrPoll?.cancel();
    super.dispose();
  }

  void _clearOutcome() {
    if (_error == null && _success == null) return;
    setState(() {
      _error = null;
      _success = null;
    });
  }

  void _leave() {
    final router = StackRouterScope.of(context)?.controller;
    if (router != null && router.canPop()) {
      router.maybePop();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _pick(SetupOption? option) {
    if (option == null || option == _option) return;
    setState(() {
      _option = option;
      _error = null;
      _success = null;
      // A half-finished interactive login belongs to the option that started
      // it.
      _qrPoll?.cancel();
      _qrPoll = null;
      _loginSteps = null;
      _qrCode = null;
      _qrState = null;
      _busy = false;
    });
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
            body: ContentFrame(
              maxWidth: kReadingMaxWidth,
              child: ListView(
                // The headline keeps the page's own gutter, as it does on
                // every other page: the list itself is unpadded, and the
                // form below is inset once. Padding the list too indented
                // this title and its back button a further step past the
                // form, which no other page does.
                padding: const EdgeInsets.only(
                  top: SolSpace.md,
                  bottom: SolSpace.xxxl,
                ),
                children: [
                  // The page names itself and carries the only control that
                  // is not part of the form: the way back, disabled while a
                  // connection attempt is in flight.
                  PageHeadline(
                    title: 'setupTitle'.tr(),
                    leading: canLeave
                        ? Padding(
                            padding: const EdgeInsets.only(right: SolSpace.sm),
                            child: IconButton(
                              tooltip: 'commonBack'.tr(),
                              onPressed: _busy ? null : _leave,
                              icon: const Icon(Symbols.arrow_back_rounded),
                            ),
                          )
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SolSpace.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'setupSubtitle'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: SolSpace.xl),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProviderPicker(
                                option: _option,
                                options: _options,
                                enabled: !_busy,
                                onChanged: _pick,
                              ),
                              const SizedBox(height: SolSpace.lg),
                              ..._formFields(),
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
                              _actions(canLeave: canLeave),
                            ],
                          ),
                        ),
                        if (adapter.needsCredentials) ...[
                          const SizedBox(height: SolSpace.lg),
                          Text(
                            'setupSecurityNote'.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
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

  /// The address, and the credentials when the adapter takes them.
  ///
  /// Three shapes, one per capability the adapter declares: an interactive
  /// login (address plus its steps), a system account (a note, no fields), or
  /// address + username + password.
  List<Widget> _formFields() {
    final addressField = TextFormField(
      controller: _serverController,
      autofocus: true,
      keyboardType: TextInputType.url,
      textInputAction: _isInteractive
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: _isInteractive ? (_) => _startInteractive() : null,
      decoration: InputDecoration(
        labelText: 'setupServerAddress'.tr(),
        hintText: switch (_option) {
          BuiltInOption(:final kind) => kind.addressHint,
          PluginOption() => 'libraryAddressPlugin'.tr(),
        },
        prefixIcon: const Icon(Symbols.dns_rounded),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'setupServerAddressError'.tr();
        final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
        if (uri == null || uri.host.isEmpty) {
          return 'setupServerAddressInvalid'.tr();
        }
        return null;
      },
    );

    if (_isInteractive) {
      return [addressField, ...?_loginSteps?.map(_stepWidget)];
    }
    if (!adapter.needsCredentials) {
      return [
        Text(
          switch (_option) {
            // A plugin that asks for nothing signs itself in: one line says
            // so instead of three empty fields.
            PluginOption() => 'setupPluginNote'.tr(),
            BuiltInOption() => 'setupAppleMusicNote'.tr(),
          },
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ];
    }
    return [
      addressField,
      const SizedBox(height: SolSpace.md),
      TextFormField(
        controller: _usernameController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'setupUsername'.tr(),
          prefixIcon: const Icon(Symbols.person_rounded),
        ),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'setupUsernameError'.tr() : null,
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
        validator: (value) =>
            (value?.isEmpty ?? true) ? 'setupPasswordError'.tr() : null,
      ),
    ];
  }

  /// Connect, and the two ways not to: try the address first, or leave.
  ///
  /// Cancel is here as well as Back in the header: the header is the window's
  /// habit, while an escape under the form, after the primary action, is the
  /// one a form user looks for.
  Widget _actions({required bool canLeave}) {
    final hasPrimary = !_isInteractive || _loginSteps == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPrimary)
          FilledButton(
            onPressed: _busy
                ? null
                : _isInteractive
                ? _startInteractive
                : _connect,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isInteractive
                        ? 'setupStartLogin'.tr()
                        : 'setupConnect'.tr(),
                  ),
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
      ],
    );
  }

  /// Starts the adapter's interactive login: mints the code its first step
  /// needs, then subscribes to that step's scan state. Nothing here knows
  /// which service is being signed in to.
  Future<void> _startInteractive() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final interactive = adapter as InteractiveLoginAdapter;
    final steps = interactive.loginSteps(_serverController.text.trim());
    setState(() {
      _loginSteps = steps;
      _error = null;
      _busy = true;
      _qrCode = null;
      _qrState = null;
    });
    final qr = steps.whereType<QrLoginStep>().firstOrNull;
    if (qr == null) return;
    try {
      final code = await qr.prepare();
      if (!mounted) return;
      // The mint is done; from here the user is scanning, so the Cancel
      // button has to be live again.
      setState(() {
        _qrCode = code;
        _busy = false;
      });
      _qrPoll = qr.poll().listen(
        (state) {
          if (!mounted) return;
          setState(() => _qrState = state);
          if (state == 803) _connectInteractive();
        },
        onError: (Object error) {
          if (!mounted) return;
          // Back to a startable state: an expired code needs a new key, so
          // the button must read "show code" again rather than leaving a
          // dead QR on screen.
          setState(() {
            _error = describeServerError(error);
            _busy = false;
            _loginSteps = null;
            _qrCode = null;
            _qrState = null;
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeServerError(error);
        _busy = false;
        _loginSteps = null;
        _qrCode = null;
        _qrState = null;
      });
    }
  }

  /// Renders one login step: the code while it is being scanned, or a
  /// spinner while it is being minted.
  Widget _stepWidget(LoginStep step) {
    final theme = Theme.of(context);
    return switch (step) {
      QrLoginStep() => Column(
        children: [
          const SizedBox(height: SolSpace.lg),
          // A still, light mat whatever the theme: cameras do not read an
          // inverted code, so the QR keeps a white field of its own.
          Container(
            padding: const EdgeInsets.all(SolSpace.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(SolRadius.md),
            ),
            child: SizedBox(
              width: 200,
              height: 200,
              child: switch (_qrCode) {
                final String code when code.startsWith('data:') => Image.memory(
                  base64Decode(code.split(',').last),
                ),
                final String code => Image.network(code),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
          const SizedBox(height: SolSpace.md),
          Text(
            _qrState == 802 ? 'setupQrScanned'.tr() : step.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
      BusyLoginStep() => Padding(
        padding: const EdgeInsets.only(top: SolSpace.lg),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: SolSpace.md),
            Expanded(child: Text(step.prompt)),
          ],
        ),
      ),
    };
  }

  /// Completes the interactive login and stores the config.
  Future<void> _connectInteractive() async {
    await _qrPoll?.cancel();
    setState(() => _busy = true);
    try {
      final interactive = adapter as InteractiveLoginAdapter;
      final config = await interactive.completeLogin(
        _serverController.text.trim(),
        _loginSteps ?? const [],
      );
      await ref.read(sourceStoreProvider.notifier).add(config);
      TextInput.finishAutofillContext();
      if (mounted) _leave();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeServerError(error);
        _busy = false;
      });
    }
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

/// The provider menu: one labelled control, named after the services a person
/// recognises rather than after the protocol behind them.
class _ProviderPicker extends StatelessWidget {
  final SetupOption option;
  final List<SetupOption> options;
  final bool enabled;
  final ValueChanged<SetupOption?> onChanged;

  const _ProviderPicker({
    required this.option,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<SetupOption>(
      // The form field owns the value once it has been built; `initialValue`
      // is what a rebuild passes back, and a new pick is reported through
      // [onChanged] to the screen's own state.
      initialValue: option,
      isExpanded: true,
      enabled: enabled,
      itemHeight: 56,
      borderRadius: SolRadius.menuRadius,
      menuMaxHeight: 320,
      icon: const Icon(Symbols.unfold_more_rounded),
      decoration: InputDecoration(labelText: 'setupProvider'.tr()),
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: SolSpace.md),
                Expanded(
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
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
