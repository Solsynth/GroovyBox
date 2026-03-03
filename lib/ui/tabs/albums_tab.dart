import 'package:easy_localization/easy_localization.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:groovybox/data/playlist_repository.dart';

import 'package:groovybox/ui/screens/album_detail_screen.dart';
import 'package:groovybox/ui/widgets/universal_image.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

class AlbumsTab extends HookConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(playlistRepositoryProvider.notifier);

    return StreamBuilder<List<AlbumData>>(
      stream: repo.watchAllAlbums(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final albums = snapshot.data!;

        if (albums.isEmpty) {
          return Center(child: Text('noAlbumsFound'.tr()));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return OpenContainer(
              openBuilder: (context, action) {
                return AlbumDetailScreen(album: album);
              },
              closedColor: Theme.of(context).colorScheme.surfaceContainer,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              closedElevation: 4,
              closedBuilder: (context, action) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: UniversalImage(
                        uri: album.artUri,
                        fit: BoxFit.cover,
                        fallbackIcon: Symbols.album,
                        fallbackIconSize: 48,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.album,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            album.artist,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}


