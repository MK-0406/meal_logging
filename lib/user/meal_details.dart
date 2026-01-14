import 'package:flutter/material.dart';

class MealDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const MealDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMealTitleSection(),
                  const SizedBox(height: 28),
                  _buildSectionTitle("Nutrition Highlights (per 100g)"),
                  const SizedBox(height: 16),
                  _buildQuickNutritionGrid(),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Detailed Nutritional Profile"),
                  const SizedBox(height: 16),
                  _buildDetailedNutrientsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Meal Details',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTitleSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text(
            data['name'] ?? 'Unnamed Meal',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), height: 1.2),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildModernChip(data['foodCategory'] ?? 'Unknown', Colors.blue),
              _buildModernChip(data['foodGroup'] ?? 'General', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), letterSpacing: -0.3),
      ),
    );
  }

  Widget _buildQuickNutritionGrid() {
    return Row(
      children: [
        Expanded(child: _buildMacroCard('🔥', 'Calories', '${data['calorie'] ?? 0}', 'kcal', Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildMacroCard('🥩', 'Protein', '${data['protein'] ?? 0}', 'g', Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildMacroCard('🍞', 'Carbs', '${data['carb'] ?? 0}', 'g', Colors.brown)),
        const SizedBox(width: 12),
        Expanded(child: _buildMacroCard('🥑', 'Fat', '${data['fat'] ?? 0}', 'g', Colors.green)),
      ],
    );
  }

  Widget _buildMacroCard(String emoji, String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDetailedNutrientsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _nutrientRow("Water", "${data['water'] ?? 0} g", Colors.lightBlue),
          _divider(),
          _nutrientRow("Fibre", "${data['fibre'] ?? 0} g", Colors.green),
          _divider(),
          _nutrientRow("Iron", "${data['iron'] ?? 0} mg", Colors.redAccent),
          _divider(),
          _nutrientRow("Calcium", "${data['calcium'] ?? 0} mg", Colors.indigo),
          _divider(),
          _nutrientRow("Sodium", "${data['sodium'] ?? 0} mg", Colors.blueGrey),
          _divider(),
          _nutrientRow("Potassium", "${data['potassium'] ?? 0} mg", Colors.teal),
          _divider(),
          _nutrientRow("Phosphorus", "${data['phosphorus'] ?? 0} mg", Colors.deepPurple),
          _divider(),
          _nutrientRow("Ash", "${data['ash'] ?? 0} g", Colors.brown),
        ],
      ),
    );
  }

  Widget _nutrientRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade100);
  }
}
