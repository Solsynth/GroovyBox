import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/widgets/brand_mark.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The installed app's version metadata.
///
/// `PackageInfo.fromPlatform` caches its answer, so this resolves once per
/// process; the page reads it through an `AsyncValue` only to keep the hero
/// from waiting on a plugin call to draw the name and the mark.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// The repository, opened in the default browser.
const _repositoryUrl = 'https://src.solsynth.dev/Solsynth/GroovyBox';

/// The network GroovyBox signs in to for presence, sync and translation.
const _solarNetworkUrl = 'https://solsynth.dev/products/solar-network';

/// About: what this build is, where its source lives, and what it is built
/// from.
///
/// A page rather than a dialog because the licenses live behind it, and a
/// license list is a document, not an aside. The order is the order a person
/// asks in: which build is this, who made it, what does it owe.
@RoutePage()
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = ref.watch(packageInfoProvider).value;

    return Scaffold(
      body: ContentFrame(
        maxWidth: kReadingMaxWidth,
        child: PageListView(
          padding: const EdgeInsets.only(bottom: SolSpace.huge),
          children: [
            BackButtonRow(onBack: () => context.router.maybePop()),
            _Hero(info: info),
            SectionLabel('aboutAppInfo'.tr()),
            _Card(
              padding: _listCardPadding,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Symbols.tag_rounded,
                    label: 'aboutVersion'.tr(),
                    value: info?.version,
                  ),
                  _InfoRow(
                    icon: Symbols.build_rounded,
                    label: 'aboutBuild'.tr(),
                    value: info?.buildNumber,
                  ),
                  if (info != null && info.packageName.isNotEmpty)
                    _InfoRow(
                      icon: Symbols.inventory_2_rounded,
                      label: 'aboutPackageName'.tr(),
                      value: info.packageName,
                      selectable: true,
                    ),
                ],
              ),
            ),
            SectionLabel('aboutOtherWorks'.tr()),
            _Card(
              padding: _listCardPadding,
              child: ListTile(
                contentPadding: _rowPadding,
                leading: Icon(
                  Symbols.diversity_3_rounded,
                  color: scheme.primary,
                ),
                title: Text('aboutSolarNetworkName'.tr()),
                subtitle: Text('aboutSolarNetworkDescription'.tr()),
                // An icon rather than a text button: a "See more" in the
                // trailing slot squeezes the description into a column three
                // words wide. The whole row is the target.
                trailing: const Icon(Symbols.open_in_new_rounded),
                onTap: () => _open(_solarNetworkUrl),
              ),
            ),
            SectionLabel('aboutLegal'.tr()),
            _Card(
              padding: _listCardPadding,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: _rowPadding,
                    leading: const Icon(Symbols.description_rounded),
                    title: Text('aboutOpenSourceLicenses'.tr()),
                    subtitle: Text('aboutOpenSourceLicensesHint'.tr()),
                    trailing: const Icon(Symbols.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'GroovyBox',
                      applicationVersion: info == null
                          ? null
                          : '${info.version} (${info.buildNumber})',
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(SolSpace.sm),
                        child: BrandMark(size: 48),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: _rowPadding,
                    leading: const Icon(Symbols.code_rounded),
                    title: Text('aboutSourceCode'.tr()),
                    // No single-line clamp: the address is the point of the
                    // row, and a URL cut at the host is a URL nobody can
                    // check. It wraps at its slashes instead.
                    subtitle: Text(_repositoryUrl),
                    trailing: const Icon(Symbols.open_in_new_rounded),
                    onTap: () => _open(_repositoryUrl),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.xxl,
                SolSpace.xxl,
                SolSpace.xxl,
                SolSpace.lg,
              ),
              child: Column(
                children: [
                  Text(
                    'aboutCopyright'.tr(args: ['${DateTime.now().year}']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SolSpace.xs),
                  Text(
                    'aboutMadeWith'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// One card's outside inset, and one row's inside inset, as on Settings.
const _cardMargin = EdgeInsets.symmetric(horizontal: SolSpace.xl);
const _rowPadding = EdgeInsets.symmetric(horizontal: SolSpace.lg);

/// The rows keep the same hairline of space the settings cards do, so the two
/// pages read as one system.
const _listCardPadding = EdgeInsets.symmetric(vertical: SolSpace.sm);

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(SolSpace.lg),
  });

  @override
  Widget build(BuildContext context) {
    return IslandCard(margin: _cardMargin, padding: padding, child: child);
  }
}

/// The mark, the name and the one-line answer to "what is this".
class _Hero extends StatelessWidget {
  final PackageInfo? info;

  const _Hero({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.sm,
        SolSpace.xxl,
        SolSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 96),
          const SizedBox(height: SolSpace.lg),
          Text(
            'GroovyBox',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SolSpace.xs),
          Text(
            switch (info) {
              final info? => 'aboutVersionInfo'.tr(
                args: [info.version, info.buildNumber],
              ),
              null => 'aboutVersionUnknown'.tr(),
            },
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SolSpace.md),
          Text(
            'aboutDescription'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// One fact about the build: the label, then the value under it.
///
/// Stacked rather than set side by side: a package name or a build hash is
/// one unbreakable word, and a trailing column narrow enough for the longest
/// of them breaks it mid-word. Under the label it has the card's whole width,
/// and the row still reads top-down like every other line on the page.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool selectable;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = value ?? '…';
    final style = theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SolSpace.lg,
        vertical: SolSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: SolSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: style?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: SolSpace.xxs),
                selectable
                    ? SelectableText(text, style: style)
                    : Text(text, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
