// SDM build (patch 0006-ui-tweaks): playlists ordered by last played, swipe right = add to queue,
// no track-row heart, no mini-player heart, nothing that deletes on the server.
import 'dart:io';

import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/sdm/playlist_recent.dart';
import 'package:finamp/sdm/sdm_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String idOf(String item) => item;

String readSource(String path) => File(path).readAsStringSync();

void main() {
  group("playlists: last played first", () {
    test("played ones first (newest first), the rest keep their order", () {
      final playlists = ["a", "b", "c", "d", "e"];
      expect(sdmSortByLastPlayed(playlists, idOf, {"d": 10, "b": 20}), ["b", "d", "a", "c", "e"]);
    });

    test("nothing played: same order", () {
      final playlists = ["a", "b", "c"];
      expect(sdmSortByLastPlayed(playlists, idOf, const {}), playlists);
      expect(sdmSortByLastPlayed(playlists, idOf, {"zzz": 5}), playlists);
    });

    test("same time: original order", () {
      expect(sdmSortByLastPlayed(["a", "b", "c"], idOf, {"c": 7, "b": 7}), ["b", "c", "a"]);
    });

    test("pages keep their sizes", () {
      final pages = [
        ["a", "b", "c"],
        ["d", "e"],
      ];
      expect(sdmSortPagesByLastPlayed(pages, idOf, {"e": 2, "d": 1}), [
        ["e", "d", "a"],
        ["b", "c"],
      ]);
      expect(sdmSortPagesByLastPlayed(<List<String>>[], idOf, {"e": 2}), isEmpty);
    });

    test("stored times: unreadable data counts as nothing played", () {
      expect(SdmPrefs.decodePlayedAt(null), isEmpty);
      expect(SdmPrefs.decodePlayedAt("not json"), isEmpty);
      expect(SdmPrefs.decodePlayedAt("[1,2]"), isEmpty);
      expect(SdmPrefs.decodePlayedAt('{"a":5,"b":9}'), {"a": 5, "b": 9});
    });

    test("marking a playlist played is remembered", () async {
      SharedPreferences.setMockInitialValues({"sdm.playlistPlayedAt": '{"old":1}'});
      final prefs = SdmPrefs.instance;
      await prefs.markPlaylistPlayed("new", now: DateTime.fromMillisecondsSinceEpoch(5000));
      expect(prefs.playlistPlayedAt.value, {"old": 1, "new": 5000});
      expect((await SharedPreferences.getInstance()).getString("sdm.playlistPlayedAt"), '{"old":1,"new":5000}');
    });
  });

  test("track rows: swipe right adds to the queue, no heart button", () {
    expect(sdmSwipeRightAction, ItemSwipeActions.addToQueue);
    expect(TrackListItemFeatures.values.map((feature) => feature.name), contains("swipeRightAddsToQueue"));
    expect(TrackListItemFeatures.values.map((feature) => feature.name), isNot(contains("addToPlaylistOrFavorite")));
    expect(readSource("lib/components/AlbumScreen/track_list_tile.dart"), isNot(contains("AddToPlaylistButton")));
  });

  test("mini player has no favorite button (the now playing screen keeps it)", () {
    expect(readSource("lib/components/now_playing_bar.dart"), isNot(contains("FavoriteButton")));
    expect(readSource("lib/sdm/player_ui.dart"), contains("FavoriteButton("));
  });

  test("nothing in the app deletes items on the server", () {
    final files = Directory("lib").listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith(".dart"));
    const forbidden = ["deleteItem(", "DeleteFromServerMenuEntry", "askBeforeDeleteFromServer", "canDeleteFromServer"];
    for (final file in files) {
      final text = file.readAsStringSync();
      for (final word in forbidden) {
        expect(text, isNot(contains(word)), reason: "${file.path} still has $word");
      }
    }
  });

  test("playlist three dots open the playlist menu directly", () {
    final page = readSource("lib/sdm/playlist_page.dart");
    expect(page, contains("openItemMenu(context: context, item: playlist)"));
    expect(page, isNot(contains("_showMenu")));
    expect(readSource("lib/menus/playlist_menu.dart"), contains("SdmEditCoverMenuEntry(baseItem: item)"));
  });
}
