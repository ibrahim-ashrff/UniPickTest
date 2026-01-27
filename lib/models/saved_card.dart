/// Model for saved payment cards
class SavedCard {
  final String id;
  final String cardNumber; // Last 4 digits
  final String cardHolderName;
  final String expiryMonth;
  final String expiryYear;
  final String cardType; // 'Visa', 'Mastercard', etc.
  final bool isDefault;

  SavedCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cardType,
    this.isDefault = false,
  });

  // Get masked card number for display
  String get maskedCardNumber => '**** **** **** $cardNumber';

  // Get expiry date formatted
  String get expiryDate => '$expiryMonth/$expiryYear';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardNumber': cardNumber,
      'cardHolderName': cardHolderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'cardType': cardType,
      'isDefault': isDefault,
    };
  }

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] ?? '',
      cardNumber: json['cardNumber'] ?? '',
      cardHolderName: json['cardHolderName'] ?? '',
      expiryMonth: json['expiryMonth'] ?? '',
      expiryYear: json['expiryYear'] ?? '',
      cardType: json['cardType'] ?? 'Visa',
      isDefault: json['isDefault'] ?? false,
    );
  }
}




