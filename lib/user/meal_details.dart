import 'package:flutter/material.dart';
import 'package:meal_logging/main.dart';

class MealDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const MealDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Back Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lightBlueTheme.colorScheme.primary, lightBlueTheme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Meal Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              data['name'] ?? 'Unnamed Meal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: lightBlueTheme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildCategoryChip(
                                  'Category: ${data['foodCategory'] ?? 'Unknown'}',
                                  Colors.orange,
                                ),
                                const SizedBox(height: 8),
                                _buildCategoryChip(
                                  'Group: ${data['foodGroup'] ?? 'Unknown'}',
                                  Colors.deepOrange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Nutrition Overview
                      Text(
                        "Nutrition Overview (per 100g)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: lightBlueTheme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickNutrition(),
                      const SizedBox(height: 24),

                      // Detailed Nutrition Info Section
                      Text(
                        "Detailed Nutritional Information",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: lightBlueTheme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _nutrientTile("Calories", "${data['calorie'] ?? '0'} kcal", Colors.orange),
                              _divider(),
                              _nutrientTile("Water", "${data['water'] ?? '0'} g", Colors.blue),
                              _divider(),
                              _nutrientTile("Protein", "${data['protein'] ?? '0'} g", Colors.red),
                              _divider(),
                              _nutrientTile("Carbohydrates", "${data['carb'] ?? '0'} g", Colors.brown),
                              _divider(),
                              _nutrientTile("Fat", "${data['fat'] ?? '0'} g", Colors.green),
                              _divider(),
                              _nutrientTile("Fibre", "${data['fibre'] ?? '0'} g", Colors.purple),
                              _divider(),
                              _nutrientTile("Ash", "${data['ash'] ?? '0'} g", Colors.pinkAccent),
                              _divider(),
                              _nutrientTile("Calcium", "${data['calcium'] ?? '0'} mg", Colors.teal),
                              _divider(),
                              _nutrientTile("Iron", "${data['iron'] ?? '0'} mg", Colors.deepOrange),
                              _divider(),
                              _nutrientTile("Phosphorus", "${data['phosphorus'] ?? '0'} mg", Colors.indigo),
                              _divider(),
                              _nutrientTile("Potassium", "${data['potassium'] ?? '0'} mg", Colors.amber),
                              _divider(),
                              _nutrientTile("Sodium", "${data['sodium'] ?? '0'} mg", Colors.blueGrey),
                            ],
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
      ),
    );
  }

  Widget _buildCategoryChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildQuickNutrition() {
    return Row(
      children: [
        Expanded(
          child: _buildNutritionCard(
            '🔥',
            'Calories',
            '${data['calorie'] ?? '0'}',
            'kcal',
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNutritionCard(
            '🥩',
            'Protein',
            '${data['protein'] ?? '0'}',
            'g',
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNutritionCard(
            '🍞',
            'Carbs',
            '${data['carb'] ?? '0'}',
            'g',
            Colors.brown,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNutritionCard(
            '🥑',
            'Fat',
            '${data['fat'] ?? '0'}',
            'g',
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionCard(String emoji, String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutrientTile(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
    );
  }
}