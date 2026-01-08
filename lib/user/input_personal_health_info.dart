import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:meal_logging/main.dart';
import 'main_dashboard.dart';
import '../custom_styles.dart';
import '../functions.dart';
import 'package:http/http.dart' as http;

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  _ProfileFormScreenState createState() => _ProfileFormScreenState();
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

  double height_m = 0;
  double weight_kg = 0;
  double cholesterol_mmolL = 0;
  double bloodSugar_mmolL = 0;

  void changeUnit() {
    if (double.tryParse(_cholesterolLevelController.text) != null) {
      switch (cholesterolUnit) {
        case 'mg/dL':
          cholesterol_mmolL = double.parse(_cholesterolLevelController.text) * 0.02586;
          break;
        case 'mmol/L':
          cholesterol_mmolL = double.parse(_cholesterolLevelController.text);
          break;
      }
      switch (bloodSugarUnit) {
        case 'mg/dL':
          bloodSugar_mmolL = double.parse(_bloodSugarLevelController.text) * 0.05556;
          break;
        case 'mmol/L':
          bloodSugar_mmolL = double.parse(_bloodSugarLevelController.text);
          break;
      }
      cholesterol_mmolL = double.parse(cholesterol_mmolL.toStringAsFixed(2));
      bloodSugar_mmolL = double.parse(bloodSugar_mmolL.toStringAsFixed(2));
      height_m = double.parse(height_m.toStringAsFixed(2));
      weight_kg = double.parse(weight_kg.toStringAsFixed(2));
    }
  }

  void calculateBMI() {
    switch (heightUnit) {
      case 'cm':
        height_m = double.parse(_heightController.text) / 100;
        break;
      case 'ft':
        height_m = double.parse(_heightController.text) * 0.3048;
        break;
      case 'm':
        height_m = double.parse(_heightController.text);
        break;
    }
    switch (weightUnit) {
      case 'kg':
        weight_kg = double.parse(_weightController.text);
        break;
      case 'lb':
        weight_kg = double.parse(_weightController.text) * 0.453592;
        break;
    }

    setState(() {
      bmi = weight_kg / (height_m * height_m);
      bmi = double.parse(bmi!.toStringAsFixed(2));
      _bmiController.text = bmi.toString();
    });
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
      _bmiController.text = bmi?.toStringAsFixed(2) ?? '';
    }
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
        _gender = userInfoData?['gender']?.toString() ?? '';
        _heightController.text = (userInfoData?['height_m'] * 100)?.toString() ?? '';
        _weightController.text = userInfoData?['weight_kg']?.toString() ?? '';
        _bmiController.text = userInfoData?['bmi']?.toString() ?? '';
        _bloodPressureSystolicController.text =
            userInfoData?['bloodPressureSystolic']?.toString() ?? '';
        _bloodPressureDiastolicController.text =
            userInfoData?['bloodPressureDiastolic']?.toString() ?? '';
        _cholesterolLevelController.text =
            userInfoData?['cholesterol_mmolL']?.toString() ?? '';
        _bloodSugarLevelController.text =
            userInfoData?['bloodSugar_mmolL']?.toString() ?? '';
        isEditing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal & Health Information', style: TextStyle(fontSize: 19.5, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your details:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: lightBlueTheme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// PERSONAL INFO
                    _buildSectionHeader('Personal Information'),
                    const SizedBox(height: 14),
                    InputTextField(label: 'User Name',controller: _nameController, isNumber: false, isInt: false),
                    const SizedBox(height: 17),
                    InputTextField(label: 'Age', controller: _ageController, isNumber: true, isInt: true,),
                    const SizedBox(height: 17),
                    _buildDropdownField('Gender', ['Male', 'Female'], _gender,
                            (val) => setState(() => _gender = val)),

                    const SizedBox(height: 30),
                    _buildSectionHeader('Health Information'),
                    const SizedBox(height: 14),

                    _buildHeightWeightFields(),
                    const SizedBox(height: 17),

                    _buildReadOnlyField('Body Mass Index (BMI)', _bmiController),
                    const SizedBox(height: 17),

                    InputTextField(label: 'Blood Pressure Systolic', controller: _bloodPressureSystolicController, isNumber: true, isInt: false),
                    const SizedBox(height: 17),
                    InputTextField(label: 'Blood Pressure Diastolic', controller: _bloodPressureDiastolicController, isNumber: true, isInt: false),
                    const SizedBox(height: 17),

                    _buildCholesterolBloodSugarFields(),
                    const SizedBox(height: 40),

                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          //backgroundColor: Colors.deepOrange,
                          //foregroundColor: Colors.white,
                          //padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            changeUnit();
                            _saveProfileData();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainDashboard()),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Profile saved successfully!'),
                                backgroundColor: lightBlueTheme.colorScheme.secondary,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
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

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: TextStyle(
      color: lightBlueTheme.colorScheme.secondary,
      fontWeight: FontWeight.bold,
      fontSize: 17,
    ),
  );

  /*Widget _buildTextField(String label, TextEditingController controller,
      {bool number = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        labelStyle: TextStyle(fontSize: 15),
        contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      ),
      validator: (value) =>
      value == null || value.isEmpty ? 'Please enter $label' : null,
    );
  }*/

  Widget _buildDropdownField(String label, List<String> options, String? value,
      void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        labelStyle: TextStyle(fontSize: 15),
        contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      ),
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select $label' : null,
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        labelStyle: TextStyle(fontSize: 15),
        contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      ),
    );
  }

  Widget _buildHeightWeightFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 6,
              child: InputTextField(label: 'Height', controller: _heightController, isNumber: true, isInt: false)),
            const SizedBox(width: 15),
            Expanded(
              flex: 5,
              child: _buildDropdownField('Unit', ['cm', 'm', 'ft'], heightUnit,
                      (v) => setState(() => heightUnit = v!)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: InputTextField(label: 'Weight', controller: _weightController, isNumber: true, isInt: false,)),
            const SizedBox(width: 15),
            Expanded(
              flex: 5,
              child: _buildDropdownField('Unit', ['kg', 'lb'], weightUnit,
                      (v) => setState(() => weightUnit = v!)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCholesterolBloodSugarFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 6,
              child: InputTextField(label: 'Cholesterol Level', controller: _cholesterolLevelController, isNumber: true, isInt: false,)),
            const SizedBox(width: 15),
            Expanded(
              flex: 5,
              child: _buildDropdownField('Unit', ['mg/dL', 'mmol/L'], cholesterolUnit,
                      (v) => setState(() => cholesterolUnit = v!)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: InputTextField(label: 'Blood Sugar Level', controller: _bloodSugarLevelController, isNumber: true, isInt: false,)),
            const SizedBox(width: 15),
            Expanded(
              flex: 5,
              child: _buildDropdownField('Unit', ['mg/dL', 'mmol/L'], bloodSugarUnit,
                      (v) => setState(() => bloodSugarUnit = v!)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> regenerateRecommendation(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Calculate today's date
    final yesterday = date.subtract(const Duration(days: 1));
    final todayDate = DateFormat('EEEE, dd MMM yyyy').format(date);

    // Get today's meal data
    final List<Map<String, dynamic>> todayMealData = await Database.getItemsWithConditions(
      'mealLogs', 'uid',
      conditions: {
        'date': DateFormat('EEEE, dd MMM yyyy').format(yesterday),
      },
    );

    double proteinIntake = 0, carbsIntake = 0, fatsIntake = 0;

    for (final data in todayMealData) {
      final mealDoc = await Database.getDocument('meals', data['mealID']);
      final mealDataMap = mealDoc.data() as Map<String, dynamic>;

      double ratio = data['servingSize'] / 100;
      proteinIntake += mealDataMap['protein'] * ratio;
      carbsIntake += mealDataMap['carb'] * ratio;
      fatsIntake += mealDataMap['fat'] * ratio;
    }

    if (proteinIntake == 0 && carbsIntake == 0 && fatsIntake == 0){
      await FirebaseFirestore.instance
          .collection('recommendations')
          .doc(uid)
          .collection('dates')
          .doc(todayDate)
          .delete();
      return;
    }

    // Call your API
    final url = Uri.parse("https://meal-recommender-model.onrender.com/predict");
    final bodyData = {
      "features": [
        int.parse(_ageController.text),
        (height_m * 100),
        weight_kg,
        bmi,
        double.parse(double.tryParse(_bloodPressureSystolicController.text)!.toStringAsFixed(2)),
        double.parse(double.tryParse(_bloodPressureDiastolicController.text)!.toStringAsFixed(2)),
        (cholesterol_mmolL * 38.67),
        (bloodSugar_mmolL * 18),
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

    final results = <String, dynamic>{};

    for (int i = 0; i < nutrients.length; i++) {
      results[nutrients[i]] = prediction[i];
    }

    results['Calories'] = (4 * (prediction[0] + prediction[1]) + 9 * prediction[2]).round();

    // Save to Firestore under tomorrow
    await FirebaseFirestore.instance
        .collection('recommendations')
        .doc(uid)
        .collection('dates')
        .doc(todayDate)
        .set(results);

    print("Recommendation regenerated!");
  }

  void _saveProfileData() async {
    await Database.setItems('usersInfo', null, {
      'name': _nameController.text.trim(),
      'age': int.parse(_ageController.text),
      'gender': _gender,
      'height_m': height_m,
      'weight_kg': weight_kg,
      'bmi': bmi,
      'bloodPressureSystolic':
      double.parse(double.tryParse(_bloodPressureSystolicController.text)!.toStringAsFixed(2)),
      'bloodPressureDiastolic':
      double.parse(double.tryParse(_bloodPressureDiastolicController.text)!.toStringAsFixed(2)),
      'cholesterol_mmolL': cholesterol_mmolL,
      'bloodSugar_mmolL': bloodSugar_mmolL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (isEditing) {
      print("isEditing");
      await regenerateRecommendation(DateTime.now());
      await regenerateRecommendation(DateTime.now().add(const Duration(days: 1)));
    }
  }
}
