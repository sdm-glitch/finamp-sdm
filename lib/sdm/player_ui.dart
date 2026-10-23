// SDM build (patch 0005-player-ui): Spotify-like player pieces - title row (title, artist, favorite),
// one bottom row (share + queue), the "more" menu in the app bar, and the mini player's thin progress line.
import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_more.dart';
import 'package:finamp/components/PlayerScreen/queue_button.dart';
import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/process_artist.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

/// The mini player shows progress as a thin line instead of filling its background.
const sdmMiniProgressFill = false;

/// position / duration, clamped to 0..1 (0 when the duration is unknown).
double sdmProgressFraction(Duration? position, Duration? duration) {
  if (position == null || duration == null || duration.inMilliseconds <= 0) return 0;
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0).toDouble();
}

/// Title, artist and the favorite check, left-aligned like Spotify.
class SdmTrackTitleRow extends ConsumerWidget {
  const SdmTrackTitleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(QueueService.queueProvider)?.currentTrack;
    if (track == null) return const SizedBox.shrink();
    final subtle = Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  processArtist(track.item.artist, context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: subtle),
                ),
              ],
            ),
          ),
          FavoriteButton(item: track.baseItem, inPlayer: true, size: 28),
        ],
      ),
    );
  }
}

/// The player's only bottom row: share + queue.
class SdmPlayerBottomRow extends StatelessWidget {
  const SdmPlayerBottomRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: "Share",
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 27),
            style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            icon: const Icon(TablerIcons.share, size: 22),
            onPressed: () async {
              final item = GetIt.instance<QueueService>().getCurrentTrack()?.baseItem;
              if (item == null) return;
              final parts = [item.name, (item.artists ?? const <String>[]).join(", ")]
                  .whereType<String>()
                  .where((s) => s.isNotEmpty);
              // ignore: deprecated_member_use
              if (parts.isNotEmpty) await Share.share(parts.join(" — "));
            },
          ),
          const SizedBox(width: 8),
          const Flexible(child: QueueButton()),
        ],
      ),
    );
  }
}

/// The track menu (edit/add to playlist/...) in the player's app bar.
class SdmPlayerMoreButton extends ConsumerWidget {
  const SdmPlayerMoreButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(QueueService.queueProvider)?.currentTrack;
    if (track == null) return const SizedBox.shrink();
    return PlayerButtonsMore(item: track.baseItem, queueItem: track);
  }
}

/// Mini player: [child] with a thin progress line along its bottom edge.
class SdmMiniProgressOverlay extends StatelessWidget {
  const SdmMiniProgressOverlay({super.key, required this.currentTrack, required this.child});

  final FinampQueueItem currentTrack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    final color = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;
    return Stack(
      children: [
        child,
        Positioned(
          left: 10,
          right: 10,
          bottom: 0,
          child: StreamBuilder<Duration>(
            stream: AudioService.position,
            initialData: audioHandler.playbackState.value.position,
            builder: (context, snapshot) => LinearProgressIndicator(
              value: sdmProgressFraction(snapshot.data, currentTrack.item.duration),
              minHeight: 2,
              borderRadius: BorderRadius.circular(1),
              color: color,
              backgroundColor: color.withValues(alpha: 0.25),
            ),
          ),
        ),
      ],
    );
  }
}
