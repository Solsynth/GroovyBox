import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/pulsar/metadata.dart';
import 'package:groovy_box/widgets/section.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The description a page draws under an artist's or album's hero: the
/// biography MusicBrainz pointed at on Wikipedia, in the reader's language
/// when it exists.
///
/// It is a *section*, not part of the hero: the hero is one block that has to
/// stay the same height on every page, and prose is the one thing whose
/// length the page cannot predict. Here it can grow, and the page's own
/// content below keeps its place.
class EntityProse extends StatelessWidget {
  final PulsarEntityMetadata metadata;

  /// What the section is called: "About". A section header rather than a
  /// heading over the text, so it matches every other block on the page.
  final String? title;

  const EntityProse({super.key, required this.metadata, this.title});

  @override
  Widget build(BuildContext context) {
    final prose = metadata.prose;
    if (prose == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final source = metadata.proseSource;
    final article = metadata.wikipedia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title ?? 'entityAbout'.tr()),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xxl,
            0,
            SolSpace.xxl,
            SolSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prose,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
              if (source != null || article != null) ...[
                const SizedBox(height: SolSpace.sm),
                Wrap(
                  spacing: SolSpace.md,
                  runSpacing: SolSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (source != null)
                      Text(
                        'entityProseSource'.tr(args: [source]),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    if (article != null)
                      _LinkButton(label: article.label, url: article.url),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The facts line under a hero: what kind of act this is, where they are
/// from, and when.
///
/// One row of chips rather than a sentence, because these are attributes a
/// reader scans — "Japanese · Group · 1991" — and a sentence would make them
/// read as prose that happens to mention facts.
class EntityFacts extends StatelessWidget {
  final PulsarEntityMetadata metadata;

  const EntityFacts({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = <Widget>[];
    final profile = metadata.artist;

    void add(String label) {
      facts.add(
        Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.xs),
        ),
      );
    }

    final type = profile?.type;
    if (type != null && type.trim().isNotEmpty) add(type);
    final origin = metadata.origin;
    if (origin != null) add(origin);
    final lifespan = metadata.lifespan;
    if (lifespan != null) add(lifespan);
    if (metadata.scrobbleCount > 0) {
      add('entityPlays'.plural(metadata.scrobbleCount));
    }

    final genres = metadata.genres.take(4).toList();
    for (final genre in genres) {
      facts.add(
        Chip(
          label: Text(genre),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.xs),
          backgroundColor: theme.colorScheme.secondaryContainer,
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      );
    }

    if (facts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        0,
        SolSpace.xxl,
        SolSpace.sm,
      ),
      child: Wrap(
        spacing: SolSpace.sm,
        runSpacing: SolSpace.sm,
        children: facts,
      ),
    );
  }
}

/// One external link — MusicBrainz, Wikipedia, the artist's own site — as a
/// quiet text button.
class _LinkButton extends StatelessWidget {
  final String label;
  final String url;

  const _LinkButton({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: const Icon(Symbols.open_in_new_rounded, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// The record's outward links, as one row under the page's own content.
class EntityLinks extends StatelessWidget {
  final PulsarEntityMetadata metadata;

  const EntityLinks({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final links = metadata.externalLinks
        .where((link) => link.url.trim().isNotEmpty)
        .toList();
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.xs,
        SolSpace.xxl,
        SolSpace.sm,
      ),
      child: Wrap(
        spacing: SolSpace.sm,
        runSpacing: SolSpace.xs,
        children: [
          for (final link in links)
            _LinkButton(label: link.label, url: link.url),
        ],
      ),
    );
  }
}
