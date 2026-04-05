import 'dart:io' show Platform;

/// Returns true on iOS and Android only.
bool get isIOSOrAndroid => Platform.isIOS || Platform.isAndroid;
