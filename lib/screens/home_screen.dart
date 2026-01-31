import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/food_truck.dart';
import '../data/mock_food_trucks.dart';
import '../utils/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/bottom_wave.dart';
import 'food_truck_menu_screen.dart';

/// Home screen displaying featured food trucks in a 2x2 grid
/// Each card shows image, name, and cuisine type
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get first 4 food trucks for the home grid
    final featuredTrucks = mockFoodTrucks.take(4).toList();
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    // Responsive header height - reduced to approximately 28% of screen
    final headerHeight = screenHeight * 0.28;
    final waveHeight = 100.0;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // Wave with gradient at the boundary (upside down, transitioning from white to burgundy)
          Positioned(
            top: headerHeight - waveHeight,
            left: 0,
            right: 0,
            height: waveHeight,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(1.0, -1.0),
              child: const BottomWave(color: AppColors.burgundy, height: 100),
            ),
          ),
          // Solid burgundy section at top (from top to bottom of wave)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight - waveHeight,
            child: Container(
              color: AppColors.burgundy,
            ),
          ),

          // Foreground content
          SafeArea(
            child: Column(
              children: [
                // Burgundy header section with text
                SizedBox(
                  height: headerHeight - statusBarHeight - MediaQuery.of(context).padding.bottom,
                  child: Transform.translate(
                    offset: const Offset(0, -25),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Logo and UniPick text side by side
                          Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'UniPick',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: 32,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Image.asset(
                                  'LOGOUNI-removebg-preview.png',
                                  height: 100,
                                  fit: BoxFit.contain,
                                  color: Colors.white,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -16),
                            child: Text(
                              'Skip the line. Pick up smart',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // White section with food trucks (no scrolling)
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Featured food trucks text - positioned right after wave
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Text(
                              'Featured Food Trucks',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                fontSize: 20,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        // 2x2 Grid of food truck cards
                        Expanded(
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 18,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: featuredTrucks.length,
                            itemBuilder: (context, index) {
                              return _FoodTruckCard(truck: featuredTrucks[index]);
                            },
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Food truck card widget with image, name, and cuisine type
class _FoodTruckCard extends StatelessWidget {
  final FoodTruck truck;

  const _FoodTruckCard({required this.truck});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.burgundy.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          // Navigate to food truck menu screen when tapped
          context.slideTo(
            FoodTruckMenuScreen(truck: truck),
            direction: SlideDirection.right,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Food truck image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  image: truck.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(truck.imageUrl),
                          fit: BoxFit.cover,
                          onError: (_, __) {
                            // Handle image load error
                          },
                        )
                      : null,
                ),
                child: truck.imageUrl.isEmpty
                    ? const Icon(
                        Icons.restaurant,
                        size: 50,
                        color: Colors.grey,
                      )
                    : null,
              ),
            ),
            // Food truck info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name
                    Flexible(
                      child: Text(
                        truck.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Cuisine type
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.burgundy.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          truck.cuisine,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.burgundy,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
