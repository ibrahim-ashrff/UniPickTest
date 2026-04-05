import 'package:flutter/foundation.dart';

/// Tracks whether the user is browsing as a guest (no account).
/// Guests can use the app except payment; Account tab is hidden.
class GuestProvider extends ChangeNotifier {
  bool _isGuest = false;

  bool get isGuest => _isGuest;

  void setGuest(bool value) {
    if (_isGuest != value) {
      _isGuest = value;
      notifyListeners();
    }
  }
}
