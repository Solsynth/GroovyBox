import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The library a playlist lives in, named for its detail page.
///
/// A playlist can belong to this device, a server, or the account's cloud. The
/// library page lists them all together, so the detail page is where that is
/// said: the local source is "Local files" rather than the store's own
/// "Local" label, and a server is named as it is in settings.
String playlistSourceName(String sourceId, WidgetRef ref) {
  if (sourceId == kLocalSourceId) return LibraryKind.local.label;
  return ref.watch(librarySourceByIdProvider)[sourceId]?.displayName ??
      LibraryKind.local.label;
}

/// A section's name, above the content it introduces, with an optional
/// smaller line under it saying where the content came from.
///
/// When [onToggle] is set the name is also the fold: tapping it collapses the
/// section under it, and the chevron says which way it is about to go.
/// Trailing actions stay live so "new playlist" still works on a folded
/// section.
class SectionHeader extends StatelessWidget {
  final String title;

  /// Where the section's content came from — a library, a device, an account.
  /// Null for a section the app itself assembled from several.
  final String? subtitle;
  final Widget? trailing;

  /// Collapse state, when this header folds its section.
  final bool collapsed;
  final VoidCallback? onToggle;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.collapsed = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    // The source line is a quiet second line, not a second title: it answers
    // "where is this from", while the name answers "what is this".
    final source = switch (subtitle) {
      final source? => Text(
        source,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      null => null,
    };
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: name),
            if (onToggle != null) ...[
              const SizedBox(width: SolSpace.xs),
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Symbols.expand_more_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        ?source,
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.xl,
        SolSpace.lg,
        SolSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: onToggle == null
                ? label
                : InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(SolRadius.sm),
                    child: label,
                  ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One foldable section of a page, as slivers.
///
/// [page] namespaces the fold state: the library and the dashboard both fold
/// sections, and a fold on one page must not move a section on the other.
/// [id] names the shelf rather than its position, so reordering a page never
/// moves a fold. The header is always drawn — folding is a way to move down
/// the page, not a way to lose the way back — and the body is built only while
/// it is open, so a folded section costs its header and nothing else.
class FoldableSection extends ConsumerWidget {
  final String page;
  final String id;
  final String title;

  /// Where the section's content came from, shown under its name.
  final String? subtitle;
  final Widget? trailing;

  /// The section's own slivers. Called only while the section is open.
  final List<Widget> Function() builder;

  const FoldableSection({
    super.key,
    required this.page,
    required this.id,
    required this.title,
    required this.builder,
    this.subtitle,
    this.trailing,
  });

  /// The key [id] is remembered under, for [CollapsedSections].
  static String keyOf(String page, String id) => '$page:$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(
      collapsedSectionsProvider.select((set) => set.contains(keyOf(page, id))),
    );
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            collapsed: collapsed,
            onToggle: () =>
                ref.read(collapsedSectionsProvider.notifier).toggle(page, id),
          ),
        ),
        if (!collapsed) ...builder(),
      ],
    );
  }
}
