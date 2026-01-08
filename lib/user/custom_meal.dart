import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_logging/main.dart';
import 'package:meal_logging/user/log_meals.dart';
import '../custom_styles.dart';
import '../functions.dart';
import 'meal_details.dart';

class CustomMealPage extends StatefulWidget {
  final String defaultCategory;
  final String? mealId;
  final Map<String, dynamic>? initialData;
  final int initialTabIndex;
  late final bool editMeal;
  late final bool editRecipe;
  final String logDate;

  CustomMealPage({
    super.key,
    required this.defaultCategory,
    this.mealId,
    this.initialData,
    this.initialTabIndex = 0,
    required this.editMeal,
    required this.editRecipe,
    required this.logDate,
  });

  @override
  State<CustomMealPage> createState() => _CustomMealPageState();
}

class _CustomMealPageState extends State<CustomMealPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToTab(int index) {
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MealLogPage(mealType: widget.defaultCategory, logDate: widget.logDate),
              ),
            );
          },
        ),
        centerTitle: true,
        title: Text(
          'Custom Meal',
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: lightBlueTheme.colorScheme.tertiary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: lightBlueTheme.colorScheme.secondary,
          labelColor: lightBlueTheme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'Meal'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Recipe'),
            Tab(icon: Icon(Icons.list), text: 'My Meals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MealForm(
            defaultCategory: widget.defaultCategory,
            mealId: widget.editMeal ? widget.mealId : null,
            initialData: widget.editMeal ? widget.initialData : null,
            logDate: widget.logDate,
          ),
          RecipeForm(
            defaultCategory: widget.defaultCategory,
            mealId: widget.editRecipe ? widget.mealId : null,
            initialData: widget.editRecipe ? widget.initialData : null,
            logDate: widget.logDate,
          ),
          UserMealsList(
            onEdit: (mealId, data) {
               int tabIndex = 0;
               bool editRecipe = false;
               if (data['type'] == 'recipe' || data['ingredients'] != null) {
                 tabIndex = 1;
                 editRecipe = true;
               }
               Navigator.pushReplacement(
                 context,
                 MaterialPageRoute(
                   builder: (_) => CustomMealPage(
                     defaultCategory: widget.defaultCategory,
                     mealId: mealId,
                     initialData: data,
                     initialTabIndex: tabIndex,
                     editMeal: editRecipe ? false : true,
                     editRecipe: editRecipe,
                     logDate: widget.logDate,
                   ),
                 ),
               );
            },
          ),
        ],
      ),
    );
  }
}

// Meal Form Widget
class MealForm extends StatefulWidget {
  final String defaultCategory;
  final String? mealId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onEdit;
  final String logDate;

  const MealForm({
    super.key,
    required this.defaultCategory,
    this.mealId,
    this.initialData,
    this.onEdit,
    required this.logDate,
  });

  @override
  State<MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<MealForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _mealNameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _fibreController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _ashController = TextEditingController();
  final TextEditingController _calciumController = TextEditingController();
  final TextEditingController _ironController = TextEditingController();
  final TextEditingController _phosphorusController = TextEditingController();
  final TextEditingController _potassiumController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();

  String? _foodGroup;
  String? _foodCategory;

  final List<TextEditingController> servingNameControllers = [];
  final List<TextEditingController> servingGramControllers = [];

  late final foodGroupItems = [
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
  ];

  late final foodCategoryItems = [
    'Breakfast',
    'Lunch / Dinner',
    'Snack',
    'Dessert',
    'Anytime',
    'Not Applicable',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _mealNameController.text = data['name'] ?? '';
      _foodGroup = data['foodGroup'];
      _foodCategory = data['foodCategory'];
      _caloriesController.text = (data['calorie'] ?? 0).toString();
      _proteinController.text = (data['protein'] ?? 0).toString();
      _carbsController.text = (data['carb'] ?? 0).toString();
      _fatController.text = (data['fat'] ?? 0).toString();
      _fibreController.text = (data['fibre'] ?? 0).toString();
      _waterController.text = (data['water'] ?? 0).toString();
      _ashController.text = (data['ash'] ?? 0).toString();
      _calciumController.text = (data['calcium'] ?? 0).toString();
      _ironController.text = (data['iron'] ?? 0).toString();
      _phosphorusController.text = (data['phosphorus'] ?? 0).toString();
      _potassiumController.text = (data['potassium'] ?? 0).toString();
      _sodiumController.text = (data['sodium'] ?? 0).toString();

      if (data['servings'] != null) {
        for (var serving in data['servings']) {
          servingNameControllers.add(TextEditingController(text: serving['name']));
          servingGramControllers.add(TextEditingController(text: serving['grams']));
        }
      }
    } else {
      _foodCategory = widget.defaultCategory == 'Lunch' || widget.defaultCategory == 'Dinner'
          ? 'Lunch / Dinner'
          : widget.defaultCategory;
      // Add one empty serving by default if creating new
      servingNameControllers.add(TextEditingController());
      servingGramControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fibreController.dispose();
    _waterController.dispose();
    _ashController.dispose();
    _calciumController.dispose();
    _ironController.dispose();
    _phosphorusController.dispose();
    _potassiumController.dispose();
    _sodiumController.dispose();
    for (final c in servingNameControllers) c.dispose();
    for (final c in servingGramControllers) c.dispose();
    super.dispose();
  }

