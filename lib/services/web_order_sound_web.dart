// Web-only implementation - plays sound via HTML5 Audio.
// Uses conditional import: only loaded when dart.library.html is available.
// Sound file: web/sounds/new_order.mp3 (served at /sounds/new_order.mp3)

import 'dart:html' as html;

/// Path to notification sound (served from web/sounds/ in build)
const String _soundPath = 'sounds/new_order.mp3';

/// Plays a short sound when a new paid order appears.
/// Only used on web - stub is used on iOS/Android.
void playNewPaidOrderSound() {
  try {
    final audio = html.AudioElement()
      ..src = _soundPath
      ..volume = 0.7;
    audio.play();
  } catch (_) {
    // Ignore playback errors (e.g. user interaction required in some browsers)
  }
}
