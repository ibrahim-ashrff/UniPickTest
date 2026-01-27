import 'package:flutter/foundation.dart';
import '../models/saved_card.dart';

/// Provider for managing saved payment cards
class SavedCardsProvider extends ChangeNotifier {
  final List<SavedCard> _savedCards = [];

  List<SavedCard> get savedCards => List.unmodifiable(_savedCards);

  SavedCard? get defaultCard {
    try {
      return _savedCards.firstWhere((card) => card.isDefault);
    } catch (e) {
      return _savedCards.isNotEmpty ? _savedCards.first : null;
    }
  }

  /// Add a new card
  void addCard(SavedCard card) {
    // If this is the first card or marked as default, set it as default
    if (_savedCards.isEmpty || card.isDefault) {
      // Remove default from all other cards
      for (var existingCard in _savedCards) {
        if (existingCard.isDefault) {
          final index = _savedCards.indexOf(existingCard);
          _savedCards[index] = SavedCard(
            id: existingCard.id,
            cardNumber: existingCard.cardNumber,
            cardHolderName: existingCard.cardHolderName,
            expiryMonth: existingCard.expiryMonth,
            expiryYear: existingCard.expiryYear,
            cardType: existingCard.cardType,
            isDefault: false,
          );
        }
      }
    }
    _savedCards.add(card);
    notifyListeners();
  }

  /// Remove a card
  void removeCard(String cardId) {
    _savedCards.removeWhere((card) => card.id == cardId);
    // If we removed the default card and there are other cards, set the first one as default
    if (_savedCards.isNotEmpty && !_savedCards.any((card) => card.isDefault)) {
      final firstCard = _savedCards.first;
      final index = _savedCards.indexOf(firstCard);
      _savedCards[index] = SavedCard(
        id: firstCard.id,
        cardNumber: firstCard.cardNumber,
        cardHolderName: firstCard.cardHolderName,
        expiryMonth: firstCard.expiryMonth,
        expiryYear: firstCard.expiryYear,
        cardType: firstCard.cardType,
        isDefault: true,
      );
    }
    notifyListeners();
  }

  /// Set a card as default
  void setDefaultCard(String cardId) {
    // Remove default from all cards
    for (var i = 0; i < _savedCards.length; i++) {
      if (_savedCards[i].isDefault) {
        _savedCards[i] = SavedCard(
          id: _savedCards[i].id,
          cardNumber: _savedCards[i].cardNumber,
          cardHolderName: _savedCards[i].cardHolderName,
          expiryMonth: _savedCards[i].expiryMonth,
          expiryYear: _savedCards[i].expiryYear,
          cardType: _savedCards[i].cardType,
          isDefault: false,
        );
      }
    }

    // Set the selected card as default
    final index = _savedCards.indexWhere((card) => card.id == cardId);
    if (index >= 0) {
      final card = _savedCards[index];
      _savedCards[index] = SavedCard(
        id: card.id,
        cardNumber: card.cardNumber,
        cardHolderName: card.cardHolderName,
        expiryMonth: card.expiryMonth,
        expiryYear: card.expiryYear,
        cardType: card.cardType,
        isDefault: true,
      );
      notifyListeners();
    }
  }
}




