import 'package:finamp/components/AlbumScreen/album_screen_content.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/sdm/playlist_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, this.parent, this.genreFilter});

  static const routeName = "/music/album";

  /// The album to show. Can also be provided as an argument in a named route
  final BaseItemDto? parent;

  // The genreFilter to apply
  final BaseItemDto? genreFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BaseItemDto resolvedParent = parent ?? ModalRoute.settingsOf(context)!.arguments as BaseItemDto;

    return Scaffold(
      extendBody: true,
      // SDM (0004): playlists get the Spotify-style page
      body: BaseItemDtoType.fromItem(resolvedParent) == BaseItemDtoType.playlist && genreFilter == null
          ? SdmPlaylistPage(playlist: resolvedParent)
          : AlbumScreenContent(parent: resolvedParent, genreFilter: genreFilter),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}
