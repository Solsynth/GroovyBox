import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/lrclib.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Hand-picking the words for the song that is playing.
///
/// The automatic chain — library, then LRCLIB — fails on the same tracks
/// every time: a mistagged title, a cover whose artist is the original
/// performer, a local release the service has never heard of. This sheet is
/// the way out, and it answers both ways a user can:
///
/// - a free-text search over LRCLIB, typed however they think of the song,
///   so the library's tags stop deciding what is findable;
/// - their own `.lrc` or plain-text file, for anything no service has.
///
/// Either answer is stored as [LyricsOrigin.manual], which no automatic
/// fetch ever displaces: a deliberate choice outlives every re-ask.
class LyricsPickerSheet extends ConsumerStatefulWidget {
  const LyricsPickerSheet({super.key, required this.song});

  final LibrarySong song;

  /// Opens the sheet for [song], returning when a lyric was chosen.
  static Future<void> show(BuildContext context, LibrarySong song) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: LyricsPickerSheet(song: song),
        ),
      );

  @override
  ConsumerState<LyricsPickerSheet> createState() => _LyricsPickerSheetState();
}

class _LyricsPickerSheetState extends ConsumerState<LyricsPickerSheet> {
  late final TextEditingController _query = TextEditingController(
    text: [
      if (widget.song.artist?.isNotEmpty ?? false) widget.song.artist!,
      widget.song.title,
    ].join(' '),
  );
  late final FocusNode _queryFocus = FocusNode();

  /// Null means the answer could not be had — a rate limit or a dead
  /// network — which reads differently from an honest empty page.
  AsyncValue<List<LrclibCandidate>?> _results = const AsyncValue.data(null);
  bool _importing = false;

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  /// Searches LRCLIB with whatever the field holds. The field is prefilled
  /// with the playing track's tags, so a mistagged title is exactly the case
  /// where the user edits it before submitting.
  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() => _results = const AsyncValue.loading());
    final found = await ref.read(lrclibProvider).search(query);
    if (!mounted) return;
    setState(() => _results = AsyncValue.data(found));
  }

  /// Adopts [lyrics] for the playing track and closes the sheet.
  Future<void> _adopt(Lyrics lyrics) async {
    // Read before the await: a context use must not cross an async gap.
    final languageCode = Localizations.localeOf(context).languageCode;
    final resolver = await ref.read(lyricsResolverProvider.future);
    await resolver.adopt(
      LyricsRequest.of(widget.song),
      lyrics,
      languageCode: languageCode,
    );
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  /// Asks for an `.lrc` or plain-text file and adopts what it parses.
  ///
  /// An LRC grammar yields timed lines; a plain file becomes an unsynced
  /// block, which the view scrolls by hand — the same two shapes a library
  /// answer can take.
  Future<void> _importFile() async {
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'lyricsPickFile'.tr(),
        type: FileType.custom,
        allowedExtensions: ['lrc', 'txt'],
      );
      if (picked.isEmpty) return;
      final file = picked.first;
      final raw = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      final parsed = parseLrc(raw);
      final lyrics = parsed.lines.isNotEmpty
          ? parsed
          : Lyrics(
              lines: [
                for (final line in const LineSplitter().convert(raw))
                  if (line.trim().isNotEmpty)
                    LyricLine(Duration.zero, line.trim()),
              ],
              synced: false,
            );
      if (lyrics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('lyricsPickFileEmpty'.tr())),
          );
        }
        return;
      }
      await _adopt(lyrics);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xl,
            0,
            SolSpace.xl,
            SolSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'lyricsPickerTitle'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // What was looked up, so the sheet is unambiguous when two
                // tracks share a title.
                '${widget.song.artist ?? 'playerUnknownArtist'.tr()}  ·  ${widget.song.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(SolSpace.xl, 0, SolSpace.xl, SolSpace.sm),
          child: TextField(
            controller: _query,
            focusNode: _queryFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'lyricsPickerSearchHint'.tr(),
              prefixIcon: const Icon(Symbols.search_rounded, size: 20),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'lyricsPickerSearch'.tr(),
                onPressed: _search,
                icon: const Icon(Symbols.arrow_forward_rounded, size: 20),
              ),
            ),
          ),
        ),
        Expanded(child: _resultsList(theme)),
        Padding(
          padding: const EdgeInsets.fromLTRB(SolSpace.xl, 0, SolSpace.xl, SolSpace.md),
          child: OutlinedButton.icon(
            onPressed: _importing ? null : _importFile,
            icon: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.file_open_rounded, size: 18),
            label: Text('lyricsPickFile'.tr()),
          ),
        ),
      ],
    );
  }

  Widget _resultsList(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return _results.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => EmptyState(
        compact: true,
        icon: Symbols.cloud_off_rounded,
        title: 'lyricsPickerFailedTitle'.tr(),
        message: 'lyricsPickerFailedDetail'.tr(),
        action: TextButton.icon(
          onPressed: _search,
          icon: const Icon(Symbols.refresh_rounded, size: 18),
          label: Text('lyricsAskAgain'.tr()),
        ),
      ),
      data: (candidates) {
        if (candidates == null) {
          // Not yet asked: the sheet opened, no request has gone out. The
          // field is already filled, so the one action is to submit it.
          return EmptyState(
            compact: true,
            icon: Symbols.search_rounded,
            title: 'lyricsPickerPrompt'.tr(),
            message: 'lyricsPickerPromptDetail'.tr(),
          );
        }
        if (candidates.isEmpty) {
          return EmptyState(
            compact: true,
            icon: Symbols.lyrics_rounded,
            title: 'lyricsPickerNoneTitle'.tr(),
            message: 'lyricsPickerNoneDetail'.tr(),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: SolSpace.md),
          itemCount: candidates.length,
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            final timed = candidate.lyrics.synced;
            // The runtimes are what decide whether these words will land on
            // the right line, so a mismatch is worth naming, not hiding.
            final lengthNote = widget.song.duration == Duration.zero ||
                    candidate.duration == null
                ? null
                : formatDuration(candidate.duration!);
            final drift = lengthNote == null
                ? null
                : (candidate.duration! - widget.song.duration).abs();
            return TrackRow(
              title: candidate.title,
              subtitle: [
                if (candidate.artistName != null) candidate.artistName!,
                if (candidate.albumName != null) candidate.albumName!,
                ?lengthNote,
                timed ? 'lyricsPickerSynced'.tr() : 'lyricsPickerPlain'.tr(),
              ].join('  ·  '),
              trailing: drift != null && drift > const Duration(seconds: 5)
                  ? 'lyricsPickerDrift'.tr()
                  : null,
              leading: Icon(
                timed ? Symbols.lyrics_rounded : Symbols.notes_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => _adopt(candidate.lyrics),
            );
          },
        );
      },
    );
  }
}
