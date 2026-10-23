// SDM build (patch 0002-flipcard-lyrics): the player screen's cover as a flip card with the synced
// lyrics on its back, plus the share button and the settings tiles for it.
import 'dart:math';

import 'package:finamp/components/PlayerScreen/player_screen_album_image.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/sdm/flip_card.dart';
import 'package:finamp/sdm/sdm_prefs.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

/// Lyrics font size for [LyricsView] lines below this widget (used on the card's back).
class SdmLyricsFontScope extends InheritedWidget {
  const SdmLyricsFontScope({super.key, required this.fontSize, required super.child});

  final double fontSize;

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SdmLyricsFontScope>()?.fontSize;

  @override
  bool updateShouldNotify(SdmLyricsFontScope oldWidget) => oldWidget.fontSize != fontSize;
}

/// Cover on the front, synced lyrics on the back; a tap turns it over.
/// With the flip card switched off in the settings it is the plain upstream cover.
class SdmPlayerCard extends StatefulWidget {
  const SdmPlayerCard({super.key});

  @override
  State<SdmPlayerCard> createState() => _SdmPlayerCardState();
}

class _SdmPlayerCardState extends State<SdmPlayerCard> {
  final prefs = SdmPrefs.instance;

  @override
  void initState() {
    super.initState();
    prefs.ensureLoaded();
  }

  void _toggle() {
    prefs.toggleCard();
    FeedbackHelper.feedback(FeedbackType.selection);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: prefs.flipCardEnabled,
      builder: (context, enabled, _) {
        if (!enabled) {
          return const PlayerScreenAlbumImage();
        }
        return SdmFlipCard(
          flipped: prefs.cardFlipped,
          front: PlayerScreenAlbumImage(onTap: _toggle),
          back: SdmCardLyrics(onFlipBack: _toggle),
        );
      },
    );
  }
}

/// Back of the player card: the same square as the cover, filled with [LyricsView].
class SdmCardLyrics extends ConsumerWidget {
  const SdmCardLyrics({super.key, required this.onFlipBack});

  final VoidCallback onFlipBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minPadding = ref.watch(finampSettingsProvider.playerScreenCoverMinimumPadding);
        final horizontalPadding = constraints.maxWidth * (minPadding / 100.0);
        final verticalPadding = constraints.maxHeight * (minPadding / 100.0);
        final side = max(
          0.0,
          min(constraints.maxWidth - 2 * horizontalPadding, constraints.maxHeight - 2 * verticalPadding),
        );
        final colorScheme = Theme.of(context).colorScheme;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onFlipBack,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(blurRadius: 24, offset: const Offset(0, 4), color: Colors.black.withValues(alpha: 0.3)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ValueListenableBuilder<double>(
                          valueListenable: SdmPrefs.instance.cardLyricsFontSize,
                          builder: (context, fontSize, _) => SdmLyricsFontScope(
                            fontSize: fontSize,
                            child: const LyricsView(inCard: true),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton(
                          tooltip: "Show the cover",
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(TablerIcons.photo),
                          onPressed: onFlipBack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// App-bar button: share "Title — Artists" of the current track.
class SdmShareButton extends StatelessWidget {
  const SdmShareButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Share",
      icon: const Icon(TablerIcons.share),
      onPressed: () async {
        final item = GetIt.instance<QueueService>().getCurrentTrack()?.baseItem;
        if (item == null) return;
        final parts = [item.name, (item.artists ?? const <String>[]).join(", ")]
            .whereType<String>()
            .where((s) => s.isNotEmpty);
        if (parts.isEmpty) return;
        // ignore: deprecated_member_use
        await Share.share(parts.join(" — "));
      },
    );
  }
}

/// Settings tiles (Settings → Player screen) for the flip card.
class SdmCardSettingsTiles extends StatefulWidget {
  const SdmCardSettingsTiles({super.key});

  @override
  State<SdmCardSettingsTiles> createState() => _SdmCardSettingsTilesState();
}

class _SdmCardSettingsTilesState extends State<SdmCardSettingsTiles> {
  final prefs = SdmPrefs.instance;

  @override
  void initState() {
    super.initState();
    prefs.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: prefs.flipCardEnabled,
          builder: (context, enabled, _) => SwitchListTile.adaptive(
            title: const Text("Flip card with lyrics"),
            subtitle: const Text("Tap the cover on the player screen to turn it over and read the synced lyrics"),
            value: enabled,
            onChanged: prefs.setFlipCardEnabled,
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: prefs.cardLyricsFontSize,
          builder: (context, fontSize, _) => ListTile(
            title: Text("Lyrics text size on the card: ${fontSize.round()}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  min: SdmPrefs.minCardLyricsFontSize,
                  max: SdmPrefs.maxCardLyricsFontSize,
                  divisions: (SdmPrefs.maxCardLyricsFontSize - SdmPrefs.minCardLyricsFontSize).round(),
                  value: fontSize,
                  label: fontSize.round().toString(),
                  onChanged: prefs.setCardLyricsFontSize,
                ),
                const Text("Card size: \"minimum cover padding\" below (less padding = bigger card)"),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
