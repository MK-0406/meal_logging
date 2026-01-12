import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'log_meals.dart';
import 'meal_details.dart';
import '../functions.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class MealDiary extends StatefulWidget {
  const MealDiary({super.key});

  @override
  State<MealDiary> createState() => _MealDiaryState();
}

class _MealDiaryState extends State<MealDiary> {
  DateTime selectedDate = DateTime.now();
  Map<String, Map<String, dynamic>>? mealTargets;
  bool _isLoadingModel = true;
  Map<String, double>? _dailyIntake;
  bool _isLoadingIntake = false;
  final bool _previousDayAvailable = true;
  bool includeSnacks = true;
  bool includeSnacksFromDatabase = false;
  late DocumentSnapshot diaryDoc;

  late var results = <String, dynamic>{};
  late var mealRatios = {'Breakfast': 0.2, 'Lunch': 0.31, 'Dinner': 0.39, 'Snack': 0.10};

  final CollectionReference userInfo = FirebaseFirestore.instance.collection('usersInfo');
  final CollectionReference mealLogs = FirebaseFirestore.instance.collection('mealLogs');
  final CollectionReference mealsCol = FirebaseFirestore.instance.collection('meals');
  final CollectionReference customMealsCol = FirebaseFirestore.instance.collection('custom_meal').doc(FirebaseAuth.instance.currentUser!.uid).collection('meals');

  final List<String> mealCategories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  final Set<String> expandedMeals = {};

  @override
  void initState() {
    super.initState();
    _checkAndPromptMissingMeals(true);
    _loadRecommendationFromDatabase();
    _loadDailyIntake();
    _loadIncludeSnacksFromDatabase();
  }

  Future<void> regenerateTomorrowRecommendation() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final tomorrow = selectedDate.add(const Duration(days: 1));
    final tomorrowDate = DateFormat('EEEE, dd MMM yyyy').format(tomorrow);
    final userDetails = await Database.getDocument('usersInfo', null);
    final userData = userDetails.data() as Map<String, dynamic>;

    final List<Map<String, dynamic>> todayMealData = await Database.getItemsWithConditions(
      'mealLogs', 'uid',
      conditions: {
        'date': DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
      },
    );

    double proteinIntake = 0, carbsIntake = 0, fatsIntake = 0;

    for (final data in todayMealData) {
      var mealDoc = await Database.getDocument('meals', data['mealID']);
      if (!mealDoc.exists) {
        CollectionReference collectionRef = FirebaseFirestore.instance.collection('custom_meal');
        mealDoc = await collectionRef.doc(FirebaseAuth.instance.currentUser!.uid).collection('meals').doc(data['mealID']).get();
      }
      final mealDataMap = mealDoc.data() as Map<String, dynamic>;

      double ratio = data['servingSize'] / 100;
      proteinIntake += mealDataMap['protein'] * ratio;
      carbsIntake += mealDataMap['carb'] * ratio;
      fatsIntake += mealDataMap['fat'] * ratio;
    }

    if (proteinIntake == 0 && carbsIntake == 0 && fatsIntake == 0){
      await FirebaseFirestore.instance
          .collection('recommendations')
          .doc(uid)
          .collection('dates')
          .doc(tomorrowDate)
          .delete();
      return;
    }

    final url = Uri.parse("https://meal-recommender-model.onrender.com/predict");
    final bodyData = {
      "features": [
        userData['age'].toDouble(),
        (userData['height_m'] * 100).toDouble(),
        userData['weight_kg'].toDouble(),
        userData['bmi'].toDouble(),
        userData['bloodPressureSystolic'].toDouble(),
        userData['bloodPressureDiastolic'].toDouble(),
        (userData['cholesterol_mmolL'] * 38.67).toDouble(),
        (userData['bloodSugar_mmolL'] * 18).toDouble(),
        proteinIntake.toDouble(),
        carbsIntake.toDouble(),
        fatsIntake.toDouble(),
      ]
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(bodyData),
    );

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final prediction = data['prediction'][0];
    final nutrients = ['Protein_g', 'Carbs_g', 'Fats_g'];
    final results = <String, dynamic>{};

    for (int i = 0; i < nutrients.length; i++) {
      results[nutrients[i]] = prediction[i];
    }

    results['Calories'] = (4 * (prediction[0] + prediction[1]) + 9 * prediction[2]).round();

    await FirebaseFirestore.instance
        .collection('recommendations')
        .doc(uid)
        .collection('dates')
        .doc(tomorrowDate)
        .set(results);

