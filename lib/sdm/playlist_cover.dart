// SDM build (patch 0003-home-playlists): a playlist's cover is its own image, or else a 2x2 collage of
// the covers of its first four distinct albums (like Spotify's mix tiles).
import 'package:finamp/components/album_image.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One track per distinct album, in playlist order, at most [max].
List<BaseItemDto> sdmCollageSources(List<BaseItemDto> tracks, {int max = 4}) {
  final seen = <String>{};
  final out = <BaseItemDto>[];
  for (final track in tracks) {
    final key = track.albumId?.raw ?? track.id.raw;
    if (seen.add(key)) {
      out.add(track);
      if (out.length == max) break;
    }
  }
  return out;
}

/// Square 2x2 grid of exactly four tiles.
class SdmCollage extends StatelessWidget {
  const SdmCollage({super.key, required this.tiles}) : assert(tiles.length == 4);

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    Widget row(int first) => Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: tiles[first]), Expanded(child: tiles[first + 1])],
      ),
    );
    return AspectRatio(
      aspectRatio: 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [row(0), row(2)]),
    );
  }
}

class SdmPlaylistCover extends ConsumerWidget {
  const SdmPlaylistCover({super.key, required this.playlist, this.radius = 8.0});

  final BaseItemDto playlist;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = BorderRadius.circular(radius);
    if (playlist.hasOwnImage) {
      return AspectRatio(aspectRatio: 1, child: AlbumImage(item: playlist, borderRadius: borderRadius));
    }
    final tracks = ref.watch(getAlbumOrPlaylistTracksProvider(playlist)).valueOrNull?.$1 ?? const <BaseItemDto>[];
    final sources = sdmCollageSources(tracks);
    if (sources.length < 4) {
      return AspectRatio(
        aspectRatio: 1,
        child: AlbumImage(item: sources.isNotEmpty ? sources.first : playlist, borderRadius: borderRadius),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SdmCollage(
        tiles: [for (final source in sources) AlbumImage(item: source, borderRadius: BorderRadius.zero)],
      ),
    );
  }
}
