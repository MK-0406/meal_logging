import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  final CollectionReference meals = FirebaseFirestore.instance.collection(
    'meals',
  );

  List<TextEditingController> servingNameControllers = [];
  List<TextEditingController> servingGramControllers = [];

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

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _mealNameController = TextEditingController();
  String? _foodGroup;
  String? _foodCategory;
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fibreController = TextEditingController();
  final TextEditingController _ashController = TextEditingController();
  final TextEditingController _calciumController = TextEditingController();
  final TextEditingController _ironController = TextEditingController();
  final TextEditingController _phosphorusController = TextEditingController();
  final TextEditingController _potassiumController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();

  String? _selectedMealId;

  void _clearForm() {
    _mealNameController.clear();
    _waterController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _fibreController.clear();
    _waterController.clear();
    _ashController.clear();
    _calciumController.clear();
    _ironController.clear();
    _phosphorusController.clear();
    _potassiumController.clear();
    _sodiumController.clear();
    _foodGroup = null;
    _foodCategory = null;
    _selectedMealId = null;
    _clearServingRows();
  }

  Future<void> _addMeal() async {
    if (_formKey.currentState!.validate()) {
      await meals.add({
        'name': _mealNameController.text,
        'calorie': _caloriesController.text,
        'protein': _proteinController.text,
        'carb': _carbsController.text,
        'fat': _fatController.text,
        'fibre': _fibreController.text,
        'water': _waterController.text,
        'ash': _ashController.text,
        'calcium': _calciumController.text,
        'iron': _ironController.text,
        'phosphorus': _phosphorusController.text,
        'potassium': _potassiumController.text,
        'sodium': _sodiumController.text,
        'foodGroup': _foodGroup,
        'foodCategory': _foodCategory,
        'servings': List.generate(
          servingNameControllers.length,
          (i) => {
            'name': servingNameControllers[i].text,
            'grams': servingGramControllers[i].text,
          },
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _clearForm();
      Navigator.pop(context);
    }
  }

  Future<void> _updateMeal() async {
    if (_formKey.currentState!.validate() && _selectedMealId != null) {
      for(var i = 0; i < servingNameControllers.length; i++){
        if(servingNameControllers[i].text.isEmpty || servingGramControllers[i].text.isEmpty){
          servingGramControllers.removeAt(i);
          servingNameControllers.removeAt(i);
          i--;
        }
      }
      await meals.doc(_selectedMealId).update({
        'name': _mealNameController.text,
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
            'name': servingNameControllers[i].text,
            'grams': servingGramControllers[i].text,
          },
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _clearForm();
      Navigator.pop(context);
    }
  }

  Future<void> _deleteMeal(String id) async {
    await meals.doc(id).delete();
  }

  void _showMealDialog({bool isEditing = false, Map<String, dynamic>? data}) {
    if (isEditing && data != null) {
      _selectedMealId = data['id'];
      _mealNameController.text = data['name'] ?? '';
      _caloriesController.text = data['calorie'].toString();
      _proteinController.text = data['protein'].toString();
      _carbsController.text = data['carb'].toString();
      _fatController.text = data['fat'].toString();
      _fibreController.text = data['fibre'].toString();
      _waterController.text = data['water'].toString();
      _ashController.text = data['ash'].toString();
      _calciumController.text = data['calcium'].toString();
      _ironController.text = data['iron'].toString();
      _phosphorusController.text = data['phosphorus'].toString();
      _potassiumController.text = data['potassium'].toString();
      _sodiumController.text = data['sodium'].toString();
      _foodGroup = data['foodGroup'] ?? '';
      _foodCategory = data['foodCategory'] ?? '';

      if (data['servings'] != null) {
        for (var serving in data['servings']) {
          servingNameControllers.add(TextEditingController(text: serving['name']));
          servingGramControllers.add(TextEditingController(text: serving['grams']));
        }
      }
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Color(0xFFE3F2FD),
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              height:
                  MediaQuery.of(context).size.height *
                  0.85, // Fixed height for sticky behavior
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // This makes it stick
                children: [
                  // Sticky Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: lightBlueTheme.colorScheme.tertiary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isEditing ? 'Update Meal' : 'Add Meal',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: lightBlueTheme.colorScheme.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            _buildTextField('Meal Name', _mealNameController),

                            DropdownButtonFormField<String>(
                              value: _foodGroup,
                              items: foodGroupItems
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setDialogState(() => _foodGroup = v),
                              decoration: InputDecoration(
                                labelText: 'Food Group', // Fixed label
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) => value == null
                                  ? 'Please select the food group'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: _foodCategory,
                              items: foodCategoryItems
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => _foodCategory = v),
                              decoration: InputDecoration(
                                labelText: 'Food Category',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) => value == null
                                  ? 'Please select the food category'
                                  : null,
                            ),
                            const SizedBox(height: 15),

                            Text(
                              'Per 100 g',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Water (g)',
                              _waterController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Calories (kcal)',
                              _caloriesController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Protein (g)',
                              _proteinController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Fat (g)',
                              _fatController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Carbohydrates (g)',
                              _carbsController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Fibre (g)',
                              _fibreController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Ash (g)',
                              _ashController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Calcium (mg)',
                              _calciumController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Iron (mg)',
                              _ironController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Phosphorus (mg)',
                              _phosphorusController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Potassium (mg)',
                              _potassiumController,
                              isNumber: true,
                            ),
                            _buildTextField(
                              'Sodium (mg)',
                              _sodiumController,
                              isNumber: true,
                            ),

                            const SizedBox(height: 15),
                            Text(
                              "Serving Options",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Column(
                              children: List.generate(
                                servingNameControllers.length,
                                (index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller:
                                                servingNameControllers[index],
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Serving Name',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          flex: 1,
                                          child: TextFormField(
                                            controller:
                                                servingGramControllers[index],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Grams',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    servingNameControllers.add(TextEditingController());
                                    servingGramControllers.add(TextEditingController());
                                  });
                                },
                                icon: Icon(Icons.add),
                                label: Text("Add Serving Option"),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Sticky Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: lightBlueTheme.colorScheme.tertiary,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _clearForm();
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            //foregroundColor: Colors.deepOrange,
                            side: BorderSide(
                              color: lightBlueTheme.colorScheme.secondary,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: isEditing ? _updateMeal : _addMeal,
                          icon: Icon(isEditing ? Icons.update : Icons.add),
                          label: Text(isEditing ? 'Update' : 'Add'),
                          style: ElevatedButton.styleFrom(
                            //backgroundColor: Colors.deepOrange,
                            //foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMealDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFE3F2FD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          data['name'],
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: lightBlueTheme.colorScheme.primary, thickness: 2),
            const SizedBox(height: 12),
            _buildInfoRow('Group', data['foodGroup']),
            _buildInfoRow('Category', data['foodCategory']),
            _buildInfoRow('Serving size', '100 g'),
            _buildInfoRow('Water', '${data['water']} g'),
            _buildInfoRow('Calories', '${data['calorie']} g'),
            _buildInfoRow('Protein', '${data['protein']} g'),
            _buildInfoRow('Fat', '${data['fat']} g'),
            _buildInfoRow('Carbs', '${data['carb']} g'),
            _buildInfoRow('Fibre', '${data['fibre']} g'),
            _buildInfoRow('Ash', '${data['ash']} g'),
            _buildInfoRow('Calcium', '${data['calcium']} mg'),
            _buildInfoRow('Iron', '${data['iron']} mg'),
            _buildInfoRow('Phosphorus', '${data['phosphorus']} mg'),
            _buildInfoRow('Potassium', '${data['potassium']} mg'),
            _buildInfoRow('Sodium', '${data['sodium']} mg'),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.edit, color: lightBlueTheme.colorScheme.primary),
            label: Text(
              'Edit',
              style: TextStyle(color: lightBlueTheme.colorScheme.primary),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showMealDialog(isEditing: true, data: data);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await _deleteMeal(data['id']);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _clearServingRows() {
    servingNameControllers.clear();
    servingGramControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Manage Meals',
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: lightBlueTheme.colorScheme.tertiary,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMealDialog(isEditing: false),
        backgroundColor: lightBlueTheme.colorScheme.secondary,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: meals.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading meals'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: lightBlueTheme.colorScheme.primary,
              ),
            );
          }

          final data = snapshot.data!.docs.map((doc) {
            final meal = doc.data() as Map<String, dynamic>;
            meal['id'] = doc.id;
            return meal;
          }).toList();

          if (data.isEmpty) {
            return const Center(child: Text('No meals found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final meal = data[index];
              return Card(
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(
                    meal['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${meal['calorie']} kcal (per 100g)'),
                  trailing: Icon(
                    Icons.keyboard_arrow_right,
                    color: lightBlueTheme.colorScheme.secondary,
                  ),
                  onTap: () => _showMealDetails(meal),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Helper UI widgets
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty){
            return 'Please enter $label';
          } else if (isNumber){
            if (double.tryParse(value) == null) {
              return '$label must be a number';
            } else if (double.parse(value) < 0) {
              return '$label must be greater than 0';
            }
          }
          return null;
        }
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(': ${value ?? '-'}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
