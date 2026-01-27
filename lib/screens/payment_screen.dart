import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/saved_card.dart';
import '../utils/app_colors.dart';
import '../state/saved_cards_provider.dart';
import '../payments/fawry_payment.dart';

/// Payment screen for managing saved payment cards
/// Users can add, view, and delete saved cards for easier checkout
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<SavedCardsProvider>(
        builder: (context, cardsProvider, child) {
          final savedCards = cardsProvider.savedCards;

          if (savedCards.isEmpty) {
            return _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedCards.length,
            itemBuilder: (context, index) {
              return _SavedCardTile(card: savedCards[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddCardDialog(context);
        },
        backgroundColor: AppColors.burgundy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Card',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController();
    final expiryMonthController = TextEditingController();
    final expiryYearController = TextEditingController();
    String selectedCardType = 'Visa';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Card'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Card Type Dropdown
                DropdownButtonFormField<String>(
                  value: selectedCardType,
                  decoration: InputDecoration(
                    labelText: 'Card Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.burgundy),
                    ),
                  ),
                  items: ['Visa', 'Mastercard', 'American Express']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedCardType = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Card Number (last 4 digits)
                TextFormField(
                  controller: cardNumberController,
                  decoration: InputDecoration(
                    labelText: 'Last 4 Digits',
                    hintText: '1234',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.burgundy),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter last 4 digits';
                    }
                    if (value.length != 4) {
                      return 'Must be 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Card Holder Name
                TextFormField(
                  controller: cardHolderController,
                  decoration: InputDecoration(
                    labelText: 'Card Holder Name',
                    hintText: 'John Doe',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.burgundy),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter card holder name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Expiry Date
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: expiryMonthController,
                        decoration: InputDecoration(
                          labelText: 'Month',
                          hintText: 'MM',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.burgundy),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'MM';
                          }
                          final month = int.tryParse(value);
                          if (month == null || month < 1 || month > 12) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: expiryYearController,
                        decoration: InputDecoration(
                          labelText: 'Year',
                          hintText: 'YY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.burgundy),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'YY';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cardsProvider =
                    Provider.of<SavedCardsProvider>(context, listen: false);
                final newCard = SavedCard(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  cardNumber: cardNumberController.text,
                  cardHolderName: cardHolderController.text,
                  expiryMonth: expiryMonthController.text,
                  expiryYear: expiryYearController.text,
                  cardType: selectedCardType,
                  isDefault: cardsProvider.savedCards.isEmpty,
                );
                cardsProvider.addCard(newCard);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Card saved successfully!'),
                    backgroundColor: AppColors.burgundy,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no cards are saved
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card,
              size: 80,
              color: AppColors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Cards',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a payment card to make checkout faster',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved card tile widget
class _SavedCardTile extends StatelessWidget {
  final SavedCard card;

  const _SavedCardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: card.isDefault
              ? AppColors.burgundy
              : AppColors.greyLight,
          width: card.isDefault ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.burgundy.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.credit_card,
            color: AppColors.burgundy,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  card.cardType,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (card.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEFAULT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              card.maskedCardNumber,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${card.cardHolderName} • Expires ${card.expiryDate}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
          itemBuilder: (context) => [
            if (!card.isDefault)
              PopupMenuItem(
                child: const Text('Set as Default'),
                onTap: () {
                  Future.delayed(
                    const Duration(milliseconds: 100),
                    () {
                      Provider.of<SavedCardsProvider>(context, listen: false)
                          .setDefaultCard(card.id);
                    },
                  );
                },
              ),
            PopupMenuItem(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Future.delayed(
                  const Duration(milliseconds: 100),
                  () {
                    Provider.of<SavedCardsProvider>(context, listen: false)
                        .removeCard(card.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Card removed'),
                        backgroundColor: AppColors.burgundy,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


