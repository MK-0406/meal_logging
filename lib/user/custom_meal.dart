import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_logging/user/log_meals.dart';
import '../custom_styles.dart';
import 'meal_details.dart';
import 'nutrition_label_extraction.dart';
import 'package:image_picker/image_picker.dart';

double toFixed(double num, int decimals) {
  return double.parse(num.toStringAsFixed(decimals));
}

class CustomMealPage extends StatefulWidget {
  final String defaultCategory;
  final String? mealId;
  final Map<String, dynamic>? initialData;
  final int initialTabIndex;
  final bool editMeal;
  final bool editRecipe;
  final String logDate;
  final Map<String, dynamic>? nutritionalTargets;
  final Map<String, dynamic>? actualTargets;

  const CustomMealPage({
    super.key,
    required this.defaultCategory,
    this.mealId,
    this.initialData,
    this.initialTabIndex = 0,
    required this.editMeal,
    required this.editRecipe,
    required this.logDate,
    required this.nutritionalTargets,
    required this.actualTargets,
  });

  @override
  State<CustomMealPage> createState() => _CustomMealPageState();
}

class _CustomMealPageState extends State<CustomMealPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                MealForm(
                  defaultCategory: widget.defaultCategory,
                  mealId: widget.editMeal ? widget.mealId : null,
                  initialData: widget.editMeal ? widget.initialData : null,
                  logDate: widget.logDate,
                  nutritionalTargets: widget.nutritionalTargets,
                  actualTargets: widget.actualTargets,
                ),
                RecipeForm(
                  defaultCategory: widget.defaultCategory,
                  mealId: widget.editRecipe ? widget.mealId : null,
                  initialData: widget.editRecipe ? widget.initialData : null,
                  logDate: widget.logDate,
                  nutritionalTargets: widget.nutritionalTargets,
                  actualTargets: widget.actualTargets,
                ),
                UserMealsList(
                  onEdit: (mealId, data, nutritionalTargets) {
                    int tabIndex =
                        (data['type'] == 'recipe' ||
                            data['ingredients'] != null)
                        ? 1
                        : 0;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomMealPage(
                          defaultCategory: widget.defaultCategory,
                          mealId: mealId,
                          initialData: data,
                          initialTabIndex: tabIndex,
                          editMeal: tabIndex == 0,
                          editRecipe: tabIndex == 1,
                          logDate: widget.logDate,
                          nutritionalTargets: nutritionalTargets,
                          actualTargets: widget.actualTargets,
                        ),
                      ),
                    );
                  },
                  nutritionalTargets: widget.nutritionalTargets,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
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
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealLogPage(
                      mealType: widget.defaultCategory,
                      logDate: widget.logDate,
                      nutritionalTargets: widget.nutritionalTargets,
                      actualTargets: widget.actualTargets,
                      baseTargets: null,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Custom Creations',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Quick Meal'),
              Tab(text: 'Full Recipe'),
              Tab(text: 'My List'),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class MealForm extends StatefulWidget {
  final String defaultCategory;
  final String? mealId;
  final Map<String, dynamic>? initialData;
  final String logDate;
  final Map<String, dynamic>? nutritionalTargets;
  final Map<String, dynamic>? actualTargets;

  const MealForm({
    super.key,
    required this.defaultCategory,
    this.mealId,
    this.initialData,
    required this.logDate,
    required this.nutritionalTargets,
    required this.actualTargets,
  });

  @override
  State<MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<MealForm> {
  final _mealFormKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  String? _foodGroup;
  String? _foodCategory;
  final List<TextEditingController> _servingNameControllers = [];
  final List<TextEditingController> _servingGramControllers = [];
  Map<String, dynamic> extractedNutrition = {};
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImageFromCamera() async {
    return await _picker.pickImage(source: ImageSource.camera);
  }

  Future<XFile?> pickImageFromGallery() async {
    return await _picker.pickImage(source: ImageSource.gallery);
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final fields = [
      'name',
      'calorie',
      'protein',
      'carb',
      'fat',
      'fibre',
      'water',
      'ash',
      'calcium',
      'iron',
      'phosphorus',
      'potassium',
      'sodium',
    ];
    for (var f in fields) {
      _controllers[f] = TextEditingController(
        text: widget.initialData?[f]?.toString() ?? '',
      );
    }
    _foodGroup = widget.initialData?['foodGroup'];
    _foodCategory =
        widget.initialData?['foodCategory'] ??
        (widget.defaultCategory == 'Lunch' || widget.defaultCategory == 'Dinner'
            ? 'Lunch / Dinner'
            : widget.defaultCategory);

    if (widget.initialData?['servings'] != null) {
      for (var s in widget.initialData!['servings']) {
        _servingNameControllers.add(TextEditingController(text: s['name']));
        _servingGramControllers.add(TextEditingController(text: s['grams']));
      }
    } else {
      _servingNameControllers.add(TextEditingController());
      _servingGramControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var c in _servingNameControllers) {
      c.dispose();
    }
    for (var c in _servingGramControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      for (var c in _controllers.values) {
        c.clear();
      }
      _foodGroup = null;
      _foodCategory = null;
      _servingNameControllers.clear();
      _servingGramControllers.clear();
      _servingNameControllers.add(TextEditingController());
      _servingGramControllers.add(TextEditingController());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _mealFormKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionCard("Basic Information", [
            InputTextField(
              label: 'Meal Name',
              controller: _controllers['name']!,
              isNumber: false,
              isInt: false,
            ),
            const SizedBox(height: 16),
            _buildDropdown("Food Group", _foodGroup, [
              'Cooked Food / Dishes',
              'Ingredients / Raw Foods',
              'Vegetables',
              'Processed Foods',
              'Snacks',
              'Beverages',
              'Condiments / Sauces',
              'Fast Food',
              'Desserts / Sweets',
              'Soups / Stews',
              'Salads / Cold Dishes',
              'Fish and shellfish',
              'Fruits',
              'Other',
            ], (v) => setState(() => _foodGroup = v)),
            const SizedBox(height: 16),
            _buildDropdown("Category", _foodCategory, [
              'Breakfast',
              'Lunch / Dinner',
              'Snack',
              'Dessert',
              'Anytime',
            ], (v) => setState(() => _foodCategory = v)),
          ]),
          const SizedBox(height: 24),
          _buildSectionCard2("Nutritional Values (per 100g)", [
            _buildNutrientGrid(),
          ]),
          const SizedBox(height: 24),
          _buildSectionCard("Portion Options", [
            ...List.generate(
              _servingNameControllers.length,
              (i) => _buildServingRow(i),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _servingNameControllers.add(TextEditingController());
                _servingGramControllers.add(TextEditingController());
              }),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Add Another Portion"),
            ),
          ]),
          const SizedBox(height: 32),
          _buildActionButtons(_saveMeal),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionCard2(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                  onPressed: () async {
                    final NutritionService nutritionService =
                        NutritionService();

                    final image = await pickImageFromCamera();

                    if (image != null) {
                      String extractedText = await nutritionService
                          .extractTextFromImage(image.path);

                      final result = await nutritionService.analyzeNutrition(
                        extractedText,
                      );

                      if (result != null) {
                        setState(() {
                          extractedNutrition = result;
                        });
                      } 
                    }
                  },
                  icon: Icon(Icons.camera),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? val,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: (value) => value == null ? 'Please select a $label' : null,
    );
  }

  Widget _buildNutrientGrid() {
    return Column(
      children: [
        _nutrientInputRow('calorie', 'Calories (kcal)', extractedNutrition['calories'], 'water', 'Water (g)', extractedNutrition['water_g']),
        _nutrientInputRow('protein', 'Protein (g)', extractedNutrition['protein_g'], 'carb', 'Carbs (g)', extractedNutrition['carbohydrates_g']),
        _nutrientInputRow('fat', 'Fat (g)', extractedNutrition['fat_g'], 'fibre', 'Fibre (g)', extractedNutrition['fiber_g']),
        _nutrientInputRow('calcium', 'Calcium (mg)', extractedNutrition['calcium_mg'], 'iron', 'Iron (mg)', extractedNutrition['iron_mg']),
        _nutrientInputRow(
          'potassium',
          'Potassium (mg)',
          extractedNutrition['potassium_mg'],
          'sodium',
          'Sodium (mg)',
          extractedNutrition['sodium_mg']),
        _nutrientInputRow('phosphorus', 'Phosphorus (mg)', extractedNutrition['phosphorus_mg'], 'ash', 'Ash (g)', extractedNutrition['ash_g']),
      ],
    );
  }

  Widget _nutrientInputRow(String f1, String l1, dynamic val1, String f2, String l2, dynamic val2) {
      if (val1 != null) {
        _controllers[f1]!.text = val1.toString();
      }
      if (val2 != null) {
        _controllers[f2]!.text = val2.toString();
      }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: InputTextField(
              label: l1,
              controller: _controllers[f1]!,
              isNumber: true,
              isInt: false,
              includeZero: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InputTextField(
              label: l2,
              controller: _controllers[f2]!,
              isNumber: true,
              isInt: false,
              includeZero: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingRow(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _servingNameControllers[i],
              decoration: InputDecoration(
                labelText: 'Size Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter size name' : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: _servingGramControllers[i],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Grams',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter weight';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Invalid';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(VoidCallback onSave) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _clearAll,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text("Clear Fields"),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Save Meal",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveMeal() async {
    if (!_mealFormKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final mealData = {
      'type': 'meal',
      'deleted': false,
      'name': _controllers['name']!.text.trim(),
      'calorie': toFixed(double.parse(_controllers['calorie']!.text), 1),
      'protein': toFixed(double.parse(_controllers['protein']!.text), 1),
      'carb': toFixed(double.parse(_controllers['carb']!.text), 1),
      'fat': toFixed(double.parse(_controllers['fat']!.text), 1),
      'fibre': toFixed(double.parse(_controllers['fibre']!.text), 1),
      'water': toFixed(double.parse(_controllers['water']!.text), 1),
      'ash': toFixed(double.parse(_controllers['ash']!.text), 1),
      'calcium': toFixed(double.parse(_controllers['calcium']!.text), 1),
      'iron': toFixed(double.parse(_controllers['iron']!.text), 1),
      'phosphorus': toFixed(double.parse(_controllers['phosphorus']!.text), 1),
      'potassium': toFixed(double.parse(_controllers['potassium']!.text), 1),
      'sodium': toFixed(double.parse(_controllers['sodium']!.text), 1),
      'foodGroup': _foodGroup,
      'foodCategory': _foodCategory,
      'updatedAt': FieldValue.serverTimestamp(),
      'servings': List.generate(
        _servingNameControllers.length,
        (i) => {
          'name': _servingNameControllers[i].text,
          'grams': _servingGramControllers[i].text,
        },
      ),
    };
    if (widget.mealId != null) {
      await FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(uid)
          .collection('meals')
          .doc(widget.mealId)
          .update(mealData);
    } else {
      mealData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(uid)
          .collection('meals')
          .add(mealData);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomMealPage(
          defaultCategory: widget.defaultCategory,
          initialTabIndex: 2,
          editMeal: false,
          editRecipe: false,
          logDate: widget.logDate,
          nutritionalTargets: widget.nutritionalTargets,
          actualTargets: widget.actualTargets,
        ),
      ),
    );
  }
}

class RecipeForm extends StatefulWidget {
  final String defaultCategory;
  final String? mealId;
  final Map<String, dynamic>? initialData;
  final String logDate;
  final Map<String, dynamic>? nutritionalTargets;
  final Map<String, dynamic>? actualTargets;

  const RecipeForm({
    super.key,
    required this.defaultCategory,
    this.mealId,
    this.initialData,
    required this.logDate,
    required this.nutritionalTargets,
    required this.actualTargets,
  });

  @override
  State<RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeForm> {
  final _recipeFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _servingNameController = TextEditingController();
  final TextEditingController _totalGramsController = TextEditingController(
    text: "0",
  );
  final List<Map<String, dynamic>> _ingredients = [];
  String? _foodCategory;
  String? _foodGroup;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _servingNameController.text =
          widget.initialData!['servings']?[0]?['name'] ?? '';
      _totalGramsController.text =
          (widget.initialData!['servings']?[0]?['grams'] ?? "0").toString();
      _foodCategory = widget.initialData!['foodCategory'];
      _foodGroup = widget.initialData!['foodGroup'];
      if (widget.initialData!['ingredients'] != null) {
        _ingredients.addAll(
          List<Map<String, dynamic>>.from(widget.initialData!['ingredients']),
        );
      }
    } else {
      _foodCategory =
          widget.defaultCategory == 'Lunch' ||
              widget.defaultCategory == 'Dinner'
          ? 'Lunch / Dinner'
          : widget.defaultCategory;
    }
  }

  void _clearAll() {
    setState(() {
      _nameController.clear();
      _servingNameController.clear();
      _totalGramsController.text = "0";
      _foodCategory = null;
      _foodGroup = null;
      _ingredients.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _recipeFormKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Recipe Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter recipe name'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildDropdown("Food Group", _foodGroup, [
                  'Cooked Food / Dishes',
                  'Ingredients / Raw Foods',
                  'Vegetables',
                  'Processed Foods',
                  'Snacks',
                  'Beverages',
                  'Condiments / Sauces',
                  'Fast Food',
                  'Desserts / Sweets',
                  'Soups / Stews',
                  'Salads / Cold Dishes',
                  'Fish and shellfish',
                  'Fruits',
                  'Other',
                ], (v) => setState(() => _foodGroup = v)),
                const SizedBox(height: 16),
                _buildDropdown("Category", _foodCategory, [
                  'Breakfast',
                  'Lunch / Dinner',
                  'Snack',
                  'Dessert',
                  'Anytime',
                ], (v) => setState(() => _foodCategory = v)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _servingNameController,
                        decoration: InputDecoration(
                          labelText: "Serving Size Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter size name'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _totalGramsController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Total Grams",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Ingredients",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: _addIngredient,
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF42A5F5),
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_ingredients.isEmpty)
                  Center(
                    child: Text(
                      "No ingredients added",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ..._ingredients.asMap().entries.map(
                  (e) => ListTile(
                    title: Text(e.value['name']),
                    subtitle: Text("${e.value['quantity']}g"),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => setState(() {
                        final grams = double.parse(_totalGramsController.text);
                        _totalGramsController.text =
                            (grams - e.value['quantity']).toStringAsFixed(1);
                        _ingredients.removeAt(e.key);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearAll,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Clear Fields"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Save Recipe",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? val,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: (value) => value == null ? 'Please select a $label' : null,
    );
  }

  void _addIngredient() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const IngredientPickerPage()),
    );
    if (result != null) {
      setState(() {
        _ingredients.add(result);
        final grams = double.parse(_totalGramsController.text);
        _totalGramsController.text = (grams + result['quantity'])
            .toStringAsFixed(1);
      });
    }
  }

  Future<void> _saveRecipe() async {
    if (!_recipeFormKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one ingredient")),
      );
      return;
    }

    double totalCalories = 0,
        totalWater = 0,
        totalProtein = 0,
        totalCarbs = 0,
        totalFat = 0,
        totalFibre = 0,
        totalAsh = 0,
        totalCalcium = 0,
        totalIron = 0,
        totalPhosphorus = 0,
        totalPotassium = 0,
        totalSodium = 0;

    for (final i in _ingredients) {
      final factor = i['quantity'] / 100;
      totalCalories += i['calorie'] * factor;
      totalWater += i['water'] * factor;
      totalProtein += i['protein'] * factor;
      totalCarbs += i['carb'] * factor;
      totalFat += i['fat'] * factor;
      totalFibre += i['fibre'] * factor;
      totalAsh += i['ash'] * factor;
      totalCalcium += i['calcium'] * factor;
      totalIron += i['iron'] * factor;
      totalPhosphorus += i['phosphorus'] * factor;
      totalPotassium += i['potassium'] * factor;
      totalSodium += i['sodium'] * factor;
    }

    final factor = 100 / double.parse(_totalGramsController.text);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final recipeData = {
      'type': 'recipe',
      'deleted': false,
      'name': _nameController.text.trim(),
      'foodCategory': _foodCategory ?? 'Anytime',
      'foodGroup': _foodGroup ?? 'Cooked Food / Dishes',
      'calorie': toFixed((totalCalories * factor), 1),
      'water': toFixed((totalWater * factor), 1),
      'protein': toFixed((totalProtein * factor), 1),
      'carb': toFixed((totalCarbs * factor), 1),
      'fat': toFixed((totalFat * factor), 1),
      'fibre': toFixed((totalFibre * factor), 1),
      'ash': toFixed((totalAsh * factor), 1),
      'calcium': toFixed((totalCalcium * factor), 1),
      'iron': toFixed((totalIron * factor), 1),
      'phosphorus': toFixed((totalPhosphorus * factor), 1),
      'potassium': toFixed((totalPotassium * factor), 1),
      'sodium': toFixed((totalSodium * factor), 1),
      'servings': [
        {
          'name': _servingNameController.text.trim(),
          'grams': _totalGramsController.text,
        },
      ],
      'ingredients': _ingredients,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.mealId != null) {
      await FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(uid)
          .collection('meals')
          .doc(widget.mealId)
          .update(recipeData);
    } else {
      recipeData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(uid)
          .collection('meals')
          .add(recipeData);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomMealPage(
          defaultCategory: widget.defaultCategory,
          initialTabIndex: 2,
          editMeal: false,
          editRecipe: false,
          logDate: widget.logDate,
          nutritionalTargets: widget.nutritionalTargets,
          actualTargets: widget.actualTargets,
        ),
      ),
    );
  }
}

class UserMealsList extends StatefulWidget {
  final Function(String, Map<String, dynamic>, Map<String, dynamic>?) onEdit;
  final Map<String, dynamic>? nutritionalTargets;

  const UserMealsList({
    super.key,
    required this.onEdit,
    required this.nutritionalTargets,
  });

  @override
  State<UserMealsList> createState() => _UserMealsList();
}

class _UserMealsList extends State<UserMealsList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('custom_meal')
                .doc(uid)
                .collection('meals')
                .where('deleted', isEqualTo: false)
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No custom meals yet"),
                    ],
                  ),
                );
              }
              var data = docs
                  .map((doc) {
                    final meal = doc.data() as Map<String, dynamic>;
                    meal['id'] = doc.id;
                    return meal;
                  })
                  .where((meal) {
                    return meal['name'].toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                  })
                  .toList();

              return data.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text("No meals found"),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MealDetailsPage(
                                  data: data[i],
                                  mealId: data[i]['id'],
                                ),
                              ),
                            ),
                            title: Text(
                              data[i]['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${data[i]['calorie'].toStringAsFixed(0)} kcal per 100g",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => widget.onEdit(
                                    data[i]['id'],
                                    data[i],
                                    widget.nutritionalTargets,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blue,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _delete(context, data[i]['id'], uid),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search for meals...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF42A5F5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
        ),
      ),
    );
  }

  void _delete(BuildContext context, String id, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("Remove this meal permanently?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(uid)
          .collection('meals')
          .doc(id)
          .update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }
}

