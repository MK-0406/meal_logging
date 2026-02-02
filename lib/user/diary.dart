import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'log_meals.dart';
import 'meal_details.dart';
import 'nutrition_progress.dart'; // Import the new trend page
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
  Map<String, Map<String, double>> _periodIntake = {
    'Breakfast': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
    'Lunch': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
    'Dinner': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
    'Snack': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
  };
  bool _isLoadingIntake = false;
  final bool _previousDayAvailable = true;
  bool includeSnacks = true;
  bool includeSnacksFromDatabase = false;
  late DocumentSnapshot diaryDoc;

  // Water Tracking State
  int _waterIntakeMl = 0;
  late int _waterTargetMl = 2700;

  late var results = <String, dynamic>{};
  late var mealRatios = {'Breakfast': 0.2, 'Lunch': 0.31, 'Dinner': 0.39, 'Snack': 0.10};

  final CollectionReference userInfo = FirebaseFirestore.instance.collection('usersInfo');
  final CollectionReference mealLogs = FirebaseFirestore.instance.collection('mealLogs');
  final CollectionReference waterLogs = FirebaseFirestore.instance.collection('waterLogs');
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
    _loadWaterIntake();
    _loadWaterTarget();
  }

  Future<void> _loadWaterTarget() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await userInfo.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _waterTargetMl = (data['gender'] == 'Male') ? 3700 : 2700;
        });
      }
    }
  }

  Future<void> _loadWaterIntake() async {
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(selectedDate);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    final query = await waterLogs
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: dateStr)
        .orderBy('timestamp', descending: true)
        .get();

    int total = 0;
    for (var doc in query.docs) {
      total += (doc.data() as Map<String, dynamic>)['amountMl'] as int;
    }

    setState(() {
      _waterIntakeMl = total;
    });
  }

  Future<void> _logWater(int amount) async {
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(selectedDate);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await waterLogs.add({
      'uid': uid,
      'date': dateStr,
      'amountMl': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _loadWaterIntake();
  }

  Future<Map<String, dynamic>> _checkBoundaries(Map<String, dynamic> data) async { // set min and max intake for each nutrient
    final userDetails = await Database.getDocument('usersInfo', null);
    final userData = userDetails.data() as Map<String, dynamic>;

    double minProtein = userData['weight_kg'];
    double maxProtein = userData['weight_kg'] * 3.5;

    if (data['Protein_g'] == null){
      data = {'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0};
    }

    if (data['Protein_g'] < minProtein) {
      data['Protein_g'] = minProtein;
    } else if (data['Protein_g'] > maxProtein) {
      data['Protein_g'] = maxProtein;
    }

    if (data['Carbs_g'] < 130) {
      if (userData['bmi'] < 23 && userData['bloodPressureDiastolic'] < 80 && userData['bloodPressureSystolic'] < 130 && userData['bloodSugar_mmolL'] < 7) {
        data['Carbs_g'] = 130;
      } else {
        if (data['Carbs_g'] < 50) {
          data['Carbs_g'] = 50;
        }
      }
    }

    switch (userData['gender']) {
      case 'Male':
        double minFats = (1500 * 0.2) / 9;
        double maxFats = (1500 * 0.3) / 9;
        if (data['Fats_g'] < minFats) {
          data['Fats_g'] = minFats;
        } else if (data['Fats_g'] > maxFats) {
          data['Fats_g'] = maxFats;
        }
        break;

      case 'Female':
        double minFats = (1200 * 0.2) / 9;
        double maxFats = (1200 * 0.3) / 9;
        if (data['Fats_g'] < minFats) {
          data['Fats_g'] = minFats;
        } else if (data['Fats_g'] > maxFats) {
          data['Fats_g'] = maxFats;
        }
        break;
    }
    
    // Recalculate Calories based on boundaries
    data['Calories'] = (4 * (data['Protein_g'] + data['Carbs_g']) + 9 * data['Fats_g']).round();

    return data;
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

    // no need delete, i need the tmr data for tmr target reminder

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
    var results = <String, dynamic>{};

    for (int i = 0; i < nutrients.length; i++) {
      results[nutrients[i]] = prediction[i];
    }

    results = await _checkBoundaries(results);
    calculateRecommendationForEachMealPeriod();
    results = {
      ...results,
      ...?mealTargets
    };

    await FirebaseFirestore.instance
        .collection('recommendations')
        .doc(uid)
        .collection('dates')
        .doc(tomorrowDate)
        .set(results, SetOptions(merge: true));

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
    final nutrients = {'Calories', 'Protein_g', 'Carbs_g', 'Fats_g'};

    mealRatios.forEach((meal, ratio) {
      final mealValues = <String, dynamic>{};
      for (var nutrient in nutrients) {
        mealValues[nutrient] = (results[nutrient] ?? 0) * ratio;
      }
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

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        if (querySnapshot.docs.isEmpty && selectedDate.day == DateTime.now().day){
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.restaurant_menu, color: Colors.blue.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      "First Log",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ],
              ),
              content: const Text(
                "To personalize your recommendations, we need yesterday's meal data. Would you like to log it now?",
                style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      results = await _checkBoundaries({});
                      calculateRecommendationForEachMealPeriod();
                    } catch (e) {
                      return;
                    }
                    await FirebaseFirestore.instance
                        .collection('recommendations')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('dates')
                        .doc(DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
                        .set(results);
                  },
                  child: Text("Use Defaults", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    try {
                      _previousDay(false);
                    } catch (e) {
                      return;
                    }
                  },
                  child: const Text("Log Now", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (missingContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text("Missing Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: Text(
                "Yesterday's logs are incomplete:\n${missing.join(", ")}",
                style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(missingContext);
                    try {
                      results = await _checkBoundaries({});
                      setState(() {
                        calculateRecommendationForEachMealPeriod();
                      });
                    } catch (e) {
                      return;
                    }
                    results = await _checkBoundaries(results);
                    await FirebaseFirestore.instance
                        .collection('recommendations')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('dates')
                        .doc(DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
                        .set(results);
                  },
                  child: Text("Later", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(missingContext);
                    try {
                      _previousDay(false);
                    } catch (e) {
                      return;
                    }
                  },
                  child: const Text("Log Now", style: TextStyle(fontWeight: FontWeight.bold)),
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
      mealRatios = include
        ? {'Breakfast': 0.2, 'Lunch': 0.31, 'Dinner': 0.39, 'Snack': 0.10}
        : {'Breakfast': 0.22, 'Lunch': 0.33, 'Dinner': 0.45, 'Snack': 0.0};
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
      _loadWaterIntake(); // Update water for the day
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
      _loadWaterIntake(); // Update water for the day
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF42A5F5),
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
      _checkAndPromptMissingMeals(true);
      _loadRecommendationFromDatabase();
      _loadDailyIntake();
      _loadWaterIntake(); // Update water for the day
      mealTargets = null;
      _loadIncludeSnacksFromDatabase();
      results.clear();
    }
  }

  void _refreshData() {
    setState(() {});
    _loadDailyIntake();
    _loadWaterIntake();
  }
  
  Future<void> _saveAdjustedTargets(Map<String, dynamic> adjustedTargets) async {
    await FirebaseFirestore.instance
        .collection('recommendations')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('dates')
        .doc(DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
        .set(adjustedTargets, SetOptions(merge: true));
  }

  Map<String, dynamic>? _getAdjustedTargets(String mealType) {
    if (mealTargets == null) return null;

    // Create a copy to avoid mutating the original until all adjustments are done
    Map<String, Map<String, dynamic>> adjusted = {};
    mealTargets!.forEach((key, value) {
      adjusted[key] = Map<String, dynamic>.from(value);
    });

    final metrics = ['Calories', 'Protein_g', 'Carbs_g', 'Fats_g'];

    // 1. Breakfast -> Lunch
    for (var m in metrics) {
      double target = mealTargets!['Breakfast']?[m] ?? 0.0;
      double intake = _periodIntake['Breakfast']?[m] ?? 0.0;
      double diff = target - intake;
      adjusted['Lunch']?[m] = (adjusted['Lunch']![m] + diff).clamp(0.0, double.infinity);
    }

    // 2. Lunch -> Dinner
    for (var m in metrics) {
      // For lunch, we use the adjusted target to find the deviation
      double target = adjusted['Lunch']?[m] ?? 0.0;
      double intake = _periodIntake['Lunch']?[m] ?? 0.0;
      double diff = target - intake;
      adjusted['Dinner']?[m] = (adjusted['Dinner']![m] + diff).clamp(0.0, double.infinity);
    }

    // 3. Dinner -> Snack
    if (includeSnacks) {
      for (var m in metrics) {
        double target = adjusted['Dinner']?[m] ?? 0.0;
        double intake = _periodIntake['Dinner']?[m] ?? 0.0;
        double diff = target - intake;
        adjusted['Snack']?[m] = (adjusted['Snack']![m] + diff).clamp(0.0, double.infinity);
        if (diff > (adjusted['Snack']![m] - _periodIntake['Snack']![m] ?? 0.0)) {
          adjusted['Dinner']?[m] = adjusted['Snack']![m] - _periodIntake['Snack']![m];
        }
      }
    }

    for (var m in metrics) {
      if ((adjusted['Lunch']![m] - _periodIntake['Lunch']![m]) > (adjusted['Dinner']![m] - _periodIntake['Dinner']![m])) {
        adjusted['Lunch']?[m] = (adjusted['Dinner']![m] - _periodIntake['Dinner']![m]);
      }
    }

    for (var m in metrics) {
      if ((adjusted['Breakfast']![m] - _periodIntake['Breakfast']![m]) > (adjusted['Lunch']![m] - _periodIntake['Lunch']![m])) {
        adjusted['Breakfast']?[m] = (adjusted['Lunch']![m] - _periodIntake['Lunch']![m]);
      }
    }

    _saveAdjustedTargets(adjusted);
    return adjusted[mealType];
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEE, dd MMM yyyy').format(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    String dayText = selected == today
        ? 'Today'
        : selected == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : formattedDate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          // Header
          _buildHeader(dayText, today),

          Expanded(
            child: _isLoadingModel
                ? _buildLoadingState()
                : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                _buildDailyDashboard(),
                const SizedBox(height: 24),
                _buildHydrationCard(),
                const SizedBox(height: 24),
                ...mealCategories.map((mealType) {
                  // Use adjusted targets for display and logging
                  final mealTarget = _getAdjustedTargets(mealType);
                  return _buildMealSection(mealType, mealTarget);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String dayText, DateTime today) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 13, 20, 20),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutritionProgressPage())),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              _headerNavButton(Icons.chevron_left, () => _previousDay(true)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextButton(
                    onPressed: _selectDate,
                    child: Text(
                      dayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                )
              ),
              _headerNavButton(
                Icons.chevron_right,
                selectedDate.isBefore(today) ? _nextDay : null,
              ),
              const SizedBox(width: 40), // Balance the trends button
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerNavButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: onPressed != null ? Colors.white : Colors.white38, size: 28),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF42A5F5), strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            'Analyzing nutrition goals...',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDashboard() {
    if (_isLoadingIntake || _dailyIntake == null) {
      return Container(
        height: 293, //so that the container wont too small
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    double tCal = 0, tProt = 0, tCarb = 0, tFat = 0;
    if (_previousDayAvailable && mealTargets != null) {
      mealTargets!.forEach((_, t) {
        if (t.isNotEmpty) {
          tCal += t['Calories'] ?? 0;
          tProt += t['Protein_g'] ?? 0;
          tCarb += t['Carbs_g'] ?? 0;
          tFat += t['Fats_g'] ?? 0;
        }
      });
    }

    final cCal = _dailyIntake!['calories'] ?? 0;
    final cProt = _dailyIntake!['protein'] ?? 0;
    final cCarb = _dailyIntake!['carbs'] ?? 0;
    final cFat = _dailyIntake!['fats'] ?? 0;

    final calPercent = tCal > 0 ? (cCal / tCal).clamp(0.0, 1.0) : 0.0;
    final calRemaining = (tCal - cCal).clamp(0.0, tCal);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 110,
                    width: 110,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: CircularProgressIndicator(
                              value: calPercent,
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  cCal > tCal ? Colors.red.shade400 : const Color(0xFF42A5F5)
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                calRemaining.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              Text('kcal left', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Goal: ${tCal.toStringAsFixed(0)} kcal',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                  ),
                ]
              ),

              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  children: [
                    _buildCompactMacro('Protein', cProt, tProt, Colors.blue),
                    const SizedBox(height: 14),
                    _buildCompactMacro('Carbs', cCarb, tCarb, Colors.orange),
                    const SizedBox(height: 14),
                    _buildCompactMacro('Fats', cFat, tFat, Colors.green),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSnackToggle(),
        ],
      ),
    );
  }

  Widget _buildCompactMacro(String label, double current, double target, Color color) {
    final percent = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final remaining = target - current;
    final isOver = remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(
                  'Goal: ${target.toStringAsFixed(0)}g',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              isOver
                  ? '+${(-remaining).toStringAsFixed(0)}g over'
                  : '${remaining.toStringAsFixed(0)}g left',
              style: TextStyle(
                fontSize: 11,
                color: isOver ? Colors.red.shade400 : Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red.shade400 : color),
          ),
        ),
      ],
    );
  }

  Widget _buildHydrationCard() {
    if (_isLoadingIntake || _dailyIntake == null) {
      return Container(
        height: 153,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    int totalWaterIntake = _waterIntakeMl + _dailyIntake!['water']!.round(); // include water from meal
    final percent = (totalWaterIntake / _waterTargetMl).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.shade900.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.water_drop_rounded, color: Colors.blue.shade400, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Water", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text("Daily Target: ${_waterTargetMl}ml", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${totalWaterIntake.toStringAsFixed(0)}ml",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue.shade700), //smaller font
                  ),
                  Text("Balance: ${(_waterTargetMl - totalWaterIntake).toStringAsFixed(0)}ml", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ) //no need quick log
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: Colors.blue.shade50,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _showWaterLoggingDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF42A5F5).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  void _showWaterLoggingDialog() {
    final TextEditingController waterController = TextEditingController(text: "250");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Log Water Intake", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How much water did you drink?", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: waterController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount (ml)",
                suffixText: "ml",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),
            const Text("Quick Select:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [100, 250, 300, 500, 750, 1000].map((ml) => ActionChip(
                label: Text("${ml}ml"),
                backgroundColor: Colors.blue.shade50,
                labelStyle: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                onPressed: () {
                  waterController.text = ml.toString();
                },
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(waterController.text) ?? 0;
              if (amount > 0) {
                _logWater(amount);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white),
            child: const Text("Log Water"),
          ),
        ],
      ),
    );
  }

  Widget _buildSnackToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF42A5F5).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cookie_outlined, size: 18, color: Color(0xFF1E88E5)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Include Snacks in Goals",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E88E5)),
            ),
          ),
          Switch(
            value: includeSnacks,
            activeThumbColor: const Color(0xFF42A5F5),
            onChanged: (value) async {
              setState(() {
                includeSnacks = value;
                mealRatios = includeSnacks
                    ? {'Breakfast': 0.2, 'Lunch': 0.31, 'Dinner': 0.39, 'Snack': 0.1}
                    : {'Breakfast': 0.22, 'Lunch': 0.33, 'Dinner': 0.45, 'Snack': 0.0};

                calculateRecommendationForEachMealPeriod();
                saveIncludeSnacksIntoDatabase();
              });
              if (includeSnacks == false) { //if switch off then move the logged snacks to dinner
                final snacks = await mealLogs.where(
                    'mealType', isEqualTo: 'Snack').get();

                for (final doc in snacks.docs) {
                  mealLogs.doc(doc.id).update(
                      {
                        'mealType': 'Dinner',
                      }
                  );
                }
              }
            },
          ),
        ],
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
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            initiallyExpanded: expandedMeals.contains(mealType),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  expandedMeals.add(mealType);
                }
                else {
                  expandedMeals.remove(mealType);
                }
              });
            },
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
            collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getMealColor(mealType).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_getMealIcon(mealType), color: _getMealColor(mealType), size: 24),
            ),
            title: Text(
              mealType,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            subtitle: meals.isEmpty
              ? Text('Not logged', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
              : FutureBuilder<Map<String, double>>(
                  future: _calculateMealTypeNutrients(meals),
                  builder: (context, nSnapshot) {
                    if (!nSnapshot.hasData) return const Text('...');
                    final data = nSnapshot.data!;
                    return Text(
                      '${data['calories']!.toStringAsFixed(0)} kcal • P:${data['protein']!.toStringAsFixed(0)}g C:${data['carbs']!.toStringAsFixed(0)}g F:${data['fats']!.toStringAsFixed(0)}g',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    );
                  },
                ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (meals.isEmpty)
                _buildEmptyMealState()
              else
                _buildMealList(meals),
              const SizedBox(height: 16),
              _buildAddMealButton(mealType, mealTarget),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyMealState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.no_food_outlined, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text(
            "Nothing logged yet",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMealList(List<QueryDocumentSnapshot> meals) {
    return FutureBuilder(
      future: Future.wait(meals.map((m) async {
        var mealDoc = await mealsCol.doc(m['mealID']).get();
        if (!mealDoc.exists) {
          mealDoc = await customMealsCol.doc(m['mealID']).get();
        }
        return {'log': m, 'mealData': mealDoc.exists ? mealDoc.data() : {}, 'mealId': mealDoc.id};
      })),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2));
        final items = snapshot.data as List<Map<String, dynamic>>;

        return Column(
          children: items.map((item) {
            final m = item['log'];
            final mealData = item['mealData'];
            final name = mealData['name'] ?? 'Unnamed';
            final serving = m['servingSize'] ?? 0;
            final cal = (mealData['calorie'] ?? 0) * serving / 100;
            final p = (mealData['protein'] ?? 0) * serving / 100;
            final c = (mealData['carb'] ?? 0) * serving / 100;
            final f = (mealData['fat'] ?? 0) * serving / 100;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MealDetailsPage(data: mealData, mealId: item['mealId']))),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('${serving}g • ${cal.toStringAsFixed(0)} kcal', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                            onPressed: () async {
                              await mealLogs.doc(m.id).delete();
                              _refreshData();
                              regenerateTomorrowRecommendation();
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniNutrient('P', '${p.toStringAsFixed(1)}g', Colors.blue),
                          _miniNutrient('C', '${c.toStringAsFixed(1)}g', Colors.orange),
                          _miniNutrient('F', '${f.toStringAsFixed(1)}g', Colors.green),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _miniNutrient(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Center(child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color))),
        ),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildAddMealButton(String mealType, Map<String, dynamic>? mealTarget) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: (mealType == 'Snack' && !includeSnacks)
          ? null
          : () async {
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
        style: TextButton.styleFrom(
          backgroundColor: _getMealColor(mealType).withValues(alpha: 0.1),
          foregroundColor: _getMealColor(mealType),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: (mealType == 'Snack' && !includeSnacks) ? null : const Icon(Icons.add, size: 20), //no label if excluded
        label: Text((mealType == 'Snack' && !includeSnacks) ? 'Excluded' : 'Add Food', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<Map<String, double>> _calculateMealTypeNutrients(List<QueryDocumentSnapshot> meals) async {
    double calories = 0, protein = 0, carbs = 0, fats = 0;
    for (var m in meals) {
      final data = m.data() as Map<String, dynamic>;
      var mealDoc = await mealsCol.doc(data['mealID']).get();
      if (!mealDoc.exists) mealDoc = await customMealsCol.doc(data['mealID']).get();
      if (mealDoc.exists) {
        final mealData = mealDoc.data() as Map<String, dynamic>;
        final ratio = (data['servingSize'] ?? 0) / 100;
        calories += (mealData['calorie'] ?? 0) * ratio;
        protein += (mealData['protein'] ?? 0) * ratio;
        carbs += (mealData['carb'] ?? 0) * ratio;
        fats += (mealData['fat'] ?? 0) * ratio;
      }
    }
    return {'calories': calories, 'protein': protein, 'carbs': carbs, 'fats': fats};
  }

  Color _getMealColor(String type) {
    switch (type) {
      case 'Breakfast': return Colors.orange;
      case 'Lunch': return Colors.green;
      case 'Dinner': return Colors.deepPurple;
      case 'Snack': return Colors.pink;
      default: return Colors.blue;
    }
  }

  IconData _getMealIcon(String type) {
    switch (type) {
      case 'Breakfast': return Icons.wb_sunny_outlined;
      case 'Lunch': return Icons.lunch_dining_outlined;
      case 'Dinner': return Icons.dark_mode_outlined;
      case 'Snack': return Icons.cookie_outlined;
      default: return Icons.restaurant_menu;
    }
  }

  Future<Map<String, double>> _calculateDailyIntake() async {
    setState(() {
      _isLoadingModel = true;
    });
    try {
      double tCal = 0, tProt = 0, tCarb = 0, tFat = 0, tWater = 0; //add water
      Map<String, Map<String, double>> periodIntake = {
        'Breakfast': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
        'Lunch': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
        'Dinner': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
        'Snack': {'Calories': 0, 'Protein_g': 0, 'Carbs_g': 0, 'Fats_g': 0},
      };

      final query = await mealLogs
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .where('date', isEqualTo: DateFormat('EEEE, dd MMM yyyy').format(selectedDate))
          .get();

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['mealType'] ?? 'Snack';
        DocumentSnapshot mDoc = await mealsCol.doc(data['mealID']).get();
        if (!mDoc.exists) mDoc = await customMealsCol.doc(data['mealID']).get();
        if (mDoc.exists) {
          final mData = mDoc.data() as Map<String, dynamic>;
          final ratio = (data['servingSize'] ?? 0) / 100;
          double c = (mData['calorie'] ?? 0) * ratio;
          double p = (mData['protein'] ?? 0) * ratio;
          double carb = (mData['carb'] ?? 0) * ratio;
          double f = (mData['fat'] ?? 0) * ratio;
          double w = (mData['water'] ?? 0) * ratio; //add water intake
          
          tCal += c; tProt += p; tCarb += carb; tFat += f; tWater += w;
          
          if (periodIntake.containsKey(type)) {
            periodIntake[type]!['Calories'] = (periodIntake[type]!['Calories'] ?? 0) + c;
            periodIntake[type]!['Protein_g'] = (periodIntake[type]!['Protein_g'] ?? 0) + p;
            periodIntake[type]!['Carbs_g'] = (periodIntake[type]!['Carbs_g'] ?? 0) + carb;
            periodIntake[type]!['Fats_g'] = (periodIntake[type]!['Fats_g'] ?? 0) + f;
          }
        }
      }
      
      setState(() {
        _periodIntake = periodIntake;
        _isLoadingModel = false;
      });
      return {'calories': tCal, 'protein': tProt, 'carbs': tCarb, 'fats': tFat, 'water': tWater}; // add water
    } catch (e) {
      return {'calories': 0, 'protein': 0, 'carbs': 0, 'fats': 0, 'water': 0}; // add water
    }
  }
}
