import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_details.dart';
import 'meal_recommendation.dart';
import 'custom_meal.dart';
import '../functions.dart';

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

class _MealLogPageState extends State<MealLogPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allMeals = [];
  List<QueryDocumentSnapshot> _allRandomMeals = [];
  List<QueryDocumentSnapshot> _allCustomMeals = [];
  final List<QueryDocumentSnapshot> _allFavMeals = [];
  List<QueryDocumentSnapshot> _displayedMeals = [];
  List<QueryDocumentSnapshot> _customMeals = [];
  List<QueryDocumentSnapshot> _favMeals = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _logFormKey = GlobalKey<FormState>();
  late TabController _tabController;

  Map<String, double> _consumed = {
    'Calories': 0,
    'Protein_g': 0,
    'Carbs_g': 0,
    'Fats_g': 0,
  };

  final TextEditingController _sizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRandomMeals();
    _loadCustomMeals();
    _loadFavMeals();
    _loadConsumed();
    _sizeController.text = '100';
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  Future<void> _loadConsumed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('mealLogs')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: widget.logDate)
          .where('mealType', isEqualTo: widget.mealType)
          .get();

      double tCal = 0, tProt = 0, tCarb = 0, tFat = 0;
      for (var doc in query.docs) {
        final data = doc.data();
        final mealID = data['mealID'];
        final serving = (data['servingSize'] ?? 0.0).toDouble();

        var mDoc = await FirebaseFirestore.instance
            .collection('meals')
            .doc(mealID)
            .get();
        if (!mDoc.exists) {
          mDoc = await FirebaseFirestore.instance
              .collection('custom_meal')
              .doc(uid)
              .collection('meals')
              .doc(mealID)
              .get();
        }

        if (mDoc.exists) {
          final mData = mDoc.data()!;
          final ratio = serving / 100.0;
          tCal += (mData['calorie'] ?? 0.0) * ratio;
          tProt += (mData['protein'] ?? 0.0) * ratio;
          tCarb += (mData['carb'] ?? 0.0) * ratio;
          tFat += (mData['fat'] ?? 0.0) * ratio;
        }
      }

      if (mounted) {
        setState(() {
          _consumed = {
            'Calories': tCal,
            'Protein_g': tProt,
            'Carbs_g': tCarb,
            'Fats_g': tFat,
          };
        });
      }
    } catch (e) {
      debugPrint("Error loading consumed nutrients: $e");
    }
  }

  Future<void> _loadFavMeals() async {
    setState(() => _isLoading = true);
    QuerySnapshot allSnapshot = await FirebaseFirestore.instance
        .collection('meals')
        .where('deleted', isEqualTo: false)
        .get();
    _allMeals = allSnapshot.docs;
    QuerySnapshot favSnapshot = await FirebaseFirestore.instance
        .collection('fav_meals')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('meals')
        .where('liked', isEqualTo: true)
        .get();
    final favMeals = favSnapshot.docs;
    _allFavMeals.clear();

    if (_allMeals.isNotEmpty && favMeals.isNotEmpty) {
      for (var fav in favMeals) {
        for (var meal in _allMeals) {
          if (meal.id == fav.id) {
            _allFavMeals.add(meal);
            break;
          }
        }
      }
    }

    if (_allFavMeals.isNotEmpty) {
      var shuffled = List<QueryDocumentSnapshot>.from(_allFavMeals)
        ..shuffle(Random());
      _favMeals = shuffled.toList();
    } else {
      _favMeals = [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadCustomMeals() async {
    setState(() => _isLoading = true);
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('custom_meal')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('meals')
        .where('deleted', isEqualTo: false)
        .get();
    _allCustomMeals = snapshot.docs;

    if (_allCustomMeals.isNotEmpty) {
      var shuffled = List<QueryDocumentSnapshot>.from(_allCustomMeals)
        ..shuffle(Random());
      _customMeals = shuffled.toList();
    } else {
      _customMeals = [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadRandomMeals() async {
    setState(() => _isLoading = true);
    final snapshot = await Database.getSnapshotNoOrder('meals');
    _allRandomMeals = snapshot.docs;

    if (_allRandomMeals.isNotEmpty) {
      _allRandomMeals.shuffle(Random());
      _displayedMeals = _allRandomMeals
          .where(
            (meal) =>
                (meal['foodCategory'] ?? '').toString().contains(
                  widget.mealType,
                ) ||
                (meal['foodCategory'] ?? '').toString().contains('Anytime') &&
                    meal['deleted'] == false,
          )
          .take(10)
          .toList();
    }
    setState(() => _isLoading = false);
  }

  void _searchMeals(String query) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty) {
      setState(() {
        _isSearching = false;
        _displayedMeals = _allRandomMeals
            .where(
              (meal) =>
                  (meal['foodCategory'] ?? '').toString().contains(
                    widget.mealType,
                  ) ||
                  (meal['foodCategory'] ?? '').toString().contains('Anytime') &&
                      meal['deleted'] == false,
            )
            .take(5)
            .toList();
      });
    } else {
      setState(() {
        _isSearching = true;
        _allMeals = [..._allRandomMeals, ..._allCustomMeals];
        _displayedMeals = _allMeals
            .where(
              (meal) =>
                  (meal['name'] ?? '').toString().toLowerCase().contains(
                    lowerQuery,
                  ) &&
                  meal['deleted'] == false,
            )
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          _buildTargetSummary(),
          _buildSearchBar(),
          Expanded(
            child: _isSearching
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        "Search Results",
                        "${_displayedMeals.length} found",
                      ),
                      const SizedBox(height: 12),
                      _displayedMeals.isEmpty
                          ? _buildSearchEmptyState()
                          : _buildMealList(_displayedMeals),
                    ],
                  )
                : _isLoading
                ? _buildLoadingState()
                : Column(
                    children: [
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                              child: Column(
                                children: [
                                  _buildSectionHeader('Recommended For You', 'Based on your needs'),
                                  const SizedBox(height: 16),
                                  MealRecommender(
                                    nutritionalTargets: _calculateBalance(),
                                    mealType: widget.mealType,
                                    logDate: widget.logDate,
                                    onMealLogged: () {
                                      _loadConsumed(); // Refresh balance dashboard
                                    },
                                  ),
                                ]
                              )
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                              child: Column(
                                children: [
                                  _buildSectionHeader('Favourite Meals', 'Your favourites'),
                                  const SizedBox(height: 16),
                                  _buildMealList(_favMeals),
                                ]
                              )
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                              child: Column(
                                children: [
                                  _buildCustomMealsSection(),
                                  const SizedBox(height: 16),
                                  _buildMealList(_customMeals),
                                ]
                              )
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateBalance() {
    final t = widget.nutritionalTargets;
    if (t == null) return {};

    return {
      'Calories': (t['Calories'] - _consumed['Calories']!).clamp(
        0.0,
        double.infinity,
      ),
      'Protein_g': (t['Protein_g'] - _consumed['Protein_g']!).clamp(
        0.0,
        double.infinity,
      ),
      'Carbs_g': (t['Carbs_g'] - _consumed['Carbs_g']!).clamp(
        0.0,
        double.infinity,
      ),
      'Fats_g': (t['Fats_g'] - _consumed['Fats_g']!).clamp(
        0.0,
        double.infinity,
      ),
    };
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 18),
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
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  widget.logDate,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
            onPressed: () {
              _loadRandomMeals();
              _loadCustomMeals();
              _loadFavMeals();
              _loadConsumed();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
        ),
        labelColor: const Color(0xFF1E88E5),
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Recommended"),
          Tab(text: "Favourite"),
          Tab(text: "Custom"),
        ],
      ),
    );
  }

  Widget _buildTargetSummary() {
    final t = widget.nutritionalTargets;
    if (t == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text(
                "Balance:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              _miniTarget(
                'Calories',
                t['Calories'],
                _consumed['Calories']!,
                'kcal',
                Colors.orange,
              ),
              _miniTarget(
                'Protein',
                t['Protein_g'],
                _consumed['Protein_g']!,
                'g',
                Colors.blue,
              ),
              _miniTarget(
                'Carbs',
                t['Carbs_g'],
                _consumed['Carbs_g']!,
                'g',
                Colors.brown,
              ),
              _miniTarget(
                'Fats',
                t['Fats_g'],
                _consumed['Fats_g']!,
                'g',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTarget(
    String label,
    dynamic target,
    double consumed,
    String unit,
    Color color,
  ) {
    double tVal = (target is num) ? target.toDouble() : 0.0;
    double balance = (tVal - consumed).clamp(0.0, double.infinity);

    return Column(
      children: [
        Text(
          balance.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          "$label",
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "($unit)",
          style: TextStyle(fontSize: 8, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
        onChanged: _searchMeals,
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
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    _searchMeals('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomMealsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionHeader("Custom Meals", "Your creations"),
        TextButton.icon(
          onPressed: () async {
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CustomMealPage(
                  defaultCategory: widget.mealType,
                  editMeal: false,
                  editRecipe: false,
                  logDate: widget.logDate,
                  nutritionalTargets: widget.nutritionalTargets,
                ),
              ),
            );
            //_loadCustomMeals();
          },
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text(
            "Create New",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E88E5)),
        ),
      ],
    );
  }

  Widget _buildMealList(List<QueryDocumentSnapshot> meals) {
    return Column(children: meals.map((doc) => _buildMealCard(doc)).toList());
  }

  Widget _buildMealCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unnamed meal';
    final cal = data['calorie']?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MealDetailsPage(data: data, mealId: doc.id),
            ),
          );
          await _loadFavMeals();
        },
        contentPadding: const EdgeInsets.all(7),
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.restaurant_menu_rounded,
            color: Colors.blue.shade400,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "${cal.toStringAsFixed(0)} kcal per 100g",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.add_circle,
            color: Color(0xFF42A5F5),
            size: 32,
          ),
          onPressed: () => _logMeal(
            doc.id,
            name,
            widget.mealType,
            FirebaseAuth.instance.currentUser!.uid,
            widget.logDate,
            {
              'calorie': cal,
              'protein': data['protein']?.toDouble() ?? 0.0,
              'carb': data['carb']?.toDouble() ?? 0.0,
              'fat': data['fat']?.toDouble() ?? 0.0,
            },
            servings: data['servings'] ?? [],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF42A5F5),
          ),
          const SizedBox(height: 20),
          Text(
            "Fetching delicious options...",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text(
            "No matches found",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGGING LOGIC & DIALOGS ---

  Future<void> _logMeal(
    String mealID,
    String mealName,
    String mealType,
    String uid,
    String logDate,
    Map<String, dynamic> mealNutrients, {
    List<dynamic>? servings,
  }) async {
    String? selectedServingName;
    _sizeController.text = '100';
    await showDialog(
      context: context,
      builder: (logContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            "Log $mealName",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: _logFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (servings != null && servings.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Select portion size"),
                        value: selectedServingName,
                        items: servings
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s['name'],
                                child: Text("${s['name']} (${s['grams']}g)"),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setDialogState(() {
                          selectedServingName = val;
                          final s = servings.firstWhere(
                            (item) => item['name'] == val,
                          );
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (!_logFormKey.currentState!.validate()) return;
                final size = double.tryParse(_sizeController.text) ?? 100.0;
                final balance = _calculateBalance();
                final exceeds = _checkIfMealExceedsTarget(
                  mealNutrients,
                  size,
                  balance,
                );
                if (exceeds['exceeds']) {
                  await _showExceedConfirmationDialog(
                    logContext,
                    exceeds,
                    mealName,
                    size,
                    mealID,
                    uid,
                    logDate,
                  );
                } else {
                  await _addMealToLog(
                    mealID,
                    mealName,
                    uid,
                    logDate,
                    logContext,
                  );
                }
              },
              child: const Text(
                "Add Meal",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _checkIfMealExceedsTarget(
    Map<String, dynamic> nutrients,
    double size,
    Map<String, dynamic> balance,
  ) {
    if (widget.nutritionalTargets == null) {
      return {'exceeds': false};
    }
    final List<Map<String, dynamic>> exceeding = [];
    final mapKeys = {
      'calorie': 'Calories',
      'protein': 'Protein_g',
      'carb': 'Carbs_g',
      'fat': 'Fats_g',
    };

    mapKeys.forEach((dbKey, targetKey) {
      final mealVal = (nutrients[dbKey] ?? 0.0) * size / 100.0;
      final balanceVal = balance[targetKey] ?? 0.0;

      if (balanceVal >= 0 && mealVal > balanceVal) {
        // include checking even the balance is 0
        exceeding.add({
          'name': targetKey,
          'amount': mealVal,
          'target': balanceVal,
        });
      }
    });
    return {'exceeds': exceeding.isNotEmpty, 'exceedingNutrients': exceeding};
  }

  Future<void> _showExceedConfirmationDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String mealName,
    double size,
    String id,
    String uid,
    String date,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Limit Exceeded"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This portion of $mealName exceeds your REMAINING meal budget for:",
            ),
            const SizedBox(height: 12),
            ...data['exceedingNutrients']
                .map<Widget>(
                  (n) => Text(
                    "• ${n['name']}: ${n['amount'].toStringAsFixed(0)} / ${n['target'].toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
                .toList(),
            const SizedBox(height: 16),
            const Text("Log it anyway?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addMealToLog(id, mealName, uid, date, context);
            },
            child: const Text(
              "Yes, Log It",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMealToLog(
    String mealID,
    String mealName,
    String uid,
    String logDate,
    BuildContext logContext,
  ) async {
    final size = double.tryParse(_sizeController.text) ?? 100.0;
    await Database.addItems('mealLogs', {
      'uid': uid,
      'mealID': mealID,
      'mealType': widget.mealType,
      'mealName': mealName,
      'date': logDate,
      'servingSize': size,
    });
    if (!logContext.mounted) return;
    Navigator.pop(logContext);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$mealName added!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E88E5),
      ),
    );
    _loadConsumed(); // Refresh balance after adding
  }
}
