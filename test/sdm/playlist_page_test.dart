// SDM build (patch 0004-playlist-page): find-in-playlist filter and total duration.
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/sdm/playlist_page.dart';
import 'package:flutter_test/flutter_test.dart';

BaseItemDto track(String id, String name, List<String> artists, {String? album, int seconds = 0}) =>
    BaseItemDto.fromJson({
      "Id": id,
      "Name": name,
      "Type": "Audio",
      "Artists": artists,
      if (album != null) "Album": album,
      "RunTimeTicks": seconds * 10000000,
    });

void main() {
  final tracks = [
    track("1", "Surrender the Night", ["My Chemical Romance"], album: "The Black Parade", seconds: 3600),
    track("2", "Burn Bright", ["My Chemical Romance"], seconds: 2 * 3600),
    track("3", "Numb", ["Linkin Park"], album: "Meteora", seconds: 53 * 60),
  ];

  test("find in playlist: title, artist or album, case-insensitive", () {
    expect(sdmFilterTracks(tracks, "").length, 3);
    expect(sdmFilterTracks(tracks, "  ").length, 3);
    expect(sdmFilterTracks(tracks, "numb").map((t) => t.id.raw), ["3"]);
    expect(sdmFilterTracks(tracks, "chemical").length, 2);
    expect(sdmFilterTracks(tracks, "PARADE").map((t) => t.id.raw), ["1"]);
    expect(sdmFilterTracks(tracks, "zzz"), isEmpty);
  });

  test("total duration like Spotify", () {
    expect(sdmTotalDuration(tracks), "3h 53min");
    expect(sdmTotalDuration([tracks[2]]), "53min");
    expect(sdmTotalDuration(const []), "0min");
  });
}
