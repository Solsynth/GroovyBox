import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:groovybox/data/db.dart' as db;
import 'package:groovybox/ui/widgets/universal_image.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:styled_widget/styled_widget.dart';

class TrackTile extends StatelessWidget {
  final db.Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool showTrailingIcon;
  final VoidCallback? onTrailingPressed;
  final Widget? leading;
  final EdgeInsets? padding;

  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.leading,
    this.padding,
    this.showTrailingIcon = false,
    this.onTrailingPressed,
  });

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return '--:--';
    final d = Duration(milliseconds: durationMs);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPlaying
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) leading!,
            AspectRatio(
              aspectRatio: 1,
              child: UniversalImage(
                uri: track.artUri,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
                fallbackIcon: Symbols.music_note,
                fallbackIconSize: 24,
              ).clipRRect(all: 8),
            ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            color: isPlaying
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${track.artist ?? context.tr('unknownArtist')} - ${_formatDuration(track.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: showTrailingIcon
            ? IconButton(
                icon: const Icon(Symbols.more_vert),
                onPressed: onTrailingPressed,
              )
            : isPlaying
            ? Icon(
                Symbols.play_arrow,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}