// SDM build (patch 0006-ui-tweaks): "Edit cover" entry of the playlist menu - pick an image on this
// device and set it as the playlist's cover (the menu is also what the playlist page's three dots open).
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/sdm/home_playlists.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/permission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

/// Lets the user pick an image on this device and uploads it as [playlist]'s cover.
Future<void> sdmChangePlaylistCover(BaseItemDto playlist) async {
  final result = await FilePicker.pickFiles(type: FileType.image);
  final path = result?.files.single.path;
  if (path == null) return;
  try {
    await GetIt.instance<JellyfinApiHelper>().setItemPrimaryImage(itemId: playlist.id, imageFile: File(path));
    GetIt.instance<ProviderContainer>().invalidate(sdmPlaylistsProvider);
    GlobalSnackbar.message((_) => "Cover updated - it shows after the next refresh");
  } catch (e) {
    GlobalSnackbar.message((_) => "Could not change the cover: $e");
  }
}

class SdmEditCoverMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const SdmEditCoverMenuEntry({super.key, required this.baseItem});

  bool get _isPlaylist => BaseItemDtoType.fromItem(baseItem) == BaseItemDtoType.playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Visibility(
      visible: _isPlaylist && !ref.watch(finampSettingsProvider.isOffline),
      child: MenuEntry(
        enabled: _isPlaylist && ref.watch(canEditPlaylistProvider(baseItem)),
        icon: TablerIcons.photo,
        title: "Edit cover",
        onTap: () {
          Navigator.pop(context); // close menu
          unawaited(sdmChangePlaylistCover(baseItem));
        },
      ),
    );
  }

  @override
  bool get isVisible => !FinampSettingsHelper.finampSettings.isOffline && _isPlaylist;
}
