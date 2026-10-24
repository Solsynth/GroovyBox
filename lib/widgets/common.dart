import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../server/models.dart';

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
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 32 : 44,
                color: iconColor ?? colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.55,
                ),
              ),
              SizedBox(height: compact ? 8 : 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (action != null) ...[
                SizedBox(height: compact ? 12 : 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Header used at the top of every tab: a title, an optional subtitle and a
/// row of trailing actions, aligned like a document rather than centered.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
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

/// Thin divider used between logical groups, inset to the page gutter.
class GroupDivider extends StatelessWidget {
  const GroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: SolSpace.lg,
      indent: SolSpace.xxl,
      endIndent: SolSpace.xxl,
    );
  }
}

/// Album/track list rows share one shape: cover, two lines, trailing duration.
class TrackRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? artwork;
  final String? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TrackRow({
    super.key,
    required this.title,
    required this.subtitle,
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

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SolSpace.xxl,
        vertical: SolSpace.xxs,
      ),
      leading: artwork,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}


/// Turns any thrown value into a line the UI can show.
///
/// Server failures carry their own message; anything else is reported without
/// claiming more than we know.
String describeServerError(Object error) {
  return switch (error) {
    SubsonicException(:final message) => message,
    _ => 'Something went wrong while talking to the server.',
  };
}
