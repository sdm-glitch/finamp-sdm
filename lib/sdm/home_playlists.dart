// SDM build (patch 0003-home-playlists): the home tab shows only the user's playlists, as a grid of
// Spotify-style cards (cover, name, download state + "Playlist"), the most recently played first (patch
// 0006). Albums, artists, genres etc. stay on their own tabs.
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/sdm/playlist_cover.dart';
import 'package:finamp/sdm/playlist_recent.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

/// The home tab is replaced by [SdmHomeContent].
const sdmPlaylistsOnlyHome = true;

const sdmGreen = Color(0xFF1ED760);

/// Columns of the playlist grid: 2 on phones, more on wide screens.
int sdmGridColumns(double width) => width >= 900 ? 4 : (width >= 600 ? 3 : 2);

/// All playlists of the user (online), or the downloaded ones (offline), by name (the grid then puts the
/// recently played ones first).
final sdmPlaylistsProvider = FutureProvider.autoDispose<List<BaseItemDto>>((ref) async {
  final offline = ref.watch(finampSettingsProvider.isOffline);
  List<BaseItemDto> items;
  if (offline) {
    final stubs = await GetIt.instance<DownloadsService>().getAllCollections(
      includeItemTypes: [BaseItemDtoType.playlist],
      fullyDownloaded: false,
      nullableViewFilters: true,
    );
    items = stubs.map((stub) => stub.baseItem).whereType<BaseItemDto>().toList();
  } else {
    items =
        await GetIt.instance<JellyfinApiHelper>().getItems(
          parentItem: null,
          includeItemTypes: ContentType.playlists.itemType?.jellyfinName,
          sortBy: "SortName",
          sortOrder: "Ascending",
          recursive: true,
        ) ??
        <BaseItemDto>[];
  }
  items.sort((a, b) => (a.name ?? "").toLowerCase().compareTo((b.name ?? "").toLowerCase()));
  return items;
});

class SdmHomeContent extends ConsumerWidget {
  const SdmHomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playedAt = ref.watch(sdmPlaylistPlayedProvider);
    final playlists = ref
        .watch(sdmPlaylistsProvider)
        .whenData((items) => sdmSortByLastPlayed(items, (playlist) => playlist.id.raw, playedAt));
    final offline = ref.watch(finampSettingsProvider.isOffline);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sdmPlaylistsProvider),
      child: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
            sliver: SliverToBoxAdapter(
              child: Text("Your playlists", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          ),
          playlists.when(
            data: (items) => items.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(offline ? "No downloaded playlists yet" : "No playlists yet")),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 14.0;
                        final columns = sdmGridColumns(constraints.crossAxisExtent);
                        final cardWidth = (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;
                        final textHeight = 58.0 * MediaQuery.textScalerOf(context).scale(1.0);
                        return SliverGrid.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: 16,
                            mainAxisExtent: cardWidth + textHeight,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              SdmPlaylistCard(key: ValueKey(items[index].id), playlist: items[index]),
                        );
                      },
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text("Could not load the playlists: $error", textAlign: TextAlign.center)),
              ),
            ),
          ),
          const SliverSafeArea(top: false, sliver: SliverPadding(padding: EdgeInsets.only(bottom: 120))),
        ],
      ),
    );
  }
}

class SdmPlaylistCard extends StatelessWidget {
  const SdmPlaylistCard({super.key, required this.playlist});

  final BaseItemDto playlist;

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).textTheme.bodySmall?.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: playlist),
        onLongPress: () => openItemMenu(context: context, item: playlist),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SdmPlaylistCover(playlist: playlist),
            const SizedBox(height: 8),
            Text(
              playlist.name ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                SdmDownloadDot(item: playlist),
                Flexible(
                  child: Text(
                    "Playlist",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: subtle),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Spotify-style download state of a collection: green dot when downloaded.
class SdmDownloadDot extends ConsumerWidget {
  const SdmDownloadDot({super.key, required this.item, this.size = 16});

  final BaseItemDto item;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stub = DownloadStub.fromItem(type: DownloadItemType.collection, item: item);
    final state = ref.watch(GetIt.instance<DownloadsService>().stateProvider(stub)).valueOrNull;
    final Widget? icon = switch (state) {
      DownloadItemState.complete ||
      DownloadItemState.needsRedownloadComplete => Icon(Icons.arrow_circle_down, size: size, color: sdmGreen),
      DownloadItemState.enqueued ||
      DownloadItemState.downloading ||
      DownloadItemState.needsRedownload => Icon(TablerIcons.cloud_download, size: size),
      DownloadItemState.failed ||
      DownloadItemState.syncFailed => Icon(TablerIcons.download_off, size: size, color: Colors.red),
      DownloadItemState.notDownloaded || null => null,
    };
    if (icon == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(right: 4), child: icon);
  }
}
