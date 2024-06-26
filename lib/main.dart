/// A fast and beautiful app to help convey emotion in text communication.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:helpers/helpers.dart';
import 'package:http/http.dart' as http;
import 'package:window_size/window_size.dart' as window_size;

import 'src/app.dart';
import 'src/app/app.dart';
import 'src/emoji/cubit/emoji_cubit.dart';
import 'src/emoji/emoji_service.dart';
import 'src/helpers/helpers.dart';
import 'src/helpers/window_watcher.dart';
import 'src/localization/strings.g.dart';
import 'src/logs/logging_manager.dart';
import 'src/settings/cubit/settings_cubit.dart';
import 'src/settings/settings_service.dart';
import 'src/shortcuts/app_hotkey.dart';
import 'src/storage/storage_service.dart';
import 'src/system_tray/system_tray.dart';
import 'src/updates/updates.dart';
import 'src/window/app_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initial configuration for the app locale.
  LocaleSettings.useDeviceLocale();

  final bool verbose = args.contains('-v') ||
      args.contains('--verbose') ||
      const String.fromEnvironment('VERBOSE') == 'true';

  await LoggingManager.initialize(verbose: verbose);
  await closeExistingSessions();

  final appWindow = await AppWindow.initialize();
  final systemTray = await SystemTray.initialize(appWindow);

  // Initialize the storage service.
  final storageService = StorageService();

  // Wait for the storage service to initialize while showing the splash screen.
  // This allows us to be certain settings are available right away,
  // and prevents unsightly things like the theme suddenly changing when loaded.
  await storageService.init();

  final emojiService = EmojiService();

  final appCubit = AppCubit(
    storageService,
    releaseNotesService: ReleaseNotesService(
      client: http.Client(),
      repository: 'merrit/feeling_finder',
    ),
    updateService: UpdateService(),
    windowEvents: appWindow?.events,
  );

  // Initialize the settings service.
  final settingsService = SettingsService(storageService);
  final settingsCubit = await SettingsCubit.init(
    settingsService,
    systemTray,
  );

  // Initialize Visibility Shortcut (Depends on Settings Service)
  if (platformIsLinuxX11()) hotKeyService.initHotkeyRegistration();

  // Run the app and pass in the state controllers.
  runApp(
    MultiRepositoryProvider(
      providers: [
        if (appWindow != null) RepositoryProvider.value(value: appWindow),
        RepositoryProvider.value(value: settingsService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: appCubit),
          BlocProvider(
            create: (context) => EmojiCubit(
              appWindow,
              emojiService,
              settingsCubit,
              settingsService,
              storageService,
            ),
            lazy: false,
          ),
          BlocProvider.value(value: settingsCubit),
        ],
        child: WindowWatcher(
          onClose: () {
            if (platformIsMobile()) {
              return;
            }
            exit(0);
          },
          child: TranslationProvider(child: const App()),
        ),
      ),
    ),
  );

  /// Now that the app has been initialized fully we show the window.
  ///
  /// This is where, before showing the window we could do things like
  /// taking launch arguments to set a custom size / position / etc of
  /// the window before showing it, allowing the picker to appear
  /// in any custom manner desired.
  if (platformIsDesktop()) {
    // Skip on non-desktop platforms as they have no windows to manage.
    window_size.setWindowVisibility(visible: true);
  }
}
