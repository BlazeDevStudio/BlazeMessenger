import 'package:flutter/material.dart';

/// Source: BlazeDevStudio/BlazeWeb at 7ce8f71456737f84df38bbef31a36e9eb8b792fd.
/// The exact verified v3 SVG is bundled in assets/branding/blazedevstudio-v3.
abstract final class BlazeIdentity {
  static const String markAsset =
      'assets/branding/blazedevstudio-v3/main-hud-transparent.svg';
  /// App-specific mark; the official parent markAsset remains unchanged.
  static const String lanMarkAsset =
      'assets/branding/blazedevstudio-v3/lan-messenger-mark-transparent.svg';
  static const String lanNativeMarkAsset =
      'assets/branding/blazedevstudio-v3/lan-messenger-mark.svg';
  static const String lanCompactMarkAsset =
      'assets/branding/blazedevstudio-v3/lan-messenger-mark-compact.svg';
  static const String networkAsset =
      'assets/branding/blazedevstudio-v3/sublogo-network.svg';
  static const Color navy = Color(0xFF0B1427);
  static const Color blue = Color(0xFF1387FE);
  static const Color ruby = Color(0xFFFA2E58);
}
