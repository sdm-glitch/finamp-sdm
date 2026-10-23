// SDM build: personal settings that are not part of Finamp's Hive settings model
// (patch 0002-flipcard-lyrics). Stored with shared_preferences, loaded once at first use.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SdmPrefs {
  SdmPrefs._();

  static final SdmPrefs instance = SdmPrefs._();

  static const defaultFlipCardEnabled = true;
  static const defaultCardLyricsFontSize = 24.0;
  static const minCardLyricsFontSize = 14.0;
  static const maxCardLyricsFontSize = 44.0;

  static const _kFlipCardEnabled = "sdm.flipCardEnabled";
  static const _kCardLyricsFontSize = "sdm.cardLyricsFontSize";
  static const _kPlaylistPlayedAt = "sdm.playlistPlayedAt";

  /// Tapping the cover on the player screen turns it over to show the lyrics.
  final ValueNotifier<bool> flipCardEnabled = ValueNotifier(defaultFlipCardEnabled);

  /// Font size of the lyrics on the back of the player card.
  final ValueNotifier<double> cardLyricsFontSize = ValueNotifier(defaultCardLyricsFontSize);

  /// Whether the player card currently shows its lyrics side (kept across tracks and screens).
  final ValueNotifier<bool> cardFlipped = ValueNotifier(false);

  /// Playlist id -> when it was last played (ms since epoch), for ordering playlists (patch 0006).
  /// Kept on this device, so it also works offline.
  final ValueNotifier<Map<String, int>> playlistPlayedAt = ValueNotifier(const {});

  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      flipCardEnabled.value = prefs.getBool(_kFlipCardEnabled) ?? defaultFlipCardEnabled;
      cardLyricsFontSize.value = _clampFontSize(prefs.getDouble(_kCardLyricsFontSize) ?? defaultCardLyricsFontSize);
      playlistPlayedAt.value = decodePlayedAt(prefs.getString(_kPlaylistPlayedAt));
    } catch (_) {
      // keep the defaults
    }
  }

  Future<void> setFlipCardEnabled(bool value) async {
    flipCardEnabled.value = value;
    if (!value) {
      cardFlipped.value = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFlipCardEnabled, value);
  }

  Future<void> setCardLyricsFontSize(double value) async {
    cardLyricsFontSize.value = _clampFontSize(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCardLyricsFontSize, cardLyricsFontSize.value);
  }

  /// Remembers that [playlistId] was played now.
  Future<void> markPlaylistPlayed(String playlistId, {DateTime? now}) async {
    await ensureLoaded();
    playlistPlayedAt.value = {...playlistPlayedAt.value, playlistId: (now ?? DateTime.now()).millisecondsSinceEpoch};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPlaylistPlayedAt, jsonEncode(playlistPlayedAt.value));
    } catch (_) {
      // still ordered correctly until the app is closed
    }
  }

  /// Reads the stored JSON map; anything unreadable counts as "nothing played yet".
  static Map<String, int> decodePlayedAt(String? json) {
    if (json == null) return const {};
    try {
      return {for (final entry in (jsonDecode(json) as Map<String, dynamic>).entries) entry.key: entry.value as int};
    } catch (_) {
      return const {};
    }
  }

  void toggleCard() {
    cardFlipped.value = !cardFlipped.value;
  }

  static double _clampFontSize(double value) =>
      value.clamp(minCardLyricsFontSize, maxCardLyricsFontSize).toDouble();
}
