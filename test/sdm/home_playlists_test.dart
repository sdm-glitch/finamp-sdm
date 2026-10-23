// SDM build (patch 0003-home-playlists): grid columns, collage sources and the collage widget.
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/sdm/home_playlists.dart';
import 'package:finamp/sdm/playlist_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BaseItemDto track(String id, String? albumId) =>
    BaseItemDto.fromJson({"Id": id, "Name": "Track $id", "Type": "Audio", if (albumId != null) "AlbumId": albumId});

void main() {
  test("grid: 2 columns on phones, more on wide screens", () {
    expect(sdmGridColumns(360), 2);
    expect(sdmGridColumns(599), 2);
    expect(sdmGridColumns(700), 3);
    expect(sdmGridColumns(1200), 4);
  });

  test("collage sources: first track of each distinct album, in order, max 4", () {
    final tracks = [
      track("1", "a"),
      track("2", "a"),
      track("3", "b"),
      track("4", null),
      track("5", "c"),
      track("6", "d"),
      track("7", "e"),
    ];
    expect(sdmCollageSources(tracks).map((t) => t.id.raw).toList(), ["1", "3", "4", "5"]);
    expect(sdmCollageSources(tracks.sublist(0, 2)).length, 1);
    expect(sdmCollageSources(const []), isEmpty);
  });

  testWidgets("collage: four tiles in a square 2x2 grid", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            child: SdmCollage(tiles: [for (var i = 0; i < 4; i++) ColoredBox(key: ValueKey(i), color: Colors.red)]),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SdmCollage)), const Size(200, 200));
    for (var i = 0; i < 4; i++) {
      expect(tester.getSize(find.byKey(ValueKey(i))), const Size(100, 100));
    }
    expect(tester.getTopLeft(find.byKey(const ValueKey(3))) - tester.getTopLeft(find.byKey(const ValueKey(0))),
        const Offset(100, 100));
  });
}