class IngredientPickerPage extends StatefulWidget {
  const IngredientPickerPage({super.key});
  @override
  State<IngredientPickerPage> createState() => _IngredientPickerPageState();
}

class _IngredientPickerPageState extends State<IngredientPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allIngredients = [];
  List<QueryDocumentSnapshot> _filteredIngredients = [];
  bool _isLoading = true;
  final String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _searchController.addListener(_filter);
  }

  void _loadIngredients() async {
    final s = await FirebaseFirestore.instance
        .collection('meals')
        .where('foodCategory', isEqualTo: 'Not Applicable')
        .orderBy('name')
        .get();
    setState(() {
      _allIngredients = s.docs;
      _filteredIngredients = s.docs;
      _isLoading = false;
    });
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredIngredients = _allIngredients.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final matchesSearch = data['name'].toString().toLowerCase().contains(q);
        final matchesFilter =
            _selectedFilter == 'All' || data['foodGroup'] == _selectedFilter;
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Select Ingredient",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredIngredients.length,
                    itemBuilder: (context, i) {
                      final data =
                          _filteredIngredients[i].data()
                              as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          title: Text(
                            data['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final qty = await _showQtyDialog(data);
                            if (!context.mounted) return;
                            if (qty != null) {
                              data['quantity'] = qty;
                              Navigator.pop(context, data);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<double?> _showQtyDialog(Map<String, dynamic> ingredient) async {
    final name = ingredient['name'] ?? 'Ingredient';
    final servings = ingredient['servings'] as List? ?? [];
    final ctrl = TextEditingController(text: "100");
    final qtyCtrl = TextEditingController(text: "1");
    final formKey = GlobalKey<FormState>();
    String? selectedServing;
    double baseGrams = 100;

    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text("Add $name"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (servings.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Serving Option",
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedServing,
                    items: servings
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['name'],
                            child: Text("${s['name']} (${s['grams']}g)"),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedServing = val;
                        final s = servings.firstWhere(
                          (item) => item['name'] == val,
                        );
                        baseGrams =
                            double.tryParse(s['grams'].toString()) ?? 100;
                        final multiplier = double.tryParse(qtyCtrl.text) ?? 1;
                        ctrl.text = (baseGrams * multiplier).toStringAsFixed(1);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Quantity (count)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final multiplier = double.tryParse(val) ?? 1;
                      setState(() {
                        ctrl.text = (baseGrams * multiplier).toStringAsFixed(1);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: "Total Weight (grams)",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter weight';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Invalid weight';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, double.tryParse(ctrl.text));
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }
}
