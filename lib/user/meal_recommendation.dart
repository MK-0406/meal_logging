import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../functions.dart';
import 'meal_details.dart';

class MealRecommender extends StatefulWidget {
  final Map<String, dynamic>? nutritionalTargets;
  final String? mealType;
  final String logDate;

  const MealRecommender({
    super.key,
    this.nutritionalTargets,
    this.mealType,
    required this.logDate,
  });

  @override
  State<MealRecommender> createState() => _MealRecommenderPageState();
}

class _MealRecommenderPageState extends State<MealRecommender> {
  List<Map<String, dynamic>> recommendedMeals = [];
  bool _isLoading = true;
  final TextEditingController _sizeController = TextEditingController();
  final _logFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _runModel();
    _sizeController.text = '100';
  }

  Future<void> _runModel() async {
    try {
      setState(() => _isLoading = true);
      recommendedMeals.clear();

      if (widget.nutritionalTargets != null && widget.mealType != null) {
        final t = widget.nutritionalTargets;
        if (t != null) {
          final meals = await _queryMeals(
            (widget.mealType! == 'Lunch' || widget.mealType == 'Dinner') ? 'Lunch / Dinner' : widget.mealType!,
            t['Calories'],
            t['Carbs_g'],
            t['Protein_g'],
            t['Fats_g'],
          );
          recommendedMeals.addAll(meals);
        }
      } else {
        final interpreter = await Interpreter.fromAsset('meal_recommender-2.tflite');
        final input = [[19, 179, 68, 21.22, 155, 107, 255, 110, 3324, 197, 214, 97]];
        final output = List.filled(4, 0.0).reshape([1, 4]);
        interpreter.run(input, output);

        final nutrients = ['Calories', 'Protein_g', 'Carbs_g', 'Fats_g'];
        final preds = output[0];
        final margins = [0.12, 0.14, 0.27, 0.25];
        final Map<String, dynamic> results = {};

        for (int i = 0; i < nutrients.length; i++) {
          final val = preds[i];
          results[nutrients[i]] = {'pred': val, 'low': val * (1 - margins[i]), 'high': val * (1 + margins[i])};
        }

        final mealRatios = {'Breakfast': 0.3, 'Lunch': 0.4, 'Dinner': 0.3};
        for (final meal in mealRatios.keys) {
          final ratio = mealRatios[meal]!;
          final meals = await _queryMeals(
            meal,
            results['Calories']['pred'] * ratio,
            results['Carbs_g']['pred'] * ratio,
            results['Protein_g']['pred'] * ratio,
            results['Fats_g']['pred'] * ratio,
          );
          recommendedMeals.addAll(meals);
        }
        interpreter.close();
      }

      recommendedMeals.shuffle(Random());
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _queryMeals(String mealType, double calHigh, double carbHigh, double proteinHigh, double fatHigh) async {
    final snapshot = await FirebaseFirestore.instance.collection('meals')
        .where('calorie', isLessThanOrEqualTo: calHigh)
        .get();

    return snapshot.docs.map((doc) {
      var data = doc.data();
      data['id'] = doc.id; // Store document ID
      return data;
    }).where((meal) =>
      meal['protein'] <= proteinHigh &&
      meal['carb'] <= carbHigh &&
      meal['fat'] <= fatHigh &&
      (meal['foodCategory'] == mealType || meal['foodCategory'] == 'Anytime')
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (recommendedMeals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No suitable recommendations found', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ]),
      );
    }

    return Column(
      children: recommendedMeals.take(5).map((data) => _buildMealCard(data)).toList(),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed meal';
    final cal = data['calorie']?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealDetailsPage(data: data))),
        contentPadding: const EdgeInsets.all(7),
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.restaurant_menu_rounded, color: Colors.blue.shade400),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("${cal.toStringAsFixed(0)} kcal per 100g", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Color(0xFF42A5F5), size: 32),
          onPressed: () => _logMealWrapper(data),
        ),
      ),
    );
  }

  void _logMealWrapper(Map<String, dynamic> data) {
    // Since we can't easily call parent methods in a clean way without callbacks, 
    // I'll implement a clean log dialog here that matches the parent one.
    _showLogDialog(data);
  }

  Future<void> _showLogDialog(Map<String, dynamic> mealData) async {
    String? selectedServingName;
    final List<dynamic> servings = mealData['servings'] ?? [];
    _sizeController.text = '100';
    
    await showDialog(
      context: context,
      builder: (logContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Log ${mealData['name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: _logFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (servings.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Select portion size"),
                        value: selectedServingName,
                        items: servings.map((s) => DropdownMenuItem<String>(value: s['name'], child: Text("${s['name']} (${s['grams']}g)"))).toList(),
                        onChanged: (val) => setDialogState(() {
                          selectedServingName = val;
                          final s = servings.firstWhere((item) => item['name'] == val);
                          _sizeController.text = s['grams'].toString();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _sizeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Custom Amount (grams)",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter a value';
                    }
                    final num = double.tryParse(val);
                    if (num == null) {
                      return 'Please enter a valid number';
                    }
                    if (num <= 0) {
                      return 'Please enter a value greater than 0';
                    }
                    return null;
                  }
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (!_logFormKey.currentState!.validate()) return;
                final size = double.tryParse(_sizeController.text) ?? 100.0;
                final exceeds = _checkIfMealExceedsTarget(mealData, size, widget.nutritionalTargets);
                if (exceeds['exceeds']) {
                  await _showExceedConfirmationDialog(logContext, exceeds, mealData['name'], size, mealData['id'], FirebaseAuth.instance.currentUser!.uid, widget.logDate);
                } else {
                  await _addMealToLog(mealData['id'], mealData['name'], size);
                }

                if (!logContext.mounted) return;
                Navigator.pop(logContext);
              },
              child: const Text("Add Meal", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _checkIfMealExceedsTarget(Map<String, dynamic> nutrients, double size, Map<String, dynamic>? targets) {
    if (targets == null) return {'exceeds': false, 'exceedingNutrients': []};
    final List<Map<String, dynamic>> exceeding = [];
    final mapKeys = {'calorie': 'Calories', 'protein': 'Protein_g', 'carb': 'Carbs_g', 'fat': 'Fats_g'};

    mapKeys.forEach((dbKey, targetKey) {
      final mealVal = (nutrients[dbKey] ?? 0.0) * size / 100.0;
      final targetVal = (targets[targetKey] ?? 0.0);
      if (targetVal > 0 && mealVal > targetVal) {
        exceeding.add({'name': dbKey, 'amount': mealVal, 'target': targetVal});
      }
    });
    return {'exceeds': exceeding.isNotEmpty, 'exceedingNutrients': exceeding};
  }

  Future<void> _showExceedConfirmationDialog(BuildContext context, Map<String, dynamic> data, String mealName, double size, String id, String uid, String date) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text("Limit Exceeded")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("This portion of $mealName exceeds your meal goals for:"),
            const SizedBox(height: 12),
            ...data['exceedingNutrients'].map<Widget>((n) => Text("• ${n['name']}: ${n['amount'].toStringAsFixed(0)} / ${n['target'].toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))).toList(),
            const SizedBox(height: 16),
            const Text("Log it anyway?"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(onPressed: () { Navigator.pop(ctx); _addMealToLog(id, mealName, size); }, child: const Text("Yes, Log It", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _addMealToLog(String mealID, String mealName, double size) async {
    await Database.addItems('mealLogs', {
      'uid': FirebaseAuth.instance.currentUser!.uid,
      'mealID': mealID,
      'mealType': widget.mealType ?? 'Anytime',
      'mealName': mealName,
      'date': widget.logDate,
      'servingSize': size,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$mealName added!"), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1E88E5)));
  }
}
