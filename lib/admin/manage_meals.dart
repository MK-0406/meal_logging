import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../user/nutrition_label_extraction.dart';

bool isMotionBlurredBackground(String imagePath) {
  final bytes = File(imagePath).readAsBytesSync();
  final image = img.decodeImage(bytes);

  if (image == null) return true;

  final gray = img.grayscale(image);
  final edges = img.sobel(gray);

  double total = 0;
  int count = 0;

  for (int y = 0; y < edges.height; y++) {
    for (int x = 0; x < edges.width; x++) {
      final pixel = edges.getPixel(x, y);
      final value = img.getLuminance(pixel);
      total += value;
      count++;
    }
  }

  double edgeStrength = total / count;

  return edgeStrength < 20;
}

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  final CollectionReference meals = FirebaseFirestore.instance.collection('meals');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Controllers for the Dialog
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  String? _foodGroup;
  String? _foodCategory;
  String? _filterGroup;
  String? _filterCategory;
  final List<TextEditingController> _servingNameControllers = [];
  final List<TextEditingController> _servingGramControllers = [];
  Map<String, dynamic> extractedNutrition = {};
  bool isLoadingImage = false;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImageFromCamera() async {
    return await _picker.pickImage(source: ImageSource.camera);
  }

  Future<XFile?> pickImageFromGallery() async {
    return await _picker.pickImage(source: ImageSource.gallery);
  }

  final List<String> _foodGroupItems = [
    'Cooked Food / Dishes', 'Ingredients / Raw Foods', 'Vegetables', 'Processed Foods', 
    'Snacks', 'Beverages', 'Condiments / Sauces', 'Fast Food', 'Desserts / Sweets', 
    'Soups / Stews', 'Salads / Cold Dishes', 'Fish and shellfish', 'Fruits', 'Other'
  ];

  final List<String> _foodCategoryItems = [
    'Breakfast', 'Lunch / Dinner', 'Snack', 'Dessert', 'Anytime', 'Not Applicable'
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final fields = ['name', 'calorie', 'protein', 'carb', 'fat', 'fibre', 'water', 'ash', 'calcium', 'iron', 'phosphorus', 'potassium', 'sodium'];
    for (var f in fields) {
      _controllers[f] = TextEditingController();
    }
    _filterCategory = 'None';
    _filterGroup = 'None';
  }

  void _fillControllers(Map<String, dynamic> data) {
    _controllers['name']!.text = data['name'] ?? '';
    _controllers['calorie']!.text = data['calorie']?.toString() ?? '';
    _controllers['protein']!.text = data['protein']?.toString() ?? '';
    _controllers['carb']!.text = data['carb']?.toString() ?? '';
    _controllers['fat']!.text = data['fat']?.toString() ?? '';
    _controllers['fibre']!.text = data['fibre']?.toString() ?? '';
    _controllers['water']!.text = data['water']?.toString() ?? '';
    _controllers['ash']!.text = data['ash']?.toString() ?? '';
    _controllers['calcium']!.text = data['calcium']?.toString() ?? '';
    _controllers['iron']!.text = data['iron']?.toString() ?? '';
    _controllers['phosphorus']!.text = data['phosphorus']?.toString() ?? '';
    _controllers['potassium']!.text = data['potassium']?.toString() ?? '';
    _controllers['sodium']!.text = data['sodium']?.toString() ?? '';
    _foodGroup = data['foodGroup'];
    _foodCategory = data['foodCategory'];

    _servingNameControllers.clear();
    _servingGramControllers.clear();
    if (data['servings'] != null) {
      for (var s in data['servings']) {
        _servingNameControllers.add(TextEditingController(text: s['name']));
        _servingGramControllers.add(TextEditingController(text: s['grams'].toString()));
      }
    }
  }

  void _clearControllers() {
    for (var c in _controllers.values) {
      c.clear();
    }
    _foodGroup = null;
    _foodCategory = null;
    _servingNameControllers.clear();
    _servingGramControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildFilterDropdown(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: meals.where('deleted', isEqualTo: false).orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading meals'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }

                final allDocs = snapshot.data!.docs;
                var data = allDocs.map((doc) {
                  final meal = doc.data() as Map<String, dynamic>;
                  meal['id'] = doc.id;
                  return meal;
                }).where((meal) {
                  return meal['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (_filterGroup != 'None') {
                  data = data.where((meal) => meal['foodGroup'] == _filterGroup).toList();
                }

                if (_filterCategory != 'None') {
                  data = data.where((meal) => meal['foodCategory'] == _filterCategory).toList();
                }

                if (data.isEmpty) return const Center(child: Text('No meals found.'));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: data.length,
                  itemBuilder: (context, index) => _buildMealCard(data[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _searchQuery.isNotEmpty ? null : Padding(
        padding: const EdgeInsets.only(bottom: 85),
        child: FloatingActionButton.extended(
          onPressed: () => _showMealDialog(isEditing: false),
          backgroundColor: const Color(0xFF42A5F5),
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("Add New Meal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Meal Management", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          Text("Manage the global food and nutrient database", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search for meals...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF42A5F5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.close), onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = "");
              }) 
            : null,
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Row(
      children: [
        const SizedBox(width: 15),
        Expanded(
          flex: 4,
          child: _buildDropdown('Food Group', _filterGroup, ['None', ..._foodGroupItems], (val) => setState(() => _filterGroup = val)),
        ),
        const SizedBox(width: 10),
        Expanded(
            flex: 3,
            child: _buildDropdown('Food Category', _filterCategory, ['None', ..._foodCategoryItems],  (val) => setState(() => _filterCategory = val))
        ),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildDropdown(String label, String? val, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, top: 3),
      child: DropdownButtonFormField<String>(
        initialValue: val, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            fillColor: Colors.white, filled: true),
        validator: (v) => v == null ? "Required" : null,
      ),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () => _showMealDetails(meal),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: const Color(0xFF42A5F5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF1E88E5)),
        ),
        title: Text(meal['name'] ?? "Unnamed Meal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("${meal['calorie']} kcal (per 100g)", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
      ),
    );
  }

  void _showMealDetails(Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36, backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                  child: const Icon(Icons.restaurant_rounded, size: 40, color: Color(0xFF1E88E5)),
                ),
                const SizedBox(height: 16),
                Text(meal['name'] ?? "Meal", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("${meal['foodCategory']} • ${meal['foodGroup']}", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                const SizedBox(height: 24),
                _detailRow("Calories", "${meal['calorie']} kcal"),
                _detailRow("Protein", "${meal['protein']} g"),
                _detailRow("Carbs", "${meal['carb']} g"),
                _detailRow("Fat", "${meal['fat']} g"),
                _detailRow("Water", "${meal['water']} g"),
                _detailRow("Fibre", "${meal['fibre']} g"),
                _detailRow("Calcium", "${meal['calcium']} mg"),
                _detailRow("Iron", "${meal['iron']} mg"),
                _detailRow("Potassium", "${meal['potassium']} mg"),
                _detailRow("Sodium", "${meal['sodium']} mg"),
                _detailRow("Phosphorus", "${meal['phosphorus']} mg"),
                _detailRow("Ash", "${meal['ash']} g"),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showMealDialog(isEditing: true, data: meal);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text("Edit"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E88E5),
                          side: const BorderSide(color: Color(0xFF1E88E5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await _showDeleteConfirm();
                          if (confirm == true) {
                            await meals.doc(meal['id']).update({'deleted': true, 'updatedAt': FieldValue.serverTimestamp()});
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Close", style: TextStyle(color: Colors.grey.shade600))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirm() {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Meal?"), content: const Text("This action cannot be undone. Are you sure?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Widget _buildOption(void Function(void Function()) setDialogState) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.camera_alt),
      onSelected: (val) async {
        setDialogState(() {
          isLoadingImage = true;
        });
        await Future.delayed(const Duration(milliseconds: 50));
        XFile? image;
        if (val == 'camera') {
          image = await pickImageFromCamera();
        } else if (val == 'gallery') {
          image = await pickImageFromGallery();
        }
        if (image != null) {
          Map<String, dynamic>? result = {};
          final NutritionService nutritionService = NutritionService();

          String extractedText = await nutritionService.extractTextFromImage(
            image.path,
          );

          result = await nutritionService.analyzeNutrition(extractedText);

          if (result != null && result.length > 1) {
            final nutrients = [
              "calories",
              "water_g",
              "protein_g",
              "fat_g",
              "carbohydrates_g",
              "fiber_g",
              "calcium_mg",
              "iron_mg",
              "potassium_mg",
              "sodium_mg",
              "phosphorus_mg",
              "ash_g",
            ];
            for (var nutrient in nutrients) {
              result[nutrient] = result[nutrient] ?? 0;
            }
            setDialogState(() {
              extractedNutrition = result!;
            });
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result!.length > 1
                      ? "Please double check the values"
                      : result["error"],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Color(0xFF1E88E5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
        setDialogState(() {
          isLoadingImage = false;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'camera',
          child: Text('Camera', style: TextStyle(color: Colors.black)),
        ),
        const PopupMenuItem(
          value: 'gallery',
          child: Text('Gallery', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  void _showMealDialog({bool isEditing = false, Map<String, dynamic>? data}) {
    if (isEditing && data != null) {
      _fillControllers(data);
    } else {
      _clearControllers();
    }
    extractedNutrition.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isEditing ? "Update Meal" : "Add New Meal", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    _buildDialogInput("Meal Name", _controllers['name']!, null, false),
                    _buildDialogDropdown("Food Group", _foodGroup, _foodGroupItems, (v) => setDialogState(() => _foodGroup = v)),
                    _buildDialogDropdown("Category", _foodCategory, _foodCategoryItems, (v) => setDialogState(() => _foodCategory = v)),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Nutritional Info (per 100g)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Expanded(
                          flex: 1,
                          child: isLoadingImage
                              ? Center(child: const CircularProgressIndicator())
                              : _buildOption(setDialogState),
                        ),
                      ]
                    ),
                    const SizedBox(height: 16),
                    _buildNutrientGrid(),
                    const SizedBox(height: 24),
                    const Text("Serving Options", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ...List.generate(_servingNameControllers.length, (i) => _buildServingRow(i, setDialogState)),
                    TextButton.icon(onPressed: () => setDialogState(() { _servingNameControllers.add(TextEditingController()); _servingGramControllers.add(TextEditingController()); }), icon: const Icon(Icons.add_circle_outline), label: const Text("Add Serving Option")),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () { _clearControllers(); Navigator.pop(context); }, child: const Text("Cancel"))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton(
                          onPressed: () => isEditing ? _handleUpdate(data!['id']) : _handleAdd(),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white),
                          child: Text(isEditing ? "Update" : "Add"),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientGrid() {
    return Column(children: [
      Row(children: [Expanded(child: _buildDialogInput("Calories (kcal)", _controllers['calorie']!, "calories", true)), const SizedBox(width: 12), Expanded(child: _buildDialogInput("Water (g)", _controllers['water']!, "water_g", true))]),
      Row(children: [Expanded(child: _buildDialogInput("Protein (g)", _controllers['protein']!, "protein_g", true)), const SizedBox(width: 12), Expanded(child: _buildDialogInput("Carbs (g)", _controllers['carb']!, "carbohydrates_g", true))]),
      Row(children: [Expanded(child: _buildDialogInput("Fat (g)", _controllers['fat']!, "fat_g", true)), const SizedBox(width: 12), Expanded(child: _buildDialogInput("Fibre (g)", _controllers['fibre']!, "fiber_g", true))]),
      Row(children: [Expanded(child: _buildDialogInput("Calcium (mg)", _controllers['calcium']!, "calcium_mg", true)), const SizedBox(width: 12), Expanded(child: _buildDialogInput("Iron (mg)", _controllers['iron']!, "iron_mg", true))]),
      Row(children: [Expanded(child: _buildDialogInput("Potassium (mg)", _controllers['potassium']!, "potassium_mg", true)), const SizedBox(width: 12), Expanded(child: _buildDialogInput("Sodium (mg)", _controllers['sodium']!, "sodium_mg", true))]),
      Row(children: [Expanded(child: _buildDialogInput("Phosphorus (mg)", _controllers['phosphorus']!, "phosphorus_mg", true)), const SizedBox(width: 12), Expanded(child: _buildDialogInput("Ash (g)", _controllers['ash']!, "ash_g", true))]),
    ]);
  }

  Widget _buildServingRow(int i, Function setDialogState) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
      Expanded(flex: 2, child: TextFormField(controller: _servingNameControllers[i], decoration: InputDecoration(labelText: 'Size Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
      const SizedBox(width: 10),
      Expanded(flex: 1, child: TextFormField(controller: _servingGramControllers[i], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Grams', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => setDialogState(() { _servingNameControllers.removeAt(i); _servingGramControllers.removeAt(i); })),
    ]));
  }

  Widget _buildDialogInput(String label, TextEditingController ctrl, String? extractedVal, bool isNum) {
    if (isNum && extractedNutrition[extractedVal] != null) {
      ctrl.text = extractedNutrition[extractedVal].toString();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (isNum && double.tryParse(v) == null) return "Invalid";
          return null;
        },
        onChanged: (val) {
          if (isNum) {
            extractedNutrition[extractedVal!] = double.tryParse(val);
          }
        },
      ),
    );
  }

  Widget _buildDialogDropdown(String label, String? val, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: val, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: (v) => v == null ? "Required" : null,
      ),
    );
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) return;
    await meals.add(_getFormData());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleUpdate(String id) async {
    if (!_formKey.currentState!.validate()) return;
    await meals.doc(id).update(_getFormData());
    if (mounted) Navigator.pop(context);
  }

  Map<String, dynamic> _getFormData() {
    return {
      'name': _controllers['name']!.text.trim(),
      'calorie': double.tryParse(_controllers['calorie']!.text) ?? 0,
      'protein': double.tryParse(_controllers['protein']!.text) ?? 0,
      'carb': double.tryParse(_controllers['carb']!.text) ?? 0,
      'fat': double.tryParse(_controllers['fat']!.text) ?? 0,
      'fibre': double.tryParse(_controllers['fibre']!.text) ?? 0,
      'water': double.tryParse(_controllers['water']!.text) ?? 0,
      'ash': double.tryParse(_controllers['ash']!.text) ?? 0,
      'calcium': double.tryParse(_controllers['calcium']!.text) ?? 0,
      'iron': double.tryParse(_controllers['iron']!.text) ?? 0,
      'phosphorus': double.tryParse(_controllers['phosphorus']!.text) ?? 0,
      'potassium': double.tryParse(_controllers['potassium']!.text) ?? 0,
      'sodium': double.tryParse(_controllers['sodium']!.text) ?? 0,
      'foodGroup': _foodGroup, 'foodCategory': _foodCategory,
      'servings': List.generate(_servingNameControllers.length, (i) => {'name': _servingNameControllers[i].text, 'grams': double.tryParse(_servingGramControllers[i].text) ?? 0}),
      'deleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
