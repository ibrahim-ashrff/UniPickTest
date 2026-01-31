import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../models/menu_item.dart';
import '../../data/mock_menu.dart';

/// Menu Management Screen for Truck Owners
/// Allows adding, editing, deleting menu items and adjusting prices
class TruckOwnerMenuScreen extends StatefulWidget {
  final String? truckId;

  const TruckOwnerMenuScreen({super.key, this.truckId});

  @override
  State<TruckOwnerMenuScreen> createState() => _TruckOwnerMenuScreenState();
}

class _TruckOwnerMenuScreenState extends State<TruckOwnerMenuScreen> {
  final Firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.truckId != null
            ? Firestore
                .collection('food_trucks')
                .doc(widget.truckId)
                .collection('menu_items')
                .orderBy('name')
                .snapshots()
            : null,
        builder: (context, snapshot) {
          if (widget.truckId == null) {
            return Center(
              child: Text(
                'No food truck assigned. Please contact support.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }

          final menuItems = snapshot.data?.docs ?? [];
          final hasFirestoreItems = menuItems.isNotEmpty;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menu Items (${menuItems.length})',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        if (!hasFirestoreItems)
                          ElevatedButton.icon(
                            onPressed: () => _importMockMenuItems(),
                            icon: const Icon(Icons.download),
                            label: const Text('Import Sample Menu'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.burgundy,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (!hasFirestoreItems) const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditMenuItemDialog(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burgundy,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: menuItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 64,
                              color: AppColors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No menu items yet',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Import sample menu or add your own items',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _importMockMenuItems(),
                              icon: const Icon(Icons.download),
                              label: const Text('Import Sample Menu'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.burgundy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: menuItems.length,
                        itemBuilder: (context, index) {
                          final doc = menuItems[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final menuItem = MenuItem(
                            id: doc.id,
                            name: data['name'] ?? '',
                            description: data['description'] ?? '',
                            price: (data['price'] ?? 0.0).toDouble(),
                            imageUrl: data['imageUrl'],
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                menuItem.name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    menuItem.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'EGP ${menuItem.price.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.burgundy,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: AppColors.burgundy,
                                    onPressed: () =>
                                        _showAddEditMenuItemDialog(menuItem),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deleteMenuItem(doc.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddEditMenuItemDialog(MenuItem? menuItem) {
    final nameController =
        TextEditingController(text: menuItem?.name ?? '');
    final descriptionController =
        TextEditingController(text: menuItem?.description ?? '');
    final priceController =
        TextEditingController(text: menuItem?.price.toString() ?? '');
    final imageUrlController =
        TextEditingController(text: menuItem?.imageUrl ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          menuItem == null ? 'Add Menu Item' : 'Edit Menu Item',
          style: GoogleFonts.inter(),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: 'Price (EGP)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Image URL (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: GoogleFonts.inter(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  descriptionController.text.isEmpty ||
                  priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final menuItemData = {
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
                'price': price,
                'imageUrl': imageUrlController.text.trim().isEmpty
                    ? null
                    : imageUrlController.text.trim(),
              };

              try {
                if (menuItem == null) {
                  // Add new item
                  await Firestore
                      .collection('food_trucks')
                      .doc(widget.truckId)
                      .collection('menu_items')
                      .add(menuItemData);
                } else {
                  // Update existing item
                  await Firestore
                      .collection('food_trucks')
                      .doc(widget.truckId)
                      .collection('menu_items')
                      .doc(menuItem.id)
                      .update(menuItemData);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(menuItem == null
                          ? 'Menu item added successfully'
                          : 'Menu item updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: Colors.white,
            ),
            child: Text(
              menuItem == null ? 'Add' : 'Update',
              style: GoogleFonts.inter(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMenuItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Menu Item', style: GoogleFonts.inter()),
        content: Text(
          'Are you sure you want to delete this menu item? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirm == true && widget.truckId != null) {
      try {
        await Firestore
            .collection('food_trucks')
            .doc(widget.truckId)
            .collection('menu_items')
            .doc(itemId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu item deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _importMockMenuItems() async {
    if (widget.truckId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import Sample Menu', style: GoogleFonts.inter()),
        content: Text(
          'This will add ${mockMenuItems.length} sample menu items to your menu. Continue?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: Colors.white,
            ),
            child: Text('Import', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Import each mock menu item to Firestore
      for (var item in mockMenuItems) {
        await Firestore
            .collection('food_trucks')
            .doc(widget.truckId)
            .collection('menu_items')
            .add({
          'name': item.name,
          'description': item.description,
          'price': item.price,
          'imageUrl': item.imageUrl,
        });
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${mockMenuItems.length} menu items!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error importing menu: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


