import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../functions.dart'; // Ensure your Database class is accessible here

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent, // Allows MainDashboard gradient to show
      body: RefreshIndicator(
        onRefresh: () async => loadHealthConditions(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            // Header Section
            _buildHeader(theme),
            const SizedBox(height: 32),

            // Health Conditions Section
            _buildSectionLabel("HEALTH OVERVIEW"),
            const SizedBox(height: 12),
            FutureBuilder<List<String>>(
              future: loadHealthConditions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingPlaceholder();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No health data found"));
                }

                final conditions = snapshot.data!;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: conditions
                          .map((c) => _buildConditionChip(context, c))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Nutrient Information Section
            _buildSectionLabel("NUTRIENT INFORMATION"),
            const SizedBox(height: 12),
            _buildNutrientCard(theme),

            const SizedBox(height: 100), // Padding for the floating nav bar
          ],
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back 👋',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 32,
            letterSpacing: -1.0,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your meals and stay healthy every day!',
          style: TextStyle(
            color: Colors.blueGrey.shade400,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.blueGrey.shade300,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildConditionChip(BuildContext context, String condition) {
    final data = _getConditionVisual(condition);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showConditionInfoDialog(context, condition),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: data['bg'],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(data['icon'], color: data['color'], size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    condition,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: data['color'].withOpacity(0.8),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: data['color'].withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.restaurant_menu, color: Colors.green.shade700, size: 20),
            ),
            title: const Text(
              "Nutrient Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: const Text(
              "Tap to learn about essential nutrients",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            children: _buildNutrientList(),
          ),
        ),
      ),
    );
  }

  // --- Logic & Helpers ---

  Map<String, dynamic> _getConditionVisual(String c) {
    if (c.contains("Normal")) {
      return {
        "color": Colors.green.shade700,
        "bg": Colors.green.shade50,
        "icon": Icons.check_circle_rounded,
      };
    }
    if (c.contains("Borderline") || c.contains("Elevated") || c.contains("Prediabetes") || c.contains("Overweight")) {
      return {
        "color": Colors.orange.shade700,
        "bg": Colors.orange.shade50,
        "icon": Icons.error_outline_rounded,
      };
    }
    return {
      "color": Colors.red.shade700,
      "bg": Colors.red.shade50,
      "icon": Icons.warning_amber_rounded,
    };
  }

  List<Widget> _buildNutrientList() {
    return nutrientDetails.entries.map((item) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.value['color'].withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.value['icon'], size: 22, color: Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(item.value['desc'], style: const TextStyle(fontSize: 14, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// --- Global Helpers & Data (Preserving your exact wording) ---

final Map<String, Map<String, dynamic>> nutrientDetails = {
  "Calories": {"icon": Icons.local_fire_department, "color": Colors.orange.shade100, "desc": "Calories represent the total energy your body gets from food."},
  "Water": {"icon": Icons.water_drop, "color": Colors.lightBlue.shade100, "desc": "Water keeps your body hydrated and supports vital functions."},
  "Protein": {"icon": Icons.fitness_center, "color": Colors.blue.shade100, "desc": "Protein helps repair tissues and build muscles."},
  "Carbohydrates": {"icon": Icons.grain, "color": Colors.amber.shade100, "desc": "Carbohydrates are the body's main and fastest energy source."},
  "Fat": {"icon": Icons.oil_barrel, "color": Colors.pink.shade100, "desc": "Fats provide long-term energy and support cell function."},
  "Fibre": {"icon": Icons.eco, "color": Colors.green.shade100, "desc": "Fibre improves digestion and helps control blood sugar."},
  "Ash": {"icon": Icons.science, "color": Colors.grey.shade300, "desc": "Ash represents the total mineral content in a food item."},
  "Calcium": {"icon": Icons.construction, "color": Colors.indigo.shade100, "desc": "Calcium supports strong bones, teeth, and muscle function."},
  "Iron": {"icon": Icons.bloodtype, "color": Colors.red.shade100, "desc": "Iron helps carry oxygen in the blood and prevents fatigue."},
  "Phosphorus": {"icon": Icons.flash_on, "color": Colors.deepPurple.shade100, "desc": "Phosphorus supports energy production and bone health."},
  "Potassium": {"icon": Icons.bolt, "color": Colors.teal.shade100, "desc": "Potassium helps regulate fluid balance and muscle function."},
  "Sodium": {"icon": Icons.spa, "color": Colors.blueGrey.shade100, "desc": "Too much sodium may increase blood pressure."},
};

// --- Your Logic Functions (Keep these as is) ---

Future<List<String>> loadHealthConditions() async {
  final doc = await Database.getDocument('usersInfo', null);
  final data = doc.data() as Map<String, dynamic>;
  if (data.isEmpty) return ["No health data found"];

  return detectConditions(
    bmi: (data["bmi"] ?? 0).toDouble(),
    systolic: (data["bloodPressureSystolic"] ?? 0).toDouble(),
    diastolic: (data["bloodPressureDiastolic"] ?? 0).toDouble(),
    bloodSugar: (data["bloodSugar_mmolL"] ?? 0).toDouble(),
    cholesterol: (data["cholesterol_mmolL"] ?? 0).toDouble(),
  );
}

List<String> detectConditions({
  required double bmi,
  required double systolic,
  required double diastolic,
  required double bloodSugar,
  required double cholesterol,
}) {
  List<String> conditions = [];
  if (bmi < 18.5) {
    conditions.add("Underweight");
  }
  else if (bmi < 23) {
    conditions.add("Normal Weight");
  }
  else if (bmi < 27.5) {
    conditions.add("Overweight");
  }
  else if (bmi < 32.5) {
    conditions.add("Obese I");
  }
  else if (bmi < 37.5) {
    conditions.add("Obese II");
  }
  else {
    conditions.add("Obese III");
  }

  if (systolic < 120 && diastolic < 80) {
    conditions.add("Normal Blood Pressure");
  }
  else if (systolic < 130 && diastolic < 80) {
    conditions.add("Elevated Blood Pressure");
  }
  else if (systolic < 140 || diastolic < 90) {
    conditions.add("Stage 1 Hypertension");
  }
  else if (systolic < 180 || diastolic < 120) {
    conditions.add("Stage 2 Hypertension");
  }
  else {
    conditions.add("Severe Hypertension");
  }

  if (bloodSugar < 5.5) {
    conditions.add("Normal Blood Sugar");
  }
  else if (bloodSugar < 7.0) {
    conditions.add("Prediabetes");
  }
  else {
    conditions.add("Diabetes");
  }

  if (cholesterol < 5.2) {
    conditions.add("Normal Cholesterol");
  }
  else if (cholesterol <= 6.2) {
    conditions.add("Borderline High Cholesterol");
  }
  else {
    conditions.add("High Cholesterol");
  }

  return conditions;
}

// --- Dialog Functions (Refined styling, original wording) ---

void showConditionInfoDialog(BuildContext context, String condition) async {
  final doc = await Database.getDocument('usersInfo', null);
  final data = doc.data() as Map<String, dynamic>;

  double bmi = (data["bmi"] ?? 0).toDouble();
  double sys = (data["bloodPressureSystolic"] ?? 0).toDouble();
  double dia = (data["bloodPressureDiastolic"] ?? 0).toDouble();
  double sugar = (data["bloodSugar_mmolL"] ?? 0).toDouble();
  double chol = (data["cholesterol_mmolL"] ?? 0).toDouble();

  String current = "";
  String url = "";

  if (condition.contains("Weight") || condition.contains("Obese") || condition.contains("Underweight")) {
    url = "https://www.moh.gov.my/moh/resources/Penerbitan/CPG/Endocrine/CPG_Management_of_Obesity_(Second_Edition)_2023.pdf";
    current = "Your BMI: ${bmi.toStringAsFixed(1)} kg/m²";
  } else if (condition.contains("Pressure") || condition.contains("Hypertension")) {
    url = "https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings";
    current = "Your BP: ${sys.toInt()} / ${dia.toInt()} mmHg";
  } else if (condition.contains("Sugar") || condition.contains("Diabetes")) {
    url = "https://my.clevelandclinic.org/health/diagnostics/12363-blood-glucose-test";
    current = "Your Blood Sugar: ${sugar.toStringAsFixed(1)} mmol/L";
  } else if (condition.contains("Cholesterol")) {
    url = "https://www.homage.com.my/health/cholesterol-level/";
    current = "Your Cholesterol: ${chol.toStringAsFixed(1)} mmol/L";
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(condition, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(current, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildRanges(condition),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ElevatedButton(
          onPressed: () => launchUrl(Uri.parse(url)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
          child: const Text("Learn More"),
        ),
      ],
    ),
  );
}

Widget _buildRanges(String condition) {
  // BMI Ranges
  if (condition.contains("Weight") || condition.contains("Obese") || condition.contains("Underweight")) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("BMI Ranges", style: TextStyle(fontWeight: FontWeight.bold)),
      _rangeRow("Underweight", "< 18.5", Colors.blue),
      _rangeRow("Normal Weight", "18.5 – 22.9", Colors.green),
      _rangeRow("Overweight", "23.0 – 27.4", Colors.orange),
      _rangeRow("Obese I", "27.5 – 32.4", Colors.orange.shade700),
      _rangeRow("Obese II", "32.5 – 37.4", Colors.red.shade600),
      _rangeRow("Obese III", "≥ 37.5", Colors.red.shade800),
    ]);
  }
  // Blood Pressure Ranges
  if (condition.contains("Pressure") || condition.contains("Hypertension")) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Blood Pressure Ranges", style: TextStyle(fontWeight: FontWeight.bold)),
      _rangeRow("Normal BP", "<120 / <80", Colors.green),
      _rangeRow("Elevated BP", "120–129 / <80", Colors.orange),
      _rangeRow("Stage 1 Hypertension", "130–139 / 80–89", Colors.orange.shade700),
      _rangeRow("Stage 2 Hypertension", "140–179 / 90–119", Colors.red),
      _rangeRow("Severe Hypertension", ">180 / >120", Colors.red.shade900),
    ]);
  }
  // Blood Sugar Ranges
  if (condition.contains("Sugar") || condition.contains("Diabetes")) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Blood Sugar (Fasting)", style: TextStyle(fontWeight: FontWeight.bold)),
      _rangeRow("Normal Blood Sugar", "< 5.5 mmol/L", Colors.green),
      _rangeRow("Prediabetes", "5.6 – 6.9 mmol/L", Colors.orange),
      _rangeRow("Diabetes", "≥ 7.0 mmol/L", Colors.red),
    ]);
  }
  // Cholesterol Ranges
  if (condition.contains("Cholesterol")) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Cholesterol Levels", style: TextStyle(fontWeight: FontWeight.bold)),
      _rangeRow("Normal Cholesterol", "< 5.2 mmol/L", Colors.green),
      _rangeRow("Borderline High", "5.2 – 6.2 mmol/L", Colors.orange),
      _rangeRow("High Cholesterol", "> 6.2 mmol/L", Colors.red),
    ]);
  }
  return const SizedBox();
}

Widget _rangeRow(String label, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text("$label: $value", style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}