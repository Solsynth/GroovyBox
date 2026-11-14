import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Asks for a playlist name, and returns the trimmed answer or null.
///
/// A name is asked for rather than invented: a playlist called "New playlist"
/// is one the user has to rename before it means anything, and the moment
/// after creating it is the moment they know what it is for.
///
/// No [TextEditingController]: the dialog is still animating out when this
/// future completes, and a controller disposed at that point is read by the
/// closing route's field — a crash, not a leak. The typed value is held in a
/// local that the field writes through `onChanged`.
Future<String?> askPlaylistName(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirmLabelKey = 'commonCreate',
}) async {
  var typed = initial;
  final answer = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: 'playlistPickerNewLabel'.tr()),
        onChanged: (value) => typed = value,
        onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(typed),
          child: Text(confirmLabelKey.tr()),
        ),
      ],
    ),
  );
  final trimmed = (answer ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The small square tile used for icon-only rows in menus and pickers.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;

  const IconTile(this.icon, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(SolRadius.sm),
        ),
        child: Icon(icon, size: size * 0.55),
      ),
    );
  }
}
