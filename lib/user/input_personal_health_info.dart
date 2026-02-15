import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'main_dashboard.dart';
import '../custom_styles.dart';
import '../functions.dart';
import 'package:http/http.dart' as http;

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bmiController = TextEditingController();
  final _bloodPressureSystolicController = TextEditingController();
  final _bloodPressureDiastolicController = TextEditingController();
  final _cholesterolLevelController = TextEditingController();
  final _bloodSugarLevelController = TextEditingController();

  late var isEditing = false;

  String? _gender;
  double? bmi;

  String heightUnit = 'cm';
  String weightUnit = 'kg';
  String cholesterolUnit = 'mmol/L';
  String bloodSugarUnit = 'mmol/L';

  double heightM = 0;
  double weightKg = 0;
  double cholesterolMmolL = 0;
  double bloodSugarMmolL = 0;

  void changeUnit() {
    if (double.tryParse(_cholesterolLevelController.text) != null) {
      switch (cholesterolUnit) {
        case 'mg/dL':
          cholesterolMmolL = double.parse(_cholesterolLevelController.text) * 0.02586;
          break;
        case 'mmol/L':
          cholesterolMmolL = double.parse(_cholesterolLevelController.text);
          break;
      }
      switch (bloodSugarUnit) {
        case 'mg/dL':
          bloodSugarMmolL = double.parse(_bloodSugarLevelController.text) * 0.05556;
          break;
        case 'mmol/L':
          bloodSugarMmolL = double.parse(_bloodSugarLevelController.text);
          break;
      }
      cholesterolMmolL = double.parse(cholesterolMmolL.toStringAsFixed(2));
      bloodSugarMmolL = double.parse(bloodSugarMmolL.toStringAsFixed(2));
      heightM = double.parse(heightM.toStringAsFixed(2));
      weightKg = double.parse(weightKg.toStringAsFixed(2));
    }
  }

  void calculateBMI() {
    switch (heightUnit) {
      case 'cm':
        heightM = (double.tryParse(_heightController.text) ?? 0) / 100;
        break;
      case 'ft':
        heightM = (double.tryParse(_heightController.text) ?? 0) * 0.305;
        break;
      case 'm':
        heightM = (double.tryParse(_heightController.text) ?? 0);
        break;
    }
    switch (weightUnit) {
      case 'kg':
        weightKg = (double.tryParse(_weightController.text) ?? 0);
        break;
      case 'lb':
        weightKg = (double.tryParse(_weightController.text) ?? 0) * 0.453592;
        break;
    }

    if (heightM > 0) {
      setState(() {
        bmi = weightKg / (heightM * heightM);
        bmi = double.parse(bmi!.toStringAsFixed(2));
        _bmiController.text = bmi.toString();
      });
    }
  }

  Map<String, dynamic>? userData;
  Map<String, dynamic>? userInfoData;

  @override
  void initState() {
    super.initState();
    fetchUserData();

    _heightController.addListener(_onHeightOrWeightChanged);
    _weightController.addListener(_onHeightOrWeightChanged);
  }

  void _onHeightOrWeightChanged() {
    final heightText = _heightController.text;
    final weightText = _weightController.text;

    if (heightText.isEmpty || weightText.isEmpty) {
      setState(() {
        _bmiController.text = '';
        bmi = null;
      });
      return;
    }

    final height = double.tryParse(heightText);
    final weight = double.tryParse(weightText);

    if (height != null && weight != null && height > 0 && weight > 0) {
      calculateBMI();
    }
  }
  
  void onHeightUnitChanged(String changedUnit) {
    final previousUnit = heightUnit;
    if (previousUnit == changedUnit) return;

    double height = double.parse(_heightController.text);

    switch (previousUnit) {

      case 'cm':
        switch (changedUnit) {
          case 'm':
            height = height / 100;
            break;
          case 'ft':
            height = height / 30.48;
            break;
        }
        break;

      case 'm':
        switch (changedUnit) {
          case 'cm':
            height = height * 100.roundToDouble();
            break;
          case 'ft':
            height = (height / 0.305);
            break;
        }
        break;

      case 'ft':
        switch (changedUnit) {
          case 'cm':
            height = (height * 30.48).roundToDouble();
            break;
          case 'm':
            height = height * 0.305;
            break;
        }
        break;
    }
    heightUnit = changedUnit;
    _heightController.text = height.toStringAsFixed(2);
  }

  void onWeightUnitChanged(String changedUnit) {
    final previousUnit = weightUnit;
    if (previousUnit == changedUnit) return;

    double weight = double.parse(_weightController.text);

    switch (previousUnit) {

      case 'kg':
        weight = weight * 2.205;
        break;

      case 'lb':
        weight = weight / 2.205;
        break;
    }
    weightUnit = changedUnit;
    _weightController.text = weight.toStringAsFixed(1);
  }

  void onCholesterolUnitChanged(String changedUnit) {
    final previousUnit = cholesterolUnit;
    if (previousUnit == changedUnit) return;

    double cholesterol = double.parse(_cholesterolLevelController.text);

    switch (previousUnit) {

      case 'mmol/L':
        cholesterol = cholesterol / 0.02586;
        break;

      case 'mg/dL':
        cholesterol = cholesterol * 0.02586;
        break;
    }
    cholesterolUnit = changedUnit;
    _cholesterolLevelController.text = cholesterol.toStringAsFixed(1);
  }

  void onBloodSugarUnitChanged(String changedUnit) {
    final previousUnit = bloodSugarUnit;
    if (previousUnit == changedUnit) return;

    double bloodSugar = double.parse(_bloodSugarLevelController.text);

    switch (previousUnit) {

      case 'mmol/L':
        bloodSugar = bloodSugar / 0.05556;
        break;

      case 'mg/dL':
        bloodSugar = bloodSugar * 0.05556;
        break;
    }
    bloodSugarUnit = changedUnit;
    _bloodSugarLevelController.text = bloodSugar.toStringAsFixed(1);
  }

  Future<void> fetchUserData() async {
    final userDoc = await Database.getDocument('users', null);
    final userInfoDoc = await Database.getDocument('usersInfo', null);
    if (userDoc.exists && userInfoDoc.exists) {
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>?;
        userInfoData = userInfoDoc.data() as Map<String, dynamic>?;
        _nameController.text = userInfoData?['name']?.toString() ?? '';
        _ageController.text = userInfoData?['age']?.toString() ?? '';
        _gender = userInfoData?['gender']?.toString();
        _heightController.text = (userInfoData?['height_m'] * 100)?.toStringAsFixed(0) ?? '';
        _weightController.text = userInfoData?['weight_kg']?.toString() ?? '';
        _bmiController.text = userInfoData?['bmi']?.toString() ?? '';
        _bloodPressureSystolicController.text = userInfoData?['bloodPressureSystolic']?.toString() ?? '';
        _bloodPressureDiastolicController.text = userInfoData?['bloodPressureDiastolic']?.toString() ?? '';
        _cholesterolLevelController.text = userInfoData?['cholesterol_mmolL']?.toString() ?? '';
        _bloodSugarLevelController.text = userInfoData?['bloodSugar_mmolL']?.toString() ?? '';
        isEditing = true;
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("BASIC INFORMATION"),
                    const SizedBox(height: 12),
                    _buildFormCard([
                      InputTextField(label: 'Full Name', controller: _nameController, isNumber: false, isInt: false),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: InputTextField(label: 'Age', controller: _ageController, isNumber: true, isInt: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDropdownField('Gender', ['Male', 'Female'], _gender, (v) => setState(() => _gender = v))),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _buildSectionLabel("BODY METRICS"),
                    const SizedBox(height: 12),
                    _buildFormCard([
                      _buildMetricRow('Height', _heightController, ['cm', 'm', 'ft'], heightUnit, (v) => setState(() => onHeightUnitChanged(v!))),
                      const SizedBox(height: 16),
                      _buildMetricRow('Weight', _weightController, ['kg', 'lb'], weightUnit, (v) => setState(() => onWeightUnitChanged(v!))),
                      const SizedBox(height: 16),
                      _buildReadOnlyField('Body Mass Index (BMI)', _bmiController),
                    ]),
                    const SizedBox(height: 28),
                    _buildSectionLabel("HEALTH INDICATORS"),
                    const SizedBox(height: 12),
                    _buildFormCard([
                      Row(
                        children: [
                          Expanded(child: InputTextField(label: 'Systolic (BP)', controller: _bloodPressureSystolicController, isNumber: true, isInt: false)),
                          const SizedBox(width: 16),
                          Expanded(child: InputTextField(label: 'Diastolic (BP)', controller: _bloodPressureDiastolicController, isNumber: true, isInt: false)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMetricRow('Cholesterol', _cholesterolLevelController, ['mg/dL', 'mmol/L'], cholesterolUnit, (v) => setState(() => onCholesterolUnitChanged(v!))),
                      const SizedBox(height: 16),
                      _buildMetricRow('Blood Sugar', _bloodSugarLevelController, ['mg/dL', 'mmol/L'], bloodSugarUnit, (v) => setState(() => onBloodSugarUnitChanged(v!))),
                    ]),
                    const SizedBox(height: 40),
                    _buildSaveButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
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
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 25),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Update Profile' : 'Input Profile',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const Text(
                  'Keep your health data accurate',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.blueGrey.shade300,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMetricRow(String label, TextEditingController controller, List<String> units, String selectedUnit, Function(String?) onUnitChanged) {
    return Row(
      children: [
        Expanded(flex: 3, child: InputTextField(label: label, controller: controller, isNumber: true, isInt: false)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _buildDropdownField('Unit', units, selectedUnit, onUnitChanged)),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> options, String? value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.blue.shade50.withValues(alpha: 0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
          boxShadow: [BoxShadow(color: const Color(0xFF42A5F5).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: _handleSave,
          child: const Text("Save Profile Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      changeUnit();
      _saveProfileData();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainDashboard()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Health data updated successfully!'),
          backgroundColor: const Color(0xFF1E88E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> regenerateRecommendation(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final todayDate = DateFormat('EEEE, dd MMM yyyy').format(date);
    final yesterday = date.subtract(const Duration(days: 1));

    final List<Map<String, dynamic>> todayMealData = await Database.getItemsWithConditions(
      'mealLogs', 'uid',
      conditions: {
        'date': DateFormat('EEEE, dd MMM yyyy').format(yesterday),
      },
    );

    double proteinIntake = 0, carbsIntake = 0, fatsIntake = 0;
    for (final data in todayMealData) {
      final mealDoc = await Database.getDocument('meals', data['mealID']);
      if (mealDoc.exists) {
        final mData = mealDoc.data() as Map<String, dynamic>;
        double ratio = (data['servingSize'] ?? 100) / 100;
        proteinIntake += (mData['protein'] ?? 0) * ratio;
        carbsIntake += (mData['carb'] ?? 0) * ratio;
        fatsIntake += (mData['fat'] ?? 0) * ratio;
      }
    }

    if (proteinIntake == 0 && carbsIntake == 0 && fatsIntake == 0) return;

    final url = Uri.parse("https://meal-recommender-model.onrender.com/predict");
    final bodyData = {
      "features": [
        int.tryParse(_ageController.text) ?? 0,
        (heightM * 100),
        weightKg,
        bmi,
        double.tryParse(_bloodPressureSystolicController.text) ?? 0,
        double.tryParse(_bloodPressureDiastolicController.text) ?? 0,
        (cholesterolMmolL * 38.67),
        (bloodSugarMmolL * 18),
        proteinIntake, carbsIntake, fatsIntake,
      ]
    };

    final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(bodyData));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final prediction = data['prediction'][0];
    final results = {
      'Protein_g': prediction[0], 'Carbs_g': prediction[1], 'Fats_g': prediction[2],
      'Calories': (4 * (prediction[0] + prediction[1]) + 9 * prediction[2]).round(),
    };

    await FirebaseFirestore.instance.collection('recommendations').doc(uid).collection('dates').doc(todayDate).set(results);
  }

  void _saveProfileData() async {
    await Database.setItems('usersInfo', null, {
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text) ?? 0,
      'gender': _gender,
      'height_m': heightM, 'weight_kg': weightKg, 'bmi': bmi,
      'bloodPressureSystolic': double.tryParse(_bloodPressureSystolicController.text) ?? 0,
      'bloodPressureDiastolic': double.tryParse(_bloodPressureDiastolicController.text) ?? 0,
      'cholesterol_mmolL': cholesterolMmolL, 'bloodSugar_mmolL': bloodSugarMmolL,
      'updatedAt': FieldValue.serverTimestamp(),
      'ban': false
    });

    if (isEditing) {
      await regenerateRecommendation(DateTime.now());
      await regenerateRecommendation(DateTime.now().add(const Duration(days: 1)));
    }
  }
}
