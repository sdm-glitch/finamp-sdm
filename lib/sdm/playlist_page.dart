// SDM build (patch 0004-playlist-page): Spotify-style playlist page - big cover, title, songs + total
// duration, download/share on the left, shuffle toggle + big Play on the right, Add/Edit chips, the
// playlist menu behind the three dots (patch 0006), a "Find in playlist" field that sits above the top
// until pulled down, and the track rows.
import 'dart:math';

import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/screens/playlist_edit_screen.dart';
import 'package:finamp/sdm/home_playlists.dart';
import 'package:finamp/sdm/playlist_cover.dart';
import 'package:finamp/services/album_screen_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

/// Height of the hidden "Find in playlist" row; the page starts scrolled by this much.
const sdmFindHeight = 64.0;

/// Tracks whose title, artists or album contain [query] (case-insensitive); all tracks for an empty query.
List<BaseItemDto> sdmFilterTracks(List<BaseItemDto> tracks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return tracks;
  return tracks.where((track) {
    final text = [track.name, track.album, ...?track.artists].whereType<String>().join(" ").toLowerCase();
    return text.contains(q);
  }).toList();
}

/// "10h 53min" / "42min".
String sdmTotalDuration(List<BaseItemDto> tracks) {
  final total = tracks
      .map((track) => track.runTimeTicksDuration())
      .whereType<Duration>()
      .fold<Duration>(Duration.zero, (sum, d) => sum + d);
  final hours = total.inHours;
  return hours > 0 ? "${hours}h ${total.inMinutes % 60}min" : "${total.inMinutes}min";
}

class SdmPlaylistPage extends ConsumerStatefulWidget {
  const SdmPlaylistPage({super.key, required this.playlist});

  final BaseItemDto playlist;

  @override
  ConsumerState<SdmPlaylistPage> createState() => _SdmPlaylistPageState();
}

class _SdmPlaylistPageState extends ConsumerState<SdmPlaylistPage> {
  final _scroll = ScrollController(initialScrollOffset: sdmFindHeight);
  final _find = TextEditingController();
  String _query = "";
  bool _shuffle = false;

  BaseItemDto get playlist => widget.playlist;

  @override
  void dispose() {
    _scroll.dispose();
    _find.dispose();
    super.dispose();
  }

  /// Shuffle off: from the first track. Shuffle on: shuffled, starting with a random track.
  Future<void> _play(List<BaseItemDto> tracks) async {
    if (tracks.isEmpty) return;
    await GetIt.instance<QueueService>().startPlayback(
      items: tracks,
      source: QueueItemSource.fromBaseItem(playlist),
      order: _shuffle ? FinampPlaybackOrder.shuffled : FinampPlaybackOrder.linear,
      startingIndex: _shuffle ? Random().nextInt(tracks.length) : 0,
    );
  }

  void _openEdit() => Navigator.pushNamed(context, PlaylistEditScreen.routeName, arguments: playlist);

  Future<void> _showAdd() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SdmAddTracksSheet(playlist: playlist),
    );
    ref.invalidate(getAlbumOrPlaylistTracksProvider(playlist));
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(getAlbumOrPlaylistTracksProvider(playlist)).valueOrNull;
    final List<BaseItemDto>? all = tracks?.$1;
    final List<BaseItemDto> playable = tracks?.$2 ?? const <BaseItemDto>[];
    final shown = sdmFilterTracks(all ?? const <BaseItemDto>[], _query);
    final offline = ref.watch(finampSettingsProvider.isOffline);
    final canEdit = !offline && ref.watch(canEditPlaylistProvider(playlist));
    final size = MediaQuery.sizeOf(context);
    final subtle = Theme.of(context).textTheme.bodySmall?.color;

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverAppBar(
          pinned: true,
          leading: FinampAppBarBackButton(),
          actions: [
            IconButton(
              tooltip: "More",
              icon: const Icon(TablerIcons.dots_vertical),
              onPressed: () => openItemMenu(context: context, item: playlist),
            ),
          ],
        ),
        // pulled into view by scrolling up past the top
        SliverToBoxAdapter(
          child: SizedBox(
            height: sdmFindHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _find,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "Find in playlist",
                  prefixIcon: const Icon(TablerIcons.search),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(TablerIcons.x),
                          onPressed: () {
                            _find.clear();
                            setState(() => _query = "");
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: SizedBox(
              width: min(size.width * 0.62, 340),
              child: SdmPlaylistCover(playlist: playlist, radius: 6),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
                ),
                const SizedBox(height: 6),
                Text(
                  all == null ? "..." : "${all.length} songs · ${sdmTotalDuration(all)}",
                  style: TextStyle(fontSize: 14, color: subtle),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                if (all != null)
                  DownloadButton(
                    item: DownloadStub.fromItem(type: DownloadItemType.collection, item: playlist),
                    children: all,
                  ),
                IconButton(
                  tooltip: "Share",
                  icon: const Icon(TablerIcons.share),
                  // ignore: deprecated_member_use
                  onPressed: () => Share.share(playlist.name ?? ""),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _shuffle ? "Shuffle: on" : "Shuffle: off",
                  icon: Icon(TablerIcons.arrows_shuffle, color: _shuffle ? sdmGreen : null),
                  onPressed: () => setState(() => _shuffle = !_shuffle),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: sdmGreen,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: playable.isEmpty ? null : () => _play(playable),
                    child: const Icon(TablerIcons.player_play_filled, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (canEdit)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(TablerIcons.plus, size: 18),
                    label: const Text("Add"),
                    shape: const StadiumBorder(),
                    onPressed: _showAdd,
                  ),
                  ActionChip(
                    avatar: const Icon(TablerIcons.list, size: 18),
                    label: const Text("Edit"),
                    shape: const StadiumBorder(),
                    onPressed: _openEdit,
                  ),
                ],
              ),
            ),
          ),
        if (all == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          )
        else
          SliverFixedExtentList(
            itemExtent: TrackListItemTile.defaultTileHeight + TrackListItemTile.defaultTitleGap,
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = shown[index];
              return TrackListTile(
                key: ValueKey(item.id),
                item: item,
                index: playable.indexWhere((track) => track.id == item.id),
                showIndex: false,
                showCover: true,
                parentItem: playlist,
                parentPlayable: PrecalculatedPlayable(source: QueueItemSource.fromBaseItem(playlist), tracks: playable),
              );
            }, childCount: shown.length),
          ),
        // room for the mini player, and enough height that the find field can stay scrolled away
        SliverToBoxAdapter(child: SizedBox(height: max(160.0, size.height * 0.6))),
      ],
    );
  }
}

/// "+ Add": search the library and add tracks to [playlist].
class SdmAddTracksSheet extends StatefulWidget {
  const SdmAddTracksSheet({super.key, required this.playlist});

  final BaseItemDto playlist;

  @override
  State<SdmAddTracksSheet> createState() => _SdmAddTracksSheetState();
}

class _SdmAddTracksSheetState extends State<SdmAddTracksSheet> {
  final _api = GetIt.instance<JellyfinApiHelper>();
  final _added = <String>{};
  List<BaseItemDto> _results = const [];
  bool _searching = false;
  String? _error;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _api.getItems(
        parentItem: null,
        includeItemTypes: ContentType.tracks.itemType?.jellyfinName,
        searchTerm: query.trim(),
        recursive: true,
        startIndex: 0,
        limit: 40,
      );
      if (mounted) setState(() => _results = results ?? const []);
    } catch (e) {
      if (mounted) setState(() => _error = "$e");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(BaseItemDto track) async {
    try {
      await _api.addItemstoPlaylist(playlistId: widget.playlist.id, ids: [track.id]);
      if (mounted) setState(() => _added.add(track.id.raw));
    } catch (e) {
      if (mounted) setState(() => _error = "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: "Search songs to add to ${widget.playlist.name ?? "the playlist"}",
                  prefixIcon: const Icon(TablerIcons.search),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final track = _results[index];
                  final added = _added.contains(track.id.raw);
                  return ListTile(
                    title: Text(track.name ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      (track.artists ?? const <String>[]).join(", "),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subtle),
                    ),
                    trailing: added
                        ? const Icon(Icons.check_circle, color: sdmGreen)
                        : IconButton(icon: const Icon(TablerIcons.circle_plus), onPressed: () => _add(track)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
