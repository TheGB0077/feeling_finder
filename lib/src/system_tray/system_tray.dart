import 'package:flutter/foundation.dart';
import 'package:helpers/helpers.dart';
import 'package:tray_manager/tray_manager.dart';

import '../core/core.dart';
import '../logs/logging_manager.dart';
import '../window/app_window.dart';

/// Manages the system tray icon.
class SystemTray {
  const SystemTray._();

  static Future<SystemTray?> initialize(AppWindow? appWindow) async {
    if (appWindow == null) return null;
    if (!defaultTargetPlatform.isDesktop) return null;

    final Menu menu = Menu(
      items: [
        MenuItem(label: 'Show', onClick: (menuItem) => appWindow.show()),
        MenuItem(label: 'Hide', onClick: (menuItem) => appWindow.hide()),
        MenuItem(label: 'Exit', onClick: (menuItem) => appWindow.close()),
      ],
    );

    await trayManager.setContextMenu(menu);

    return const SystemTray._();
  }

  /// Removes the system tray icon.
  Future<void> remove() async {
    await trayManager.destroy();
  }

  /// Shows the system tray icon.
  Future<void> show() async {
    final String iconPath;

    if (runningInFlatpak() || runningInSnap()) {
      // When running in Flatpak the icon must be specified by the icon's name, not the path.
      iconPath = kPackageId;
    } else {
      iconPath = (defaultTargetPlatform.isWindows) //
          ? AppIcons.windows
          : AppIcons.linux;
    }

    log.t('Setting system tray icon to $iconPath');
    await trayManager.setIcon(iconPath);
  }
}
