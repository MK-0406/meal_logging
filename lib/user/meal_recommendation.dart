import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:meal_logging/main.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../custom_styles.dart';
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
  String status = "Running model...";
  Map<String, dynamic>? result;
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
      setState(() {
        _isLoading = true;
        recommendedMeals.clear();
      });

      // 🔹 If targets are passed from diary page, use them directly
      if (widget.nutritionalTargets != null) {
        final t = widget.nutritionalTargets!;
        final meals = await _queryMeals(
          (widget.mealType! == 'Lunch' || widget.mealType == 'Dinner') ? 'Lunch / Dinner' : widget.mealType!,
          t['Calories'],
          t['Carbs_g'],
          t['Protein_g'],
          t['Fats_g'],
        );
        recommendedMeals.addAll(meals);
      } else {
        // 🔹 Fallback: Run ML model if no targets passed
        /*final model = await FirebaseModelDownloader.instance.getModel(
          "meal_recommender",
          FirebaseModelDownloadType.latestModel,
        );*/

        final interpreter = await Interpreter.fromAsset('meal_recommender-2.tflite');

        final input = [
          [19, 179, 68, 21.22, 155, 107, 255, 110, 3324, 197, 214, 97],
        ];

        final output = List.filled(4, 0.0).reshape([1, 4]);
        interpreter.run(input, output);

        final nutrients = ['Calories', 'Protein_g', 'Carbs_g', 'Fats_g'];
        final preds = output[0];
        final margins = [0.12, 0.14, 0.27, 0.25];
        final Map<String, dynamic> results = {};

        for (int i = 0; i < nutrients.length; i++) {
          final val = preds[i];
          final low = val * (1 - margins[i]);
          final high = val * (1 + margins[i]);
          results[nutrients[i]] = {'pred': val, 'low': low, 'high': high};
        }

        final mealRatios = {'Breakfast': 0.3, 'Lunch': 0.4, 'Dinner': 0.3};
        final mealTargets = <String, Map<String, dynamic>>{};

        mealRatios.forEach((meal, ratio) {
          final mealValues = <String, dynamic>{};
          results.forEach((nutrient, data) {
            mealValues[nutrient] = {
              'low': data['low'] * ratio,
              'pred': data['pred'] * ratio,
              'high': data['high'] * ratio,
            };
          });
          mealTargets[meal] = mealValues;
        });

        for (final meal in mealTargets.keys) {
          final t = mealTargets[meal]!;
          final meals = await _queryMeals(
            meal,
            t['Calories']['pred'],
            t['Carbs_g']['pred'],
            t['Protein_g']['pred'],
            t['Fats_g']['pred'],
          );
          recommendedMeals.addAll(meals);
        }

        interpreter.close();
      }

      // 🔹 Shuffle the recommended meals for variety
      recommendedMeals.shuffle(Random());

      setState(() {
        _isLoading = false;
        status = "Recommendations ready!";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        status = "Error: $e";
      });
    }
  }

  Future<List<Map<String, dynamic>>> _queryMeals(
      String mealType,
      double calHigh,
      double carbHigh,
      double proteinHigh,
      double fatHigh,
      ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('meals')
        .where('calorie', isLessThanOrEqualTo: calHigh)
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .where(
          (meal) =>
      meal['protein'] <= proteinHigh &&
          meal['carb'] <= carbHigh &&
          meal['fat'] <= fatHigh &&
          meal['foodCategory'] == mealType ||
          meal['foodCategory'] == 'Anytime',
    )
        .toList();
  }

  Future<void> _logMeal(
      String mealID, String mealName, String mealType, String uid, String logDate, Map<String, dynamic> mealNutrients, {List<dynamic>? servings}) async {
    String? selectedServingName;
    await showDialog(
        context: context,
        builder: (logContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text(
                  'Log $mealName',
                  style: const TextStyle(
                    //color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: _logFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter serving size for $mealName',
                          style: TextStyle(color: Colors.grey[700]),
                        ),

                        const SizedBox(height: 15),

                        // Serving Options Dropdown
                        if (servings != null && servings.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                hint: const Text('Select Serving Option'),
                                value: selectedServingName,
                                items: servings.map<DropdownMenuItem<String>>((
                                    item) {
                                  return DropdownMenuItem<String>(
                                    value: item['name'],
                                    child: Text(
                                        "${item['name']} (${item['grams']}g)"),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedServingName = value;

                                    // Autofill the grams into text field
                                    final selected = servings.firstWhere(
                                          (s) => s['name'] == value,
                                    );
                                    _sizeController.text =
                                        selected['grams'].toString();
                                  });
                                },
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                        InputTextField(label: 'Serving Size (g)',
                            controller: _sizeController,
                            isNumber: true,
                            isInt: false),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(logContext);
                      _sizeController.text = '100';
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      //backgroundColor: Colors.deepOrange,
                      /*shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),*/
                    ),
                    onPressed: () async {
                      if (_logFormKey.currentState!.validate()) {
                        final servingSize = double.parse(_sizeController.text);

                        // Debug: Print the values
                        print('🔍 Checking meal exceedance...');
                        print('🔍 Serving Size: $servingSize');
                        print('🔍 Meal Nutrients: $mealNutrients');
                        print('🔍 Nutritional Targets: ${widget
                            .nutritionalTargets}');
                        print('🔍 Meal Type: ${widget.mealType}');

                        // Check if meal exceeds recommendations
                        final exceedsRecommendation = _checkIfMealExceedsTarget(
                            mealNutrients,
                            servingSize,
                            widget.nutritionalTargets
                        );

                        print('🔍 Exceed Result: $exceedsRecommendation');

                        if (exceedsRecommendation['exceeds']) {
                          print('🔍 Showing exceed dialog...');
                          // Show confirmation dialog instead of blocking
                          await _showExceedConfirmationDialog(
                              logContext,
                              exceedsRecommendation,
                              mealName,
                              servingSize,
                              mealID,
                              uid,
                              logDate
                          );
                        } else {
                          print('🔍 No exceedance, adding directly...');
                          await _addMealToLog(
                              mealID, mealName, uid, logDate, logContext);
                        }
                      }
                    },
                    child: const Text(
                      'Add to Diary',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            }
        )
    );
  }

  Map<String, dynamic> _checkIfMealExceedsTarget(
      Map<String, dynamic> mealNutrients,
      double servingSize,
      Map<String, dynamic>? targets
      ) {
    print('🔍 _checkIfMealExceedsTarget called');
    print('🔍 Targets structure: $targets');

    if (targets == null) {
      print('🔍 No targets provided');
      return {'exceeds': false, 'exceedingNutrients': []};
    }

    final nutrients = ['Calories', 'Protein_g', 'Carbs_g', 'Fats_g'];
    final exceedingNutrients = <Map<String, dynamic>>[];
    bool exceeds = false;

    for (String nutrient in nutrients) {
      // Safely get meal nutrient value (per 100g)
      Map<String, dynamic> mealTargetNutrients = {
        'Calories': mealNutrients['calorie'],
        'Protein_g': mealNutrients['protein'],
        'Carbs_g': mealNutrients['carb'],
        'Fats_g': mealNutrients['fat'],
      };
      final dynamic mealValue = mealTargetNutrients[nutrient];
      final double mealAmountPer100g = (mealValue is num ? mealValue.toDouble() : 0.0);

      // Calculate actual meal amount based on serving size
      final double actualMealAmount = mealAmountPer100g * servingSize / 100.0;

      // Safely get target value (this should be the total target for the meal)
      final dynamic targetValue = targets[nutrient];
      final double targetAmount = targetValue is num ? targetValue.toDouble() : 0.0;

      print('🔍 $nutrient - Meal per 100g: $mealAmountPer100g');
      print('🔍 $nutrient - Actual Meal Amount: $actualMealAmount');
      print('🔍 $nutrient - Target Amount: $targetAmount');

      if (actualMealAmount > targetAmount && targetAmount > 0) {
        exceeds = true;
        exceedingNutrients.add({
          'name': nutrient,
          'mealAmount': actualMealAmount,
          'targetAmount': targetAmount,
        });
        print('🔍 $nutrient EXCEEDS target!');
      }
    }

    final result = {
      'exceeds': exceeds,
      'exceedingNutrients': exceedingNutrients,
    };

    print('🔍 Final result: $result');
    return result;
  }

  // Show confirmation dialog when meal exceeds recommendations
  Future<void> _showExceedConfirmationDialog(
      BuildContext context,
      Map<String, dynamic> exceedsNutrients,
      String mealName,
      double servingSize,
      String mealID, String uid, String logDate,
      ) async {
    final nutrientNames = {
      'Calories': 'Calories',
      'Protein_g': 'Protein',
      'Carbs_g': 'Carbohydrates',
      'Fats_g': 'Fats',
    };

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: lightBlueTheme.colorScheme.secondary),
            const SizedBox(width: 8),
            Text('Exceeds Recommendation', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This meal exceeds your recommended intake for:'),
            const SizedBox(height: 8),
            ...exceedsNutrients['exceedingNutrients'].map<Widget>((nutrient) =>
                Text(
                    '• ${nutrientNames[nutrient['name']]} '
                        '(${nutrient['mealAmount'].toStringAsFixed(1)}g / '
                        '${nutrient['targetAmount'].toStringAsFixed(1)}g)',
                    style: const TextStyle(fontWeight: FontWeight.w500)
                )
            ).toList(),
            const SizedBox(height: 12),
            const Text('Do you want to add it anyway?', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Pop exceed dialog
              Navigator.pop(context); // Pop log dialog
              _addMealToLog(mealID, mealName, uid, logDate, context);
            },
            style: ElevatedButton.styleFrom(
              //backgroundColor: Colors.orange,
              //foregroundColor: Colors.white,
            ),
            child: const Text('Add Anyway'),
          ),
        ],
      ),
    );
  }

  // Method to add meal to log
  Future<void> _addMealToLog(String mealID, String mealName, String uid, String logDate, BuildContext logContext) async {
    if (_logFormKey.currentState!.validate()) {
      final servingSize = double.parse(_sizeController.text);

      await Database.addItems('mealLogs', {
        'uid': uid,
        'mealID': mealID,
        'mealType': widget.mealType,
        'mealName': mealName,
        'date': logDate,
        'servingSize': servingSize,
      });

      _sizeController.text = '100';
      Navigator.pop(logContext); // Pop the log dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mealName added to ${widget.mealType}'),
          backgroundColor: lightBlueTheme.colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: lightBlueTheme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Finding perfect meals for you...',
                style: TextStyle(
                  color: lightBlueTheme.colorScheme.secondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (recommendedMeals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No recommendations found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8)
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: min(recommendedMeals.length, 5),
      itemBuilder: (context, index) {
        final data = recommendedMeals[index];
        if (data['name'] == null) {
          return const SizedBox.shrink();
        }

        final name = data['name'] ?? 'Unnamed meal';
        final calorie = data['calorie']?.toString() ?? '-';
        final protein = data['protein']?.toStringAsFixed(1) ?? '-';
        final carbs = data['carb']?.toStringAsFixed(1) ?? '-';
        final fats = data['fat']?.toStringAsFixed(1) ?? '-';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: lightBlueTheme.colorScheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu, color: lightBlueTheme.colorScheme.secondary),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$calorie kcal'),
                /*const SizedBox(height: 2),
                Text(
                  'P: ${protein}g | C: ${carbs}g | F: ${fats}g',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),*/
              ],
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: lightBlueTheme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () async {
                  try {
                    final mealSnapshot = await FirebaseFirestore.instance
                        .collection('meals')
                        .where('name', isEqualTo: data['name'])
                        .limit(1)
                        .get();

                    if (mealSnapshot.docs.isNotEmpty) {
                      final doc = mealSnapshot.docs.first;
                      final mealID = doc.id;
                      final mealType = data['foodCategory'] ?? 'Unknown';
                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      final logDate = widget.logDate;

                      await _logMeal(mealID, name, mealType, uid, logDate, data, servings: data['servings'] ?? []);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Meal not found in database'),
                          backgroundColor: lightBlueTheme.colorScheme.secondary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging meal: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MealDetailsPage(data: data),
                ),
              );
            },
          ),
        );
      },
    );
  }
}