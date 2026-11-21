import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:solsynth_express/api.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a release says, and — when this platform has an artifact — the way to
/// its download.
///
/// GroovyBox does not install in place. An app that replaces its own bundle
/// has to own code signing, notarisation and the platform's update channel,
/// and this app ships through the store listings for the same binaries; the
/// sheet therefore hands the reader the release page and the file, which is
/// the one update path that cannot install something the user did not choose.
class ReleaseSheet extends StatelessWidget {
  const ReleaseSheet({
    super.key,
    required this.release,
    this.currentVersion,
    this.artifact,
    this.updateAvailable = true,
  });

  final DistributionReleaseInfo release;

  /// The build being replaced. Null when the caller does not know it.
  final String? currentVersion;

  /// The file published for this platform, when there is one.
  final DistributionArtifact? artifact;

  /// False for the "what's new" reading of the release being run.
  final bool updateAvailable;

  static Future<void> show(
    BuildContext context, {
    required DistributionReleaseInfo release,
    String? currentVersion,
    DistributionArtifact? artifact,
    bool updateAvailable = true,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: ReleaseSheet(
        release: release,
        currentVersion: currentVersion,
        artifact: artifact,
        updateAvailable: updateAvailable,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notes = release.body.trim();
    final page = release.htmlUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.xl,
              SolSpace.xs,
              SolSpace.xl,
              SolSpace.md,
            ),
            children: [
              _ReleaseCard(
                release: release,
                currentVersion: currentVersion,
                artifact: artifact,
                updateAvailable: updateAvailable,
              ),
              const SizedBox(height: SolSpace.md),
              IslandCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(SolSpace.lg),
                child: notes.isEmpty
                    ? Text(
                        'updatesNoNotes'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : MarkdownBody(
                        data: notes,
                        selectable: true,
                        // Built from this app's own text theme rather than
                        // `fromTheme`: that factory takes Flutter's Material
                        // `ThemeData`, and this app renders `material_ui`'s.
                        // The two `TextStyle`s are the same `dart:ui` type.
                        styleSheet: _markdownStyles(theme),
                        onTapLink: (_, href, _) {
                          final uri = href == null ? null : Uri.tryParse(href);
                          if (uri != null) openExternally(uri);
                        },
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            SolSpace.xl,
            SolSpace.sm,
            SolSpace.xl,
            SolSpace.lg + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  // The release page is the fallback whenever this platform
                  // has no artifact: the feed still says what shipped.
                  onPressed: artifact != null || page != null
                      ? () => _open(
                          artifact?.downloadUrl ?? page!,
                        )
                      : null,
                  icon: Icon(
                    artifact != null
                        ? Symbols.download_rounded
                        : Symbols.open_in_new_rounded,
                    size: 18,
                  ),
                  label: Text(
                    artifact != null
                        ? 'updatesDownload'.tr()
                        : 'updatesOpenReleasePage'.tr(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The release-note stylesheet: the app's body text, with headings a step
  /// down from a page's so a changelog never outranks the sheet's own title.
  static MarkdownStyleSheet _markdownStyles(ThemeData theme) {
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.55);
    final code = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * 0.85,
    );
    return MarkdownStyleSheet(
      p: body,
      a: body?.copyWith(color: scheme.primary),
      em: body?.copyWith(fontStyle: FontStyle.italic),
      strong: body?.copyWith(fontWeight: FontWeight.w700),
      del: body?.copyWith(decoration: TextDecoration.lineThrough),
      code: code,
      blockquote: body?.copyWith(color: scheme.onSurfaceVariant),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.outlineVariant, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(
        SolSpace.md,
        SolSpace.xs,
        SolSpace.sm,
        SolSpace.xs,
      ),
      codeblockDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SolRadius.xs),
      ),
      codeblockPadding: const EdgeInsets.all(SolSpace.md),
      h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      listBulletPadding: const EdgeInsets.only(right: SolSpace.sm),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      blockSpacing: SolSpace.md,
      listIndent: SolSpace.lg,
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await openExternally(uri);
  }
}

/// Opens [uri] in the system browser or store, ignoring a failure: a machine
/// with no handler for a URL scheme should not see an error for choosing it.
Future<void> openExternally(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Which release this is, what it replaces, and how big the download is: the
/// facts a reader checks before deciding.
class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.release,
    required this.currentVersion,
    required this.artifact,
    required this.updateAvailable,
  });

  final DistributionReleaseInfo release;
  final String? currentVersion;
  final DistributionArtifact? artifact;
  final bool updateAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final installed = currentVersion?.trim();
    final channel = release.channel.trim();
    final publishedAt = release.publishedAt ?? release.createdAt;
    final size = artifact?.size;

    return IslandCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(SolSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(SolRadius.sm),
                ),
                child: Icon(
                  Symbols.system_update_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: SolSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.name.isEmpty ? release.tagName : release.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // The tag is only written here when nothing else states
                    // it: with a known install, the transition line below is
                    // the version, and repeating it in the header made the
                    // card say the same thing twice.
                    if (installed == null || installed.isEmpty) ...[
                      const SizedBox(height: SolSpace.xxs),
                      Text(
                        release.tagName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (installed != null && installed.isNotEmpty) ...[
            const SizedBox(height: SolSpace.md),
            _VersionTransition(from: installed, to: release.tagName),
          ],
          const SizedBox(height: SolSpace.md),
          Wrap(
            spacing: SolSpace.sm,
            runSpacing: SolSpace.sm,
            children: [
              if (channel.isNotEmpty)
                _MetaChip(
                  icon: Symbols.new_releases_rounded,
                  label: 'updatesChannelValue'.tr(args: [channel]),
                ),
              if (size != null && size > 0)
                _MetaChip(
                  icon: Symbols.download_rounded,
                  label: 'updatesDownloadSize'.tr(args: [formatBytes(size)]),
                ),
              _MetaChip(
                icon: Symbols.calendar_today_rounded,
                label: _formatDate(publishedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// `2026-10-18` — one spelling every locale reads without a date formatter.
  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

/// `2.0.0+21 → 2.1.0+24`, the line that says what the install replaces.
class _VersionTransition extends StatelessWidget {
  const _VersionTransition({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        Text('updatesInstalledVersion'.tr(), style: style),
        const SizedBox(width: SolSpace.xs),
        Flexible(child: Text(from, style: style, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: SolSpace.xs),
        Icon(
          Symbols.arrow_forward_rounded,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: SolSpace.xs),
        Flexible(
          child: Text(
            to,
            overflow: TextOverflow.ellipsis,
            style: style?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SolSpace.sm + 2,
        vertical: SolSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SolRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: SolSpace.xs + 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
