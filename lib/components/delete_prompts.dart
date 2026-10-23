import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

Future<void> askBeforeDeleteDownloadFromDevice(BuildContext context, DownloadStub stub, {VoidCallback? refresh}) async {
  String type = stub.baseItemType.name;
  await showDialog(
    context: context,
    builder: (context) => ConfirmationPromptDialog(
      promptText: AppLocalizations.of(context)!.deleteFromTargetDialogText("", "device", type),
      confirmButtonText: AppLocalizations.of(context)!.deleteFromTargetConfirmButton("device"),
      onConfirmed: () async {
        try {
          await GetIt.instance<DownloadsService>().deleteDownload(stub: stub);
          GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.itemDeletedSnackbar("device", type));

          if (context.mounted && FinampSettingsHelper.finampSettings.isOffline) {
            Navigator.of(context).popUntil((route) {
              return route.settings.name !=
                      null // unnamed dialog
                      &&
                  route.settings.name != AlbumScreen.routeName; // albums screen
            });
          }
        } catch (err) {
          GlobalSnackbar.error(err);
        } finally {
          refresh != null ? refresh() : null;
        }
      },
      centerText: true,
    ),
  );
}
