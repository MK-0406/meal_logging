import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:meal_logging/main.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
  bool _previousDayAvailable = true;
  bool includeSnacks = true;
  bool includeSnacksFromDatabase = false;
  late DocumentSnapshot diaryDoc;

  late var results = <String, dynamic>{};

  late var mealRatios = {'Breakfast': 0.2, 'Lunch': 0.3, 'Dinner': 0.3, 'Snack': 0.2};

  final CollectionReference userInfo = FirebaseFirestore.instance.collection('usersInfo');
  final CollectionReference mealLogs = FirebaseFirestore.instance.collection('mealLogs');
  final CollectionReference mealsCol = FirebaseFirestore.instance.collection('meals');

  final List<String> mealCategories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  final Set<String> expandedMeals = {};

  @override
  void initState() {
    super.initState();
    _runMLModel(true);
    _loadDailyIntake();
    _loadIncludeSnacksFromDatabase();
  }

  Future<void> _loadDailyIntake() async {
    setState(() => _isLoadingIntake = true);
    final intake = await _calculateDailyIntake();
    setState(() {
      _dailyIntake = intake;
      _isLoadingIntake = false;
    });
  }

   /*Future<void> _runMLModel(bool needChecking) async {
    try {
      setState(() {
        _isLoadingModel = true; _previousDayAvailable = true;
      });
      final model = await FirebaseModelDownloader.instance.getModel(
        "meal_recommender2",
        FirebaseModelDownloadType.latestModel,
      );
      final interpreter = Interpreter.fromFile(model.file);
      final userDetails = await Database.getDocument('usersInfo', null);
      final userData = userDetails.data() as Map<String, dynamic>;

      final List<Map<String, dynamic>> mealData = await Database.getItemsWithConditions(
        'mealLogs', 'uid',
        conditions: {
          'date': DateFormat('EEEE, dd MMM yyyy').format(selectedDate.subtract(const Duration(days: 1))),
        },
      );

      double proteinIntake = 0, carbsIntake = 0, fatsIntake = 0;
      bool hasBreakfast = false, hasLunch = false, hasDinner = false;

      for (final data in mealData) {
        final mealType = data['mealType'];
        if (mealType == 'Breakfast') hasBreakfast = true;
        if (mealType == 'Lunch') hasLunch = true;
        if (mealType == 'Dinner') hasDinner = true;
        final mealDoc = await Database.getDocument('meals', data['mealID']);
        final mealDataMap = mealDoc.data() as Map<String, dynamic>;
        double ratio = data['servingSize'] / 100;
        proteinIntake += mealDataMap['protein'] * ratio;
        carbsIntake += mealDataMap['carb'] * ratio;
        fatsIntake += mealDataMap['fat'] * ratio;
      }

      if (needChecking) _checkAndPromptMissingMeals(hasBreakfast, hasLunch, hasDinner);

      if (mealData.isNotEmpty){
        final input = [[
          userData['age'],
          userData['height_m'] * 100,
          userData['weight_kg'],
          userData['bmi'],
          userData['bloodPressureSystolic'],
          userData['bloodPressureDiastolic'],
          userData['cholesterol_mgdL'],
          userData['bloodSugar_mgdL'],
          proteinIntake,
          carbsIntake,
          fatsIntake
        ]];

        final output = List.filled(3, 0.0).reshape([1, 3]);
        interpreter.run(input, output);
        final preds = output[0];

        final nutrients = ['Protein_g', 'Carbs_g', 'Fats_g'];
        final margins = [0.30, 0.46, 0.48];

        final results = <String, dynamic>{};
        for (int i = 0; i < nutrients.length; i++) {
          results[nutrients[i]] = {
            'pred': (preds[i]).toInt(),
            'low': (preds[i] * (1 - margins[i])).toInt(),
            'high': (preds[i] * (1 + margins[i])).toInt(),
          };
        }

        results['Calories'] = {
          'pred': 4 * (preds[0].toInt() + preds[1].toInt()) + (9 * preds[2].toInt()),
          'low': (4 * (preds[0].toInt() + preds[1].toInt()) + (9 * preds[2].toInt())) * (1-0.23),
          'high': (4 * (preds[0].toInt() + preds[1].toInt()) + (9 * preds[2].toInt())) * (1+0.23),
        };

        final mealRatios = {'Breakfast': 0.2, 'Lunch': 0.3, 'Dinner': 0.3, 'Snack': 0.2};
        final targets = <String, Map<String, dynamic>>{};
        mealRatios.forEach((meal, ratio) {
          final mealValues = <String, dynamic>{};
          results.forEach((nutrient, data) {
            mealValues[nutrient] = {
              'low': data['low'] * ratio,
              'pred': data['pred'] * ratio,
              'high': data['high'] * ratio,
            };
          });
          targets[meal] = mealValues;
        });

        //interpreter.close();
        setState(() {
          mealTargets = targets;
          _isLoadingModel = false;
        });
      } else {
        //interpreter.close();
        _previousDayAvailable = false;
        setState(() {
          _isLoadingModel = false;
        });
      }

    } catch (e) {
      console.log('ML Model Error: $e');
      setState(() => _isLoadingModel = false);
    }
  }*/

  Future<void> _runMLModel(bool needChecking) async {
    try {
      setState(() {
        _isLoadingModel = true;
        _previousDayAvailable = true;
      });

      // Fetch user data
      final userDetails = await Database.getDocument('usersInfo', null);
      final userData = userDetails.data() as Map<String, dynamic>;

      print('here 1');

      // Fetch yesterday's meal data
      final List<Map<String, dynamic>> mealData = await Database.getItemsWithConditions(
        'mealLogs', 'uid',
        conditions: {
          'date': DateFormat('EEEE, dd MMM yyyy')
              .format(selectedDate.subtract(const Duration(days: 1))),
        },
      );

      double proteinIntake = 0, carbsIntake = 0, fatsIntake = 0;
      bool hasBreakfast = false, hasLunch = false, hasDinner = false;

      for (final data in mealData) {
        final mealType = data['mealType'];
        if (mealType == 'Breakfast') hasBreakfast = true;
        if (mealType == 'Lunch') hasLunch = true;
        if (mealType == 'Dinner') hasDinner = true;

        final mealDoc = await Database.getDocument('meals', data['mealID']);
        final mealDataMap = mealDoc.data() as Map<String, dynamic>;

        double ratio = data['servingSize'] / 100;
        proteinIntake += mealDataMap['protein'] * ratio;
        carbsIntake += mealDataMap['carb'] * ratio;
        fatsIntake += mealDataMap['fat'] * ratio;
      }

      if (needChecking) {
        _checkAndPromptMissingMeals(hasBreakfast, hasLunch, hasDinner);
      }

      if (mealData.isEmpty) {
        _previousDayAvailable = false;
        setState(() => _isLoadingModel = false);
        return;
      }

      print(mealData);

      final url = Uri.parse("https://meal-recommender-model.onrender.com/predict");

      final bodyData = {
        "features": [
          userData['age'].toDouble(),
          (userData['height_m'] * 100).toDouble(),
          userData['weight_kg'].toDouble(),
          userData['bmi'].toDouble(),
          userData['bloodPressureSystolic'].toDouble(),
          userData['bloodPressureDiastolic'].toDouble(),
          userData['cholesterol_mmolL'].toDouble(),
          userData['bloodSugar_mmolL'].toDouble(),
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

      if (response.statusCode != 200) {
        setState(() => _isLoadingModel = false);
        return;
      }

      final data = jsonDecode(response.body);
      final prediction = data['prediction'] as List<dynamic>;
      final preds = prediction[0];

      // ✅ Same calculation logic as before
      final nutrients = ['Protein_g', 'Carbs_g', 'Fats_g'];
      final margins = [0.30, 0.46, 0.48];

      //final results = <String, dynamic>{};
      for (int i = 0; i < nutrients.length; i++) {
        results[nutrients[i]] = {
          'pred': preds[i].round(),
          'low': (preds[i] * (1 - margins[i])).round(),
          'high': (preds[i] * (1 + margins[i])).round(),
        };
      }

      results['Calories'] = {
        'pred': (4 * (preds[0] + preds[1]) + (9 * preds[2])).round(),
        'low': (4 * (preds[0] + preds[1]) + (9 * preds[2])) * (1 - 0.23),
        'high': (4 * (preds[0] + preds[1]) + (9 * preds[2])) * (1 + 0.23),
      };

      print(results);
      calculateRecommendationForEachMealPeriod();

    } catch (e) {
      print('ML API Error: $e');
      setState(() => _isLoadingModel = false);
    }
  }

  void calculateRecommendationForEachMealPeriod(){
    //final mealRatios = {'Breakfast': 0.2, 'Lunch': 0.3, 'Dinner': 0.3, 'Snack': 0.2};
    final targets = <String, Map<String, dynamic>>{};

    mealRatios.forEach((meal, ratio) {
      final mealValues = <String, dynamic>{};
      results.forEach((nutrient, data) {
        mealValues[nutrient] = {
          'low': data['low'] * ratio,
          'pred': data['pred'] * ratio,
          'high': data['high'] * ratio,
        };
      });
      targets[meal] = mealValues;
    });

    print(targets);

    setState(() {
      mealTargets = targets;
      _isLoadingModel = false;
    });
  }

  Future<void> _checkAndPromptMissingMeals(bool hasBreakfast, bool hasLunch, bool hasDinner) async {
    final missing = <String>[];
    if (!hasBreakfast) missing.add('Breakfast');
    if (!hasLunch) missing.add('Lunch');
    if (!hasDinner) missing.add('Dinner');
    if (missing.isEmpty) return;

    final querySnapshot = await FirebaseFirestore.instance.collection('mealLogs')
    .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid).get();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        if (querySnapshot.docs.isEmpty && selectedDate.day == DateTime.now().day){
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("First Time Logging Meals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              content: Text("To generate accurate meal recommendations, we need your meals from yesterday.\n"
                  "Would you like to log yesterday’s meals now or use common intakes instead?",
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      results = {'Calories': 2000, 'Protein_g': 130, 'Carbs_g': 250, 'Fats_g': 90};
                      mealTargets = {
                        'Breakfast': {'Calories': {'pred': 2000 * 0.2}, 'Protein_g': {'pred': 130 * 0.2}, 'Carbs_g': {'pred': 250 * 0.2}, 'Fats_g': {'pred': 90 * 0.2}},
                        'Lunch': {'Calories': {'pred': 2000 * 0.3}, 'Protein_g': {'pred': 130 * 0.3}, 'Carbs_g': {'pred': 250 * 0.3}, 'Fats_g': {'pred': 90 * 0.3}},
                        'Dinner': {'Calories': {'pred': 2000 * 0.3}, 'Protein_g': {'pred': 130 * 0.3}, 'Carbs_g': {'pred': 250 * 0.3}, 'Fats_g': {'pred': 90 * 0.3}},
                        'Snack': {'Calories': {'pred': 2000 * 0.2}, 'Protein_g': {'pred': 130 * 0.2}, 'Carbs_g': {'pred': 250 * 0.2}, 'Fats_g': {'pred': 90 * 0.2}},
                      };
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Use Default", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF009688)),
                  onPressed: () {
                    Navigator.pop(context);
                    _previousDay(false);
                  },
                  child: const Text("Log Now", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) =>
                AlertDialog(
                  title: const Text("Missing Meals", style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Text(
                      "You haven't logged these meals for yesterday:\n${missing
                          .join(", ")}"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                          "Later", style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _previousDay(false);
                      },
                      child: const Text(
                          "Log Now", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
          );
        }
      }

    });
  }

  Future<void> saveIncludeSnacksIntoDatabase() async {
    print(includeSnacksFromDatabase);
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
    print(doc.docs.isNotEmpty);
    if (doc.docs.isNotEmpty) {
      diaryDoc = doc.docs.first;
      final data = diaryDoc.data() as Map<String, dynamic>;
      include = (data['includeSnacks'] == null)
          ? true
          : data['includeSnacks'];
      print('include $include');
      includeSnacksFromDatabase =
      (data['includeSnacks'] == null) ? false : true;
    } else {
      includeSnacksFromDatabase = false;
    }
    setState(() {
      includeSnacks = include;
    });
  }

  void _previousDay(bool needChecking) {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      _runMLModel(needChecking);
      _loadDailyIntake();
      mealTargets = null;
      _loadIncludeSnacksFromDatabase();
    });
  }

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
      _runMLModel(true);
      mealTargets = null;
      _loadDailyIntake();
      _loadIncludeSnacksFromDatabase();
    });
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _runMLModel(true);
      _loadDailyIntake();
      mealTargets = null;
      _loadIncludeSnacksFromDatabase();
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
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Date
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
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _selectDate,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            day.isNotEmpty ? day : formattedDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Navigation Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _previousDay(true),
                          icon: const Icon(Icons.arrow_back_ios, size: 14),
                          label: const Text('Previous'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: lightBlueTheme.colorScheme.secondary,
                            elevation: 2,
                            padding: EdgeInsets.symmetric(vertical: 11, horizontal: 25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: selectedDate.isBefore(today) ? _nextDay : null,
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          label: const Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: lightBlueTheme.colorScheme.secondary,
                            elevation: 2,
                            padding: EdgeInsets.symmetric(vertical: 11, horizontal: 25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ],
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
                      CircularProgressIndicator(color: lightBlueTheme.colorScheme.secondary),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing your nutrition...',
                        style: TextStyle(color: lightBlueTheme.colorScheme.secondary, fontSize: 16),
                      ),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Daily Summary Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insights, color: lightBlueTheme.colorScheme.secondary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  "Daily Nutrition",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: lightBlueTheme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                child: _buildNutrientSummary()),
                            ),
                            const SizedBox(height: 14),

                            // Today's Progress Section
                            if (_isLoadingIntake)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(color: lightBlueTheme.colorScheme.secondary),
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

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Include Snacks for Recommendation",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: lightBlueTheme.colorScheme.secondary,
                                      ),
                                  ),
                                ),
                                Checkbox(
                                  value: includeSnacks,
                                  onChanged: (value) {
                                    setState(() {
                                      includeSnacks = value!;
                                      mealRatios = includeSnacks ? {'Breakfast': 0.2, 'Lunch': 0.3, 'Dinner': 0.3, 'Snack': 0.2} : {'Breakfast': 0.3, 'Lunch': 0.4, 'Dinner': 0.3, 'Snack': 0.0};
                                      calculateRecommendationForEachMealPeriod();
                                      saveIncludeSnacksIntoDatabase();
                                    });
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Meal Sections
                    ...mealCategories.map((mealType) {
                      final mealTarget = mealTargets?[mealType];
                      return _buildMealSection(mealType, mealTarget);
                    }),
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

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lightBlueTheme.colorScheme.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,

                ),
                child: Icon(
                  _getMealIcon(mealType),
                  color: lightBlueTheme.colorScheme.secondary,
                  size: 24,
                ),
              ),
              title: Text(
                mealType,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                '${meals.length} meal${meals.length != 1 ? 's' : ''} logged',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: lightBlueTheme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  expandedMeals.contains(mealType) ? Icons.expand_less : Icons.expand_more,
                  color: lightBlueTheme.colorScheme.secondary,
                ),
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                if (meals.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.fastfood_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          "No meals logged yet",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start by adding your first meal!",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...meals.map((m) {
                    final mealName = m['mealName'] ?? 'Unnamed Meal';
                    final servingSize = m['servingSize'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: lightBlueTheme.colorScheme.secondary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.restaurant_menu, color: lightBlueTheme.colorScheme.secondary, size: 20),
                        ),
                        title: Text(
                          mealName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Serving: ${servingSize}g',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                await mealLogs.doc(m.id).delete();
                                _refreshData();
                              },
                            ),
                          ],
                        ),
                        onTap: () async {
                          final mealDoc = await mealsCol.doc(m['mealID']).get();
                          if (mealDoc.exists) {
                            final mealData = mealDoc.data() as Map<String, dynamic>;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MealDetailsPage(data: mealData),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }),

                const SizedBox(height: 8),
                ElevatedButton.icon(
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
                  },
                  style: ElevatedButton.styleFrom(
                    //backgroundColor: lightBlueTheme.colorScheme.secondary,
                    //foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 26),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Meal', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          )
        );
      },
    );
  }

  Widget _buildNutrientSummary() {
    print(' hrere $mealTargets');
    if (mealTargets == null || _previousDayAvailable == false) return const SizedBox.shrink();
    double totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFats = 0;
    print('here a');
    mealTargets!.forEach((_, t) {
      totalCal += t['Calories']['pred'];
      totalProtein += t['Protein_g']['pred'];
      totalCarbs += t['Carbs_g']['pred'];
      totalFats += t['Fats_g']['pred'];
    });

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildNutrientCard('🔥 Calories', '${totalCal.toStringAsFixed(0)} kcal', Colors.orange),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNutrientCard('🥩 Protein', '${totalProtein.toStringAsFixed(0)} g', Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildNutrientCard('🍞 Carbs', '${totalCarbs.toStringAsFixed(0)} g', Colors.brown),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNutrientCard('🥑 Fats', '${totalFats.toStringAsFixed(0)} g', Colors.green),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutrientCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, double>> _calculateDailyIntake() async {
    try {
      double totalCalIntake = 0, totalProteinIntake = 0, totalCarbsIntake = 0, totalFatsIntake = 0;

      final QuerySnapshot mealDataQuery = await mealLogs
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .where(
        'date',
        isEqualTo: DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
      )
          .get();

      for (final doc in mealDataQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final DocumentSnapshot mealQuery = await mealsCol.doc(data['mealID']).get();
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
      print('Error calculating daily intake: $e');
      return {'calories': 0, 'protein': 0, 'carbs': 0, 'fats': 0};
    }
  }

  Widget _buildIntakeComparison(
      double totalCalIntake,
      double totalProteinIntake,
      double totalCarbsIntake,
      double totalFatsIntake,
      ) {
    //if (mealTargets == null) return const SizedBox.shrink();

    double totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFats = 0;
    if (_previousDayAvailable && mealTargets != null) {
      mealTargets!.forEach((meal, targets) {
        totalCal += targets['Calories']['pred'];
        totalProtein += targets['Protein_g']['pred'];
        totalCarbs += targets['Carbs_g']['pred'];
        totalFats += targets['Fats_g']['pred'];
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Progress',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: lightBlueTheme.colorScheme.secondary),
        ),
        const SizedBox(height: 12),
        _buildProgressRow('🔥 Calories', totalCalIntake, totalCal, 'kcal', Colors.orange),
        const SizedBox(height: 10),
        _buildProgressRow('🥩 Protein', totalProteinIntake, totalProtein, 'g', Colors.red),
        const SizedBox(height: 10),
        _buildProgressRow('🍞 Carbs', totalCarbsIntake, totalCarbs, 'g', Colors.brown),
        const SizedBox(height: 10),
        _buildProgressRow('🥑 Fats', totalFatsIntake, totalFats, 'g', Colors.green),
      ],
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              '${actual.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isOver ? Colors.red : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red : color),
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}% of target',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
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