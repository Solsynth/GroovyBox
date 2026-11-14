import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../library/models.dart';
import '../player/player.dart';
import 'format.dart';

/// Centers a page's content in one column on wide windows.
///
/// Without this every row, cover and empty state stretches across a maximized
/// window. The column stops at [maxWidth]; the extra pixels become gutter, and
/// the page keeps its normal [SolSpace] insets inside the column.
class ContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The card primitive: a tonal island of the same warm paper, no border, no
/// glass. Same tone family as Solian's `ExploreCard`, so the two apps' cards
/// read as one system.
///
/// Cards sit *in* the scrolling plane, so they are deliberately opaque and
/// unblurred — a sampled material behind body text costs legibility and a
/// backdrop copy per frame, and a long list pays that per card. Separation
/// comes from tone and space, which is why no divider is ever drawn between
/// two of these.
///
/// The optional [onTap] adds a ripple clipped to the card's shape, so the
/// whole island reads as one target.
class IslandCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double cornerRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Slightly deeper tone, for a card that is selected or emphasised.
  final bool emphasised;

  const IslandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: SolSpace.sm),
    this.margin = EdgeInsets.zero,
    this.cornerRadius = SolRadius.card,
    this.onTap,
    this.onLongPress,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // A real `Material` rather than a decorated box: rows inside (ListTile
    // especially) paint their own ink on the nearest Material, so the card's
    // fill has to be that Material or the ripples land underneath it.
    return Padding(
      padding: margin,
      child: Material(
        color: emphasised
            ? colorScheme.surfaceContainer
            : colorScheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        child: onTap == null && onLongPress == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// The one placeholder for every empty surface: dimmed icon, bold line, quiet
/// explanation, optional way out.
///
/// Pass [compact] inside sheets and panels, and [iconColor] for errors. Do not
/// build a second placeholder style next to this one.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? SolSpace.xl : SolSpace.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 26 : 32,
                color:
                    iconColor ??
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            SizedBox(height: compact ? SolSpace.md : SolSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: SolSpace.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? SolSpace.md : SolSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Header used at the top of every tab: a title, an optional subtitle and a
/// row of trailing actions, aligned like a document rather than centered.
///
/// [leading] is the back affordance for pushed pages; tabs leave it empty.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.xl,
        SolSpace.md,
        SolSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SolSpace.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Back button for a pushed page's [PageHeader].
class HeaderBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const HeaderBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'commonBack'.tr(),
      onPressed: onPressed,
      icon: const Icon(Symbols.arrow_back_rounded),
    );
  }
}


/// Section label above a group of rows or cards.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SolSpace.xxl,
        SolSpace.lg,
        SolSpace.xxl,
        SolSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Album/track list rows share one shape: an optional leading slot, cover,
/// two lines, trailing text.
///
/// Rows are separated by space and hover tone, never by a divider: a list of
/// hairlines reads as a table, and this is a playlist. The hover and selected
/// fills are rounded so a row reads as one object.
class TrackRow extends StatelessWidget {
  final String title;
  final String subtitle;

  /// A fixed slot before the artwork: a track number in an album, where the
  /// position in the record is information the title does not carry.
  ///
  /// [wide] is the width reserved, in logical pixels; the leading content is
  /// right aligned in it so single digits line up with two.
  final Widget? leading;
  final double leadingWidth;
  final Widget? artwork;
  final String? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TrackRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.leadingWidth = 28,
    this.artwork,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.md, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(SolRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: SolSpace.md,
              vertical: SolSpace.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.6)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(SolRadius.md),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(
                    width: leadingWidth,
                    // Centred against the row's two lines, not their first:
                    // a number aligned to the box's top read as raised above
                    // the title it belongs to.
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: leading,
                    ),
                  ),
                  const SizedBox(width: SolSpace.sm),
                ],
                if (artwork != null) ...[
                  artwork!,
                  const SizedBox(width: SolSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? colorScheme.onSecondaryContainer.withValues(
                                  alpha: 0.8,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: SolSpace.sm),
                    child: Text(
                      trailing!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [TrackRow] for one library song, selected while that song is playing.
///
/// The selection is the only part of a list that changes on a transport tick,
/// and it is decided by a `select` on the song's identity: a list of fifty
/// rows no longer repaints because the player's position moved, and a row no
/// longer has to watch the whole [PlaybackState] to know it is the one on
/// the air.
///
/// Rows that are not songs (an album's rank, a search hit the library cannot
/// play) still use [TrackRow] directly.
class SongTrackRow extends ConsumerWidget {
  final LibrarySong song;

  /// What the row says, when it differs from the track's own title and
  /// subtitle: a playlist row names the album, an album row names the artist.
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final double leadingWidth;
  final Widget? artwork;
  final String? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTrackRow({
    super.key,
    required this.song,
    this.title,
    this.subtitle,
    this.leading,
    this.leadingWidth = 28,
    this.artwork,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The song's identity, not the transport: `isCurrentSong` also matches a
    // copy of the same track from another library, which is exactly what a
    // merged list shows.
    final selected = ref.watch(
      playbackProvider.select((state) => state.isCurrentSong(song)),
    );
    return TrackRow(
      title: title ?? song.playing.title,
      subtitle: subtitle ?? songRowSubtitle(ref, song),
      leading: leading,
      leadingWidth: leadingWidth,
      artwork: artwork,
      trailing: trailing,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Turns any thrown value into a line the UI can show.
///
/// Server failures carry their own message, and a key when the app diagnosed
/// the failure itself: the key is resolved against the current locale here, so
/// adapters stay free of UI concerns. Anything else is reported without
/// claiming more than we know.
String describeServerError(Object error) {
  if (error is LibraryException) {
    final key = error.messageKey;
    return key == null ? error.message : key.tr(args: error.messageArgs);
  }
  return 'commonLibraryUnreachable'.tr();
}
