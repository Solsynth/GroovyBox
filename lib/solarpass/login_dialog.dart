import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import 'models.dart';
import 'providers.dart';

class SolarpassLoginDialog extends ConsumerStatefulWidget {
  const SolarpassLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const SolarpassLoginDialog(),
    );
  }

  @override
  ConsumerState<SolarpassLoginDialog> createState() =>
      _SolarpassLoginDialogState();
}

class _SolarpassLoginDialogState extends ConsumerState<SolarpassLoginDialog> {
  bool _loading = false;
  String? _errorMessage;
  DeviceAuthorization? _deviceAuth;

  Future<void> _signInWithBrowser() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _deviceAuth = null;
    });

    try {
      await ref.read(solarpassSessionProvider.notifier).signInBrowser();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('OAuthException: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithDeviceCode() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(solarpassSessionProvider.notifier)
          .signInDevice(
            onDeviceCode: (auth) {
              if (mounted) {
                setState(() {
                  _deviceAuth = auth;
                });
              }
            },
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('OAuthException: ', '');
          _loading = false;
          _deviceAuth = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(SolSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: SolSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'solarpassSignInTitle'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'solarpassSignInSubtitle'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: _loading && _deviceAuth != null
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: SolSpace.lg),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(SolSpace.md),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.error_rounded,
                        color: scheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: SolSpace.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SolSpace.md),
              ],

              if (_deviceAuth != null) ...[
                _buildDeviceAuthContent(theme, scheme, _deviceAuth!),
              ] else ...[
                Text(
                  'solarpassSignInDescription'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SolSpace.xl),

                FilledButton.icon(
                  onPressed: _loading ? null : _signInWithBrowser,
                  icon: _loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Symbols.open_in_browser_rounded),
                  label: Text('solarpassSignInWithBrowser'.tr()),
                ),
                const SizedBox(height: SolSpace.sm),

                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithDeviceCode,
                  icon: const Icon(Symbols.devices_rounded),
                  label: Text('solarpassSignInWithDeviceCode'.tr()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceAuthContent(
    ThemeData theme,
    ColorScheme scheme,
    DeviceAuthorization auth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'solarpassDeviceCodeInstructions'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SolSpace.md),
        Container(
          padding: const EdgeInsets.all(SolSpace.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SelectableText(
                auth.userCode,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: SolSpace.xs),
              Text(
                auth.verificationUri.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SolSpace.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: auth.userCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('solarpassCopiedToClipboard'.tr())),
                  );
                },
                icon: const Icon(Symbols.content_copy_rounded, size: 18),
                label: Text('solarpassCopyCode'.tr()),
              ),
            ),
            const SizedBox(width: SolSpace.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => launchUrl(auth.verificationUriComplete),
                icon: const Icon(Symbols.open_in_new_rounded, size: 18),
                label: Text('solarpassOpenPage'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: SolSpace.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: SolSpace.sm),
            Text(
              'solarpassWaitingForApproval'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