    setState(() {
      _isLoadingModel = false;
    });
  }

  Future<void> _loadRecommendationFromDatabase() async {
    setState(() => _isLoadingModel = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final dateStr = DateFormat('EEEE, dd MMM yyyy').format(selectedDate);

      final docSnapshot = await FirebaseFirestore.instance
          .collection('recommendations')
          .doc(uid)
          .collection('dates')
          .doc(dateStr)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;

        setState(() {
          results = Map<String, dynamic>.from(data);
          calculateRecommendationForEachMealPeriod();
        });
      }
    } catch (e) {
      setState(() => _isLoadingModel = false);
    }
  }

  Future<void> _loadDailyIntake() async {
    setState(() => _isLoadingIntake = true);
    final intake = await _calculateDailyIntake();
    setState(() {
      _dailyIntake = intake;
      _isLoadingIntake = false;
    });
  }

  void calculateRecommendationForEachMealPeriod(){
    final targets = <String, Map<String, dynamic>>{};

    mealRatios.forEach((meal, ratio) {
      final mealValues = <String, dynamic>{};
      results.forEach((nutrient, data) {
        mealValues[nutrient] = data * ratio;
      });
      targets[meal] = mealValues;
    });

    setState(() {
      mealTargets = targets;
      _isLoadingModel = false;
    });
  }

  Future<void> _checkAndPromptMissingMeals(bool needChecking) async {
    final missing = <String>[];
    if (!needChecking) return;

    final querySnapshot = await FirebaseFirestore.instance.collection('mealLogs')
        .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid).get();

    final List<Map<String, dynamic>> todayMealData = await Database.getItemsWithConditions(
      'mealLogs', 'uid',
      conditions: {
        'date': DateFormat('EEEE, dd MMM yyyy').format(selectedDate.subtract(const Duration(days: 1))),
      },
    );

    bool hasBreakfast = false, hasLunch = false, hasDinner = false;

    for (final data in todayMealData) {
      final mealType = data['mealType'];
      if (mealType == 'Breakfast') hasBreakfast = true;
      if (mealType == 'Lunch') hasLunch = true;
      if (mealType == 'Dinner') hasDinner = true;
    }

    if (!hasBreakfast) missing.add('Breakfast');
    if (!hasLunch) missing.add('Lunch');
    if (!hasDinner) missing.add('Dinner');
    if (missing.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        if (querySnapshot.docs.isEmpty && selectedDate.day == DateTime.now().day){
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.restaurant_menu, color: Colors.blue.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "First Time Logging Meals",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: const Text(
                "To generate accurate meal recommendations, we need your meals from yesterday.\n\nWould you like to log yesterday's meals now or use common intakes instead?",
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      results = {'Calories': 2000, 'Protein_g': 130, 'Carbs_g': 250, 'Fats_g': 90};
                      calculateRecommendationForEachMealPeriod();
                    });
                    await FirebaseFirestore.instance
                        .collection('recommendations')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('dates')
                        .doc(DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
                        .set(results);
                  },
                  child: const Text("Use Default", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _previousDay(false);
                  },
                  child: const Text("Log Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text("Missing Meals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(
                "You haven't logged these meals for yesterday:\n${missing.join(", ")}",
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Later", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _previousDay(false);
                  },
                  child: const Text("Log Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  Future<void> saveIncludeSnacksIntoDatabase() async {
    if (includeSnacksFromDatabase) {
      Database.updateItems('diary', diaryDoc.id, {
        'includeSnacks': includeSnacks,
      });
    } else {
      Database.addItems('diary', {
        'includeSnacks': includeSnacks,
        'date': DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
        'userId' : FirebaseAuth.instance.currentUser!.uid,
      });
      setState(() {
        _loadIncludeSnacksFromDatabase();
      });
    }
  }

  Future<void> _loadIncludeSnacksFromDatabase() async {
    final doc = await FirebaseFirestore.instance.collection('diary')
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .where('date', isEqualTo: DateFormat('EEEE, dd MMM yyyy').format(selectedDate)).get();
    bool include = true;
    if (doc.docs.isNotEmpty) {
      diaryDoc = doc.docs.first;
      final data = diaryDoc.data() as Map<String, dynamic>;
      include = (data['includeSnacks'] == null) ? true : data['includeSnacks'];
      includeSnacksFromDatabase = (data['includeSnacks'] == null) ? false : true;
    } else {
      includeSnacksFromDatabase = false;
    }
    setState(() {
      includeSnacks = include;
      _isLoadingModel = false;
    });
  }

  void _previousDay(bool needChecking) {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      _checkAndPromptMissingMeals(needChecking);
      _loadRecommendationFromDatabase();
      _loadDailyIntake();
      mealTargets = null;
      _loadIncludeSnacksFromDatabase();
      results.clear();
    });
  }

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
      _checkAndPromptMissingMeals(true);
      _loadRecommendationFromDatabase();
      mealTargets = null;
      _loadDailyIntake();
      _loadIncludeSnacksFromDatabase();
      results.clear();
    });
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF42A5F5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _loadRecommendationFromDatabase();
      _loadDailyIntake();
      mealTargets = null;
      _loadIncludeSnacksFromDatabase();
      results.clear();
    }
  }

  void _refreshData() {
    setState(() {});
    _loadDailyIntake();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, dd MMM yyyy').format(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    String day = selected == today
        ? 'Today'
        : selected == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : '';

    return Scaffold(
      key: const ValueKey('diary'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F9FF), Color(0xFFE8F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade300.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        onPressed: () => _previousDay(true),
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF42A5F5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                day.isNotEmpty ? day : formattedDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.expand_more, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        onPressed: selectedDate.isBefore(today) ? _nextDay : null,
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF42A5F5),
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoadingModel
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: const Color(0xFF42A5F5),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Analyzing your nutrition...',
                        style: TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Daily Summary Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.insights, color: Color(0xFF42A5F5), size: 24),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Daily Nutrients Recommendation",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF42A5F5),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.85,
                                child: _buildNutrientSummary(),
                              ),
                            ),
                            const SizedBox(height: 18),

                            if (_isLoadingIntake)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(
                                    color: const Color(0xFF42A5F5),
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            else if (_dailyIntake != null)
                              _buildIntakeComparison(
                                _dailyIntake!['calories']!,
                                _dailyIntake!['protein']!,
                                _dailyIntake!['carbs']!,
                                _dailyIntake!['fats']!,
                              )
                            else
                              const SizedBox.shrink(),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Include Snacks for Recommendation",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF42A5F5),
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 1.1,
                                    child: Checkbox(
                                      value: includeSnacks,
                                      activeColor: const Color(0xFF42A5F5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          includeSnacks = value!;
                                          mealRatios = includeSnacks
                                              ? {'Breakfast': 0.2, 'Lunch': 0.31, 'Dinner': 0.39, 'Snack': 0.1}
                                              : {'Breakfast': 0.22, 'Lunch': 0.33, 'Dinner': 0.45, 'Snack': 0.0};
                                          calculateRecommendationForEachMealPeriod();
                                          saveIncludeSnacksIntoDatabase();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Meal Sections
                    ...mealCategories.map((mealType) {
                      final mealTarget = mealTargets?[mealType];
                      return _buildMealSection(mealType, mealTarget);
                    }),

                    const SizedBox(height: 80), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealSection(String mealType, Map<String, dynamic>? mealTarget) {
    return StreamBuilder<QuerySnapshot>(
      stream: mealLogs
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .where('mealType', isEqualTo: mealType)
          .where('date', isEqualTo: DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
          .snapshots(),
      builder: (context, snapshot) {
        final meals = snapshot.data?.docs ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, _getMealColor(mealType).withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ExpansionTile(
                initiallyExpanded: expandedMeals.contains(mealType),
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      expandedMeals.add(mealType);
                    } else {
                      expandedMeals.remove(mealType);
                    }
                  });
                },
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getMealColor(mealType).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getMealIcon(mealType),
                    color: _getMealColor(mealType),
                    size: 24,
                  ),
                ),
                title: Text(
                  mealType,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${meals.length} meal${meals.length != 1 ? 's' : ''} logged',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getMealColor(mealType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    expandedMeals.contains(mealType) ? Icons.expand_less : Icons.expand_more,
                    color: _getMealColor(mealType),
                  ),
                ),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  if (meals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.fastfood_outlined, size: 56, color: Colors.grey[350]),
                          const SizedBox(height: 12),
                          Text(
                            "No meals logged yet",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Start by adding your first meal!",
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    FutureBuilder(
                      future: Future.wait(meals.map((m) async {
                        var mealDoc = await mealsCol.doc(m['mealID']).get();
                        if (!mealDoc.exists) {
                          mealDoc = await customMealsCol.doc(m['mealID']).get();
                        }

                        return {
                          'log': m,
                          'mealData': mealDoc.exists ? mealDoc.data() : {},
                        };
                      })),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: const Color(0xFF42A5F5),
                                strokeWidth: 3,
                              ),
                            ),
                          );
                        }

                        final items = snapshot.data as List<Map<String, dynamic>>;

                        return Column(
                          children: items.map((item) {
                            final m = item['log'];
                            final mealData = item['mealData'];
                            final mealName = mealData['name'] ?? 'Unnamed Meal';
                            final servingSize = m['servingSize'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getMealColor(mealType).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    color: _getMealColor(mealType),
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  mealName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Serving: ${servingSize}g',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 22),
                                    onPressed: () async {
                                      await mealLogs.doc(m.id).delete();
                                      _refreshData();
                                      regenerateTomorrowRecommendation();
                                    },
                                  ),
                                ),
                                onTap: () async {
                                  var mealDoc = await mealsCol.doc(m['mealID']).get();
                                  if (!mealDoc.exists) {
                                    mealDoc = await customMealsCol.doc(m['mealID']).get();
                                  }
                                  if (mealDoc.exists) {
                                    final mealData = mealDoc.data() as Map<String, dynamic>;
                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => MealDetailsPage(data: mealData)),
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MealLogPage(
                              mealType: mealType,
                              logDate: DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
                              nutritionalTargets: mealTarget,
                            ),
                          ),
                        );
                        _refreshData();
                        regenerateTomorrowRecommendation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getMealColor(mealType),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text(
                        'Add Meal',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getMealColor(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return const Color(0xFFFF9800);
      case 'Lunch':
        return const Color(0xFF4CAF50);
      case 'Dinner':
        return const Color(0xFF9C27B0);
      case 'Snack':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  Widget _buildNutrientSummary() {
    if (mealTargets == null || !_previousDayAvailable) return const SizedBox.shrink();
    double totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFats = 0;

    mealTargets!.forEach((_, t) {
        if (t.isNotEmpty){
          totalCal += t['Calories'];
          totalProtein += t['Protein_g'];
          totalCarbs += t['Carbs_g'];
          totalFats += t['Fats_g'];
        }
    });

    if (totalCal == 0) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildNutrientCard('🔥 Calories', '${totalCal.toStringAsFixed(0)} kcal', Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _buildNutrientCard('🥩 Protein', '${totalProtein.toStringAsFixed(0)} g', Colors.blue)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildNutrientCard('🍞 Carbs', '${totalCarbs.toStringAsFixed(0)} g', Colors.brown)),
            const SizedBox(width: 10),
            Expanded(child: _buildNutrientCard('🥑 Fats', '${totalFats.toStringAsFixed(0)} g', Colors.green)),
          ],
        ),
      ],
    );
  }

  Widget _buildNutrientCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double actual, double target, String unit, Color color) {
    final percentage = target > 0 ? (actual / target * 100).clamp(0, 100) : 0;
    final isOver = actual > target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2),
            ),
            Text(
              '${actual.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isOver ? Colors.red.shade600 : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red.shade400 : color),
            minHeight: 8,
            semanticsLabel: label,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${percentage.toStringAsFixed(1)}% of target',
          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<Map<String, double>> _calculateDailyIntake() async {
    try {
      double totalCalIntake = 0, totalProteinIntake = 0, totalCarbsIntake = 0, totalFatsIntake = 0;

      final QuerySnapshot mealDataQuery = await mealLogs
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .where('date', isEqualTo: DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
          .get();

      for (final doc in mealDataQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        DocumentSnapshot mealQuery = await mealsCol.doc(data['mealID']).get();
        if (!mealQuery.exists) {
          mealQuery = await customMealsCol.doc(data['mealID']).get();
        }
        if (mealQuery.exists) {
          final mealData = mealQuery.data() as Map<String, dynamic>;
          final servingSize = data['servingSize'];
          totalCalIntake += (mealData['calorie']) * servingSize / 100;
          totalProteinIntake += (mealData['protein']) * servingSize / 100;
          totalCarbsIntake += (mealData['carb']) * servingSize / 100;
          totalFatsIntake += (mealData['fat']) * servingSize / 100;
        }
      }

      return {
        'calories': totalCalIntake,
        'protein': totalProteinIntake,
        'carbs': totalCarbsIntake,
        'fats': totalFatsIntake,
      };
    } catch (e) {
      return {'calories': 0, 'protein': 0, 'carbs': 0, 'fats': 0};
    }
  }

  Widget _buildIntakeComparison(
      double totalCalIntake,
      double totalProteinIntake,
      double totalCarbsIntake,
      double totalFatsIntake,
      ) {
    double totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFats = 0;
    if (_previousDayAvailable && mealTargets != null) {
      mealTargets!.forEach((meal, targets) {
        if (targets.isNotEmpty) {
          totalCal += targets['Calories'];
          totalProtein += targets['Protein_g'];
          totalCarbs += targets['Carbs_g'];
          totalFats += targets['Fats_g'];
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Progress',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF42A5F5),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        _buildProgressRow('🔥 Calories', totalCalIntake, totalCal, 'kcal', Colors.orange),
        const SizedBox(height: 12),
        _buildProgressRow('🥩 Protein', totalProteinIntake, totalProtein, 'g', Colors.blue),
        const SizedBox(height: 12),
        _buildProgressRow('🍞 Carbs', totalCarbsIntake, totalCarbs, 'g', Colors.brown),
        const SizedBox(height: 12),
        _buildProgressRow('🥑 Fats', totalFatsIntake, totalFats, 'g', Colors.green),
      ],
    );
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.breakfast_dining;
      case 'Lunch':
        return Icons.lunch_dining;
      case 'Dinner':
        return Icons.dinner_dining;
      case 'Snack':
        return Icons.local_cafe;
      default:
        return Icons.restaurant_menu;
    }
  }
}