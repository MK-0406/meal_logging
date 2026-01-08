import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_logging/main.dart';
import 'meal_details.dart';
import 'meal_recommendation.dart';
import 'custom_meal.dart';
import '../functions.dart';
import '../custom_styles.dart';

class MealLogPage extends StatefulWidget {
  final String mealType;
  final String logDate;
  final Map<String, dynamic>? nutritionalTargets;

  const MealLogPage({
    super.key,
    required this.mealType,
    required this.logDate,
    this.nutritionalTargets,
  });

  @override
  State<MealLogPage> createState() => _MealLogPageState();
}

class _MealLogPageState extends State<MealLogPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allMeals = [];
  List<QueryDocumentSnapshot> _allRandomMeals = [];
  List<QueryDocumentSnapshot> _allCustomMeals = [];
  List<QueryDocumentSnapshot> _displayedMeals = [];
  List<QueryDocumentSnapshot> _customMeals = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController _sizeController = TextEditingController();
  final _logFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadRandomMeals();
    _loadCustomMeals();
    _sizeController.text = '100';
  }

  Future<void> _loadCustomMeals() async {
    setState(() => _isLoading = true);
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('custom_meal').doc(FirebaseAuth.instance.currentUser!.uid).collection('meals').get();
    _allCustomMeals = snapshot.docs;

      if (_allCustomMeals.isNotEmpty) {
        var shuffled = List<QueryDocumentSnapshot>.from(_allCustomMeals)..shuffle(Random());
        _customMeals = shuffled
            .where((meal) =>
            (meal['foodCategory'] ?? '').toString().contains(widget.mealType)
            || (meal['foodCategory'] ?? '').toString().contains('Anytime')
        ).take(5).toList();
      } else {
        _customMeals = [];
      }
      print(_allCustomMeals);
    setState(() => _isLoading = false);
  }

  Future<void> _loadRandomMeals() async {
    setState(() => _isLoading = true);
    final snapshot = await Database.getSnapshotNoOrder('meals');
    _allRandomMeals = snapshot.docs;

    if (_allRandomMeals.isNotEmpty) {
      _allRandomMeals.shuffle(Random());
      _displayedMeals = _allRandomMeals
          .where((meal) =>
          (meal['foodCategory'] ?? '').toString().contains(widget.mealType)
          || (meal['foodCategory'] ?? '').toString().contains('Anytime')
      ).take(5).toList();
    }

    setState(() => _isLoading = false);
  }

  void _searchMeals(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.isEmpty) {
      setState(() {
        _isSearching = false;
        _displayedMeals = _allMeals.take(10).toList();
      });
    } else {
      setState(() {
        _isSearching = true;
        _allMeals = [
          ..._allRandomMeals,
          ..._allCustomMeals,
        ];
        _displayedMeals = _allMeals
            .where((meal) =>
            (meal['name'] ?? '').toString().toLowerCase().contains(lowerQuery))
            .toList();
      });
    }
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
              // Header
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Log ${widget.mealType}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.logDate,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: "Randomize meals",
                      onPressed: () {
                        _loadRandomMeals;
                        _loadCustomMeals();
                      }
                    ),
                  ],
                ),
              ),

              // Nutritional Targets Display
              if (widget.nutritionalTargets != null && widget.nutritionalTargets![widget.mealType] != null) ...[
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Targets for ${widget.mealType}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            //color: Colors.deepOrange,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Calories: ${widget.nutritionalTargets?[widget.mealType]?['Calories']?.toStringAsFixed(1) ?? 'N/A'} kcal'),
                        Text('Protein: ${widget.nutritionalTargets?[widget.mealType]?['Protein_g']?.toStringAsFixed(1) ?? 'N/A'} g'),
                        Text('Carbs: ${widget.nutritionalTargets?[widget.mealType]?['Carbs_g']?.toStringAsFixed(1) ?? 'N/A'} g'),
                        Text('Fats: ${widget.nutritionalTargets?[widget.mealType]?['Fats_g']?.toStringAsFixed(1) ?? 'N/A'} g'),
                      ],
                    ),
                  ),
                ),
              ],

              Expanded(
                child: _isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: lightBlueTheme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Loading meals...',
                        style: TextStyle(color: lightBlueTheme.colorScheme.primary, fontSize: 16),
                      ),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // 🔍 Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search, color: lightBlueTheme.colorScheme.primary),
                          hintText: 'Search for meals...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: _isSearching
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchMeals('');
                            },
                          )
                              : null,
                        ),
                        onChanged: _searchMeals,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Show different content based on search state
                    if (_isSearching) ...[
                      // 🔎 Search Results section
                      _buildSectionHeader(
                        title: "Search Results",
                        subtitle: _displayedMeals.isEmpty
                            ? "No meals found"
                            : "${_displayedMeals.length} meal${_displayedMeals.length != 1 ? 's' : ''} found",
                      ),
                      const SizedBox(height: 12),

                      _displayedMeals.isEmpty
                          ? _buildEmptyState(
                        icon: Icons.search_off,
                        message: 'No meals found matching your search',
                        subtitle: 'Try different keywords',
                      )
                          : _buildMealList(_displayedMeals),
                    ] else ...[
                      // 🥗 Recommended Meals section
                      _buildSectionHeader(
                        title: "Recommended For You",
                        subtitle: "Based on your health condition",
                      ),
                      const SizedBox(height: 12),
                      MealRecommender(
                        nutritionalTargets: widget.nutritionalTargets,
                        mealType: widget.mealType,
                        logDate: widget.logDate,
                      ),

                      const SizedBox(height: 24),

                      // 🍱 Random Meals section
                      _buildSectionHeader(
                        title: "Discover Meals",
                        subtitle: "Try something new",
                      ),
                      const SizedBox(height: 12),
                      _buildMealList(_displayedMeals),

                      const SizedBox(height: 24),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            title: "Custom Meals",
                            subtitle: "Add your own meals",
                          ),
                          const SizedBox(width: 15),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final changed = await Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomMealPage(
                                      defaultCategory: widget.mealType,
                                      editMeal: false,
                                      editRecipe: false,
                                      logDate: widget.logDate,
                                    ),
                                  ),
                                );
                                if (changed) {
                                  _loadCustomMeals;
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lightBlueTheme.colorScheme.secondary,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                              ),
                              icon: const Icon(Icons.create, size: 18),
                              label: const Text('Create Custom Meal', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ]
                      ),
                      const SizedBox(height: 12),
                      _buildMealList(_customMeals),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: lightBlueTheme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealList(List<QueryDocumentSnapshot> meals) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final doc = meals[index];
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Unnamed meal';
        final calorie = data['calorie'] is num ? data['calorie'] : 0.0;
        final protein = data['protein'] is num ? data['protein'] : 0.0;
        final carbs = data['carb'] is num ? data['carb'] : 0.0;
        final fats = data['fat'] is num ? data['fat'] : 0.0;
        List<TextEditingController> servingNameControllers = [];
        List<TextEditingController> servingGramControllers = [];
        if (data['servings'] != null) {
          for (var serving in data['servings']) {
            servingNameControllers.add(TextEditingController(text: serving['name']));
            servingGramControllers.add(TextEditingController(text: serving['grams']));
          }
        }

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
                Text('${calorie.toStringAsFixed(1)} kcal'),
                /*const SizedBox(height: 2),
                Text(
                  'Protein: ${protein.toStringAsFixed(1)}g | Carbs: ${carbs.toStringAsFixed(1)}g | Fat: ${fats.toStringAsFixed(1)}g',
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
                onPressed: () => _logMeal(
                    doc.id,
                    name,
                    widget.mealType,
                    FirebaseAuth.instance.currentUser!.uid,
                    widget.logDate,
                    {
                      'Calories': calorie,
                      'Protein_g': protein,
                      'Carbs_g': carbs,
                      'Fats_g': fats,
                    },
                    servings: data['servings'] ?? [],
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MealDetailsPage(data: data),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to check if meal exceeds targets
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
      final dynamic mealValue = mealNutrients[nutrient];
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
            const Text('Exceeds Recommendation', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
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
}
