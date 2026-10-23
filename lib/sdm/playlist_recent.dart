// SDM build (patch 0006-ui-tweaks): playlists played most recently come first (home grid and the
// library's Playlists tab). Jellyfin does not reliably record "last played" for playlists, so the app
// remembers it itself (see SdmPrefs.playlistPlayedAt).
import 'dart:async';

import 'package:finamp/sdm/sdm_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Playlist id -> last played time (ms since epoch); changes whenever a playlist is played.
final sdmPlaylistPlayedProvider = Provider<Map<String, int>>((ref) {
  final prefs = SdmPrefs.instance;
  void onChange() => ref.invalidateSelf();
  prefs.playlistPlayedAt.addListener(onChange);
  ref.onDispose(() => prefs.playlistPlayedAt.removeListener(onChange));
  unawaited(prefs.ensureLoaded());
  return prefs.playlistPlayedAt.value;
});

/// Items that were played first, most recent first; all others after them in their original order.
List<T> sdmSortByLastPlayed<T>(List<T> items, String Function(T item) idOf, Map<String, int> playedAt) {
  if (playedAt.isEmpty) return items;
  final played = [
    for (final (index, item) in items.indexed)
      if (playedAt.containsKey(idOf(item))) (index, item),
  ];
  // List.sort is not stable, so equal times keep their original order through the index
  played.sort((a, b) {
    final byTime = playedAt[idOf(b.$2)]!.compareTo(playedAt[idOf(a.$2)]!);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [...played.map((entry) => entry.$2), ...items.where((item) => !playedAt.containsKey(idOf(item)))];
}

/// [sdmSortByLastPlayed] over everything loaded so far, split into pages of the same sizes again.
List<List<T>> sdmSortPagesByLastPlayed<T>(
  List<List<T>> pages,
  String Function(T item) idOf,
  Map<String, int> playedAt,
) {
  final sorted = sdmSortByLastPlayed([for (final page in pages) ...page], idOf, playedAt);
  final result = <List<T>>[];
  var start = 0;
  for (final page in pages) {
    result.add(sorted.sublist(start, start + page.length));
    start += page.length;
  }
  return result;
}