  Future<void> _saveCustomMeal() async {
    if (!_formKey.currentState!.validate()) return;

    for (var i = 0; i < servingNameControllers.length; i++) {
      if (servingNameControllers[i].text.isEmpty || servingGramControllers[i].text.isEmpty) {
        servingNameControllers.removeAt(i);
        servingGramControllers.removeAt(i);
        i--;
      }
    }

    final mealData = {
      'type': 'meal',
      'deleted': false,
      'name': _mealNameController.text.trim(),
      'calorie': double.parse(_caloriesController.text),
      'protein': double.parse(_proteinController.text),
      'carb': double.parse(_carbsController.text),
      'fat': double.parse(_fatController.text),
      'fibre': double.parse(_fibreController.text),
      'water': double.parse(_waterController.text),
      'ash': double.parse(_ashController.text),
      'calcium': double.parse(_calciumController.text),
      'iron': double.parse(_ironController.text),
      'phosphorus': double.parse(_phosphorusController.text),
      'potassium': double.parse(_potassiumController.text),
      'sodium': double.parse(_sodiumController.text),
      'foodGroup': _foodGroup,
      'foodCategory': _foodCategory,
      'servings': List.generate(
        servingNameControllers.length,
            (i) => {
          'name': servingNameControllers[i].text.trim(),
          'grams': servingGramControllers[i].text.trim(),
        },
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.mealId != null) {
        await FirebaseFirestore.instance
            .collection('custom_meal')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('meals')
            .doc(widget.mealId)
            .update(mealData);
      } else {
        mealData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('custom_meal')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('meals')
            .add(mealData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.mealId != null ? 'Custom meal updated' : 'Custom meal created'),
          backgroundColor: lightBlueTheme.colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomMealPage(
            defaultCategory: widget.defaultCategory,
            initialTabIndex: 2,
            editMeal: false,
            editRecipe: false,
            logDate: widget.logDate,
          ),
        ),
      );
      //Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving meal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  InputTextField(label: 'Meal Name', controller: _mealNameController, isNumber: false, isInt: false),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                      value: _foodGroup,
                      decoration: InputDecoration(
                        labelText: 'Food Group',
                        labelStyle: TextStyle(fontSize: 15),
                        contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      items: foodGroupItems
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _foodGroup = v),
                      validator: (value) => value == null
                          ? 'Please select the food group'
                          : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: _foodCategory,
                      decoration: InputDecoration(
                        labelText: 'Food Category',
                        labelStyle: TextStyle(fontSize: 15),
                        contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      items: foodCategoryItems
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _foodCategory = v),
                      validator: (value) => value == null
                          ? 'Please select the food category'
                          : null,
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "Nutritional Values (per 100g)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: InputTextField(label: 'Calories', controller: _caloriesController, isNumber: true, isInt: false)),
                      const SizedBox(width: 12),
                      Expanded(child: InputTextField(label: 'Water', controller: _waterController, isNumber: true, isInt: false)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: InputTextField(label: 'Protein', controller: _proteinController, isNumber: true, isInt: false)),
                      const SizedBox(width: 12),
                      Expanded(child: InputTextField(label: 'Carbs', controller: _carbsController, isNumber: true, isInt: false)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: InputTextField(label: 'Fat', controller: _fatController, isNumber: true, isInt: false)),
                      const SizedBox(width: 12),
                      Expanded(child: InputTextField(label: 'Fibre', controller: _fibreController, isNumber: true, isInt: false)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: InputTextField(label: 'Ash', controller: _ashController, isNumber: true, isInt: false)),
                      const SizedBox(width: 12),
                      Expanded(child: InputTextField(label: 'Calcium', controller: _calciumController, isNumber: true, isInt: false)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: InputTextField(label: 'Iron', controller: _ironController, isNumber: true, isInt: false)),
                      const SizedBox(width: 12),
                      Expanded(child: InputTextField(label: 'Phosphorus', controller: _phosphorusController, isNumber: true, isInt: false)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: InputTextField(label: 'Potassium', controller: _potassiumController, isNumber: true, isInt: false)),
                      const SizedBox(width: 12),
                      Expanded(child: InputTextField(label: 'Sodium', controller: _sodiumController, isNumber: true, isInt: false)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "Serving Options",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Column(
                    children: List.generate(servingNameControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: servingNameControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Serving Name',
                                  labelStyle: TextStyle(fontSize: 15),
                                  contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: servingGramControllers[index],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Grams',
                                  labelStyle: TextStyle(fontSize: 15),
                                  contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          servingNameControllers.add(TextEditingController());
                          servingGramControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Add Serving Option"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: lightBlueTheme.colorScheme.secondary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _saveCustomMeal,
              icon: const Icon(Icons.save),
              label: const Text('Save Meal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: lightBlueTheme.colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// Recipe Form Widget
class RecipeForm extends StatefulWidget {
  final String defaultCategory;
  final String? mealId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onEdit;
  final String logDate;

  const RecipeForm({
    super.key,
    required this.defaultCategory,
    this.mealId,
    this.initialData,
    this.onEdit,
    required this.logDate,
  });

  @override
  State<RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _recipeNameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();
  final TextEditingController _totalGramsController = TextEditingController(text: "0");

  final List<Map<String, dynamic>> _ingredients = [];
  String? _foodCategory;
  String? _foodGroup;

  late final foodGroupItems = [
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
  ];

  late final foodCategoryItems = [
    'Breakfast',
    'Lunch / Dinner',
    'Snack',
    'Dessert',
    'Anytime',
    'Not Applicable',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _recipeNameController.text = data['name'] ?? '';
      _foodGroup = data['foodGroup'];
      _foodCategory = data['foodCategory'];
      _totalGramsController.text = (data['servings']?[0]?['grams'] ?? "0").toString();
      _servingSizeController.text = data['servings']?[0]?['name'] ?? '';

      if (data['ingredients'] != null) {
        for (var ingredient in data['ingredients']) {
          _ingredients.add(Map<String, dynamic>.from(ingredient));
        }
      }
    } else {
      _foodCategory = widget.defaultCategory == 'Lunch' || widget.defaultCategory == 'Dinner'
          ? 'Lunch / Dinner'
          : widget.defaultCategory;
    }
  }

  @override
  void dispose() {
    _recipeNameController.dispose();
    _instructionsController.dispose();
    _servingSizeController.dispose();
    _totalGramsController.dispose();
    super.dispose();
  }

  Future<void> _showIngredientPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const IngredientPickerPage(),
      ),
    );

    if (result != null) {
      setState(() {
        _ingredients.add(result);
        final grams = double.parse(_totalGramsController.text);
        _totalGramsController.text = (grams + result['quantity']).toString();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      final grams = double.parse(_totalGramsController.text);
      _totalGramsController.text = (grams - _ingredients[index]['quantity']).toStringAsFixed(1);
      _ingredients.removeAt(index);
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one ingredient'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    double totalCalories = 0;
    double totalWater = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFibre = 0;
    double totalAsh = 0;
    double totalCalcium = 0;
    double totalIron = 0;
    double totalPhosphorus = 0;
    double totalPotassium = 0;
    double totalSodium = 0;

    for (final ingredient in _ingredients) {
      final factor = ingredient['quantity'] / 100;
      totalCalories += ingredient['calorie'] * factor;
      totalWater += ingredient['water'] * factor;
      totalProtein += ingredient['protein'] * factor;
      totalCarbs += ingredient['carb'] * factor;
      totalFat += ingredient['fat'] * factor;
      totalFibre += ingredient['fibre'] * factor;
      totalAsh += ingredient['ash'] * factor;
      totalCalcium += ingredient['calcium'] * factor;
      totalIron += ingredient['iron'] * factor;
      totalPhosphorus += ingredient['phosphorus'] * factor;
      totalPotassium += ingredient['potassium'] * factor;
      totalSodium += ingredient['sodium'] * factor;
    }

    final factor = 100 / double.parse(_totalGramsController.text);

    final recipeData = {
      'type': 'recipe',
      'deleted': false,
      'name': _recipeNameController.text.trim(),
      'foodCategory': _foodCategory ?? 'Not Applicable',
      'foodGroup': _foodGroup,
      'calorie': double.parse((totalCalories * factor).toStringAsFixed(1)),
      'water': double.parse((totalWater * factor).toStringAsFixed(1)),
      'protein': double.parse((totalProtein * factor).toStringAsFixed(1)),
      'carb': double.parse((totalCarbs * factor).toStringAsFixed(1)),
      'fat': double.parse((totalFat * factor).toStringAsFixed(1)),
      'fibre': double.parse((totalFibre * factor).toStringAsFixed(1)),
      'ash': double.parse((totalAsh * factor).toStringAsFixed(1)),
      'calcium': double.parse((totalCalcium * factor).toStringAsFixed(1)),
      'iron': double.parse((totalIron * factor).toStringAsFixed(1)),
      'phosphorus': double.parse((totalPhosphorus * factor).toStringAsFixed(1)),
      'potassium': double.parse((totalPotassium * factor).toStringAsFixed(1)),
      'sodium': double.parse((totalSodium * factor).toStringAsFixed(1)),
      'servings': List.generate(
        1,
            (i) => {
          'name': _servingSizeController.text.trim(),
          'grams': _totalGramsController.text,
        },
      ),
      'ingredients': _ingredients,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.mealId != null) {
        await FirebaseFirestore.instance
            .collection('custom_meal')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('meals')
            .doc(widget.mealId)
            .update(recipeData);
      } else {
        recipeData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('custom_meal')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('meals')
            .add(recipeData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.mealId != null ? 'Recipe updated' : 'Recipe created'),
          backgroundColor: lightBlueTheme.colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomMealPage(
            defaultCategory: widget.defaultCategory,
            initialTabIndex: 2,
            editMeal: false,
            editRecipe: false,
            logDate: widget.logDate,
          ),
        ),
      );
      //Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving recipe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _recipeNameController,
                    decoration: InputDecoration(
                      labelText: 'Recipe Name',
                      labelStyle: TextStyle(fontSize: 15),
                      contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a recipe name' : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _foodGroup,
                    decoration: InputDecoration(
                      labelText: 'Food Group',
                      labelStyle: TextStyle(fontSize: 15),
                      contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    items: foodGroupItems
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _foodGroup = v),
                    validator: (value) => value == null
                        ? 'Please select the food group'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _foodCategory,
                    decoration: InputDecoration(
                      labelText: 'Food Category',
                      labelStyle: TextStyle(fontSize: 15),
                      contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    items: foodCategoryItems
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _foodCategory = v),
                  ),

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InputTextField(label: 'Serving Size', controller: _servingSizeController, isNumber: false, isInt: false),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _totalGramsController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Grams',
                            labelStyle: TextStyle(fontSize: 15),
                            contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        )
                      )
                    ]
                  ),

                  const SizedBox(height: 16),
                  Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Ingredients",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _showIngredientPicker,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Ingredient"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_ingredients.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No ingredients added yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _ingredients.asMap().entries.map((entry) {
                        final index = entry.key;
                        final ingredient = entry.value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(ingredient['name']),
                            subtitle: Text('${ingredient['quantity']}g'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeIngredient(index),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: lightBlueTheme.colorScheme.secondary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _saveRecipe,
              icon: const Icon(Icons.save),
              label: const Text('Save Recipe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: lightBlueTheme.colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _nutritionRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: lightBlueTheme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class UserMealsList extends StatelessWidget {
  final Function(String, Map<String, dynamic>) onEdit;
  final Function(String, Map<String, dynamic>)? onLog;

  const UserMealsList({
    super.key,
    required this.onEdit,
    this.onLog,
  });

  Future<void> _deleteMeal(BuildContext context, String mealId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to delete this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('meals')
          .doc(mealId)
          .update({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meal deleted'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('custom_meal')
          .doc(uid)
          .collection('meals')
          .where('deleted', isEqualTo: false)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No custom meals yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final meal = snapshot.data!.docs[index];
            final data = meal.data() as Map<String, dynamic>;
            final calorie = data['calorie']?.toString() ?? '0';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  data['name'] ?? 'Unnamed Meal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$calorie kcal (per 100g)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onLog != null)
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () => onLog!(meal.id, data),
                        tooltip: 'Log Meal',
                      ),
                    IconButton(
                      icon: Icon(Icons.edit, color: lightBlueTheme.colorScheme.secondary),
                      onPressed: () => onEdit(meal.id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMeal(context, meal.id),
                    ),
                  ],
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
      },
    );
  }
}

// Ingredient Picker Page
class IngredientPickerPage extends StatefulWidget {
  const IngredientPickerPage({super.key});

  @override
  State<IngredientPickerPage> createState() => _IngredientPickerPageState();
}

class _IngredientPickerPageState extends State<IngredientPickerPage> {
  final _ingredientFormKey = GlobalKey<FormState>();
  final servingOptionController = TextEditingController(text: '100');
  final quantityController = TextEditingController(text: '1');
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allIngredients = [];
  List<QueryDocumentSnapshot> _filteredIngredients = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  double servingGram = 100;

  final List<String> _filterOptions = [
    'All',
    'Vegetables',
    'Fruits',
    'Ingredients / Raw Foods',
    'Fish and shellfish',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _searchController.addListener(_filterIngredients);
    quantityController.addListener(_onQuantityChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQuantityChange() {
    final qty = double.tryParse(quantityController.text) ?? 1;

    setState(() {
      servingOptionController.text =
          (servingGram * qty).toStringAsFixed(1);
    });
  }

  Future<double?> _showQuantityDialog(Map<String, dynamic> ingredient) async {
    final servings = ingredient['servings'] ?? [];
    String? selectedServingName;
    servingOptionController.text = "100";
    quantityController.text = "1";

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Add ${ingredient['name']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _ingredientFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (servings.isNotEmpty)
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
                            items: servings
                                .map<DropdownMenuItem<String>>((item) {
                              return DropdownMenuItem<String>(
                                value: item['name'],
                                child: Text(
                                    "${item['name']} (${item['grams']}g)"),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedServingName = value;
                                final selected = servings.firstWhere(
                                        (s) => s['name'] == value);
                                final grams = double.tryParse(selected['grams'].toString()) ?? 0;
                                servingGram = grams;
                                final qty = int.tryParse(quantityController.text) ?? 1;

                                servingOptionController.text = (grams * qty).toStringAsFixed(1);
                              });
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                    TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          labelStyle: TextStyle(fontSize: 15),
                          contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          } else if (int.tryParse(value) == null) {
                            return 'Quantity must be an integer';
                          } else if (int.parse(value) <= 0) {
                            return 'Quantity must be greater than 0';
                          }
                          return null;
                        }
                    ),

                    const SizedBox(height: 20),
                    InputTextField(
                      label: 'Serving Size (g)',
                      controller: servingOptionController,
                      isNumber: true,
                      isInt: false,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final grams =
                  double.tryParse(servingOptionController.text);

                  if (grams == null) {
                    Navigator.pop(dialogContext);
                    return;
                  }

                  Navigator.pop(dialogContext, grams);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightBlueTheme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  Future<void> _loadIngredients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('meals')
          .where('foodCategory', isEqualTo: 'Not Applicable')
          .orderBy('name')
          .get();

      setState(() {
        _allIngredients = snapshot.docs;
        _filteredIngredients = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading ingredients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterIngredients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredIngredients = _allIngredients.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final foodGroup = (data['foodGroup'] ?? '').toString();

        final matchesSearch = name.contains(query);
        final matchesFilter = _selectedFilter == 'All' || foodGroup == _selectedFilter;

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  Future<void> _selectIngredient(Map<String, dynamic> ingredient) async {
    final quantity = await _showQuantityDialog(ingredient);

    if (quantity != null) {
      Navigator.pop(context, {
        ...ingredient,
        'quantity': quantity,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Select Ingredient',
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: lightBlueTheme.colorScheme.tertiary,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: lightBlueTheme.colorScheme.tertiary,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                        _filterIngredients();
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: lightBlueTheme.colorScheme.secondary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredIngredients.length} ingredients found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Ingredients List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredIngredients.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ingredients found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term or filter',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredIngredients.length,
              itemBuilder: (context, index) {
                final doc = _filteredIngredients[index];
                final data = doc.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _selectIngredient(data),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}