import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../functions.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: const ValueKey('home'),
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Header Section
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track your meals and stay healthy every day!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Health Conditions Card
          FutureBuilder(
            future: loadHealthConditions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }

              final conditions = snapshot.data as List<String>;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.health_and_safety,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Health Overview",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ...conditions.map((c) => _buildConditionChip(context, c)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Nutrient Information Card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.green.shade50.withValues(alpha: 0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    "Nutrient Information",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Tap to learn about essential nutrients",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  children: [
                    ..._buildNutrientList(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80), // Extra padding for bottom nav
        ],
      ),
    );
  }
}

Widget _buildConditionChip(BuildContext context, String condition) {
  final data = _getConditionVisual(condition);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showConditionInfoDialog(context, condition),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: data['bg'],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: data['color'].withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data['color'].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data['icon'], color: data['color'], size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    condition,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: data['color'],
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: data['color'],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _getConditionVisual(String c) {
  final green = Colors.green.shade700;
  final yellow = Colors.orange.shade700;
  final red = Colors.red.shade700;

  if (c.contains("Normal")) {
    return {
      "color": green,
      "bg": green.withValues(alpha: 0.1),
      "icon": Icons.check_circle_rounded,
    };
  }
  if (c.contains("Borderline") || c.contains("Elevated")) {
    return {
      "color": yellow,
      "bg": yellow.withValues(alpha: 0.1),
      "icon": Icons.error_outline_rounded,
    };
  }
  return {
    "color": red,
    "bg": red.withValues(alpha: 0.1),
    "icon": Icons.warning_amber_rounded,
  };
}

List<Widget> _buildNutrientList() {
  return nutrientDetails.entries.map((item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: item.value['color'],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.value['icon'],
                size: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value['desc'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }).toList();
}

Widget buildColorRange(String label, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildRanges(String condition) {
  if (condition.contains("Underweight") ||
      condition.contains("Normal Weight") ||
      condition.contains("Overweight") ||
      condition.contains("Obese")) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "BMI Ranges",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        buildColorRange("Underweight", "< 18.5", Colors.blue),
        buildColorRange("Normal Weight", "18.5 – 22.9", Colors.green),
        buildColorRange("Overweight", "23.0 – 27.4", Colors.orange),
        buildColorRange("Obese I", "27.5 – 32.4", Colors.orange.shade700),
        buildColorRange("Obese II", "32.5 – 37.4", Colors.red.shade600),
        buildColorRange("Obese III", "≥ 37.5", Colors.red.shade800),
      ],
    );
  }

  if (condition.contains("Blood Pressure") || condition.contains("Hypertension")) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Blood Pressure Ranges",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        buildColorRange("Normal BP", "<120 / <80", Colors.green),
        buildColorRange("Elevated BP", "120–129 / <80", Colors.orange),
        buildColorRange("Stage 1 Hypertension", "130–139 / 80–89", Colors.orange.shade700),
        buildColorRange("Stage 2 Hypertension", "140–179 / 90–119", Colors.red),
        buildColorRange("Severe Hypertension", ">180 / >120", Colors.red.shade900),
      ],
    );
  }

  if (condition.contains("Blood Sugar") ||
      condition.contains("Prediabetes") ||
      condition.contains("Diabetes")) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Blood Sugar (Fasting)",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        buildColorRange("Normal Blood Sugar", "< 5.5 mmol/L", Colors.green),
        buildColorRange("Prediabetes", "5.6 – 6.9 mmol/L", Colors.orange),
        buildColorRange("Diabetes", "≥ 7.0 mmol/L", Colors.red),
      ],
    );
  }

  if (condition.contains("Cholesterol")) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Cholesterol Levels",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        buildColorRange("Normal Cholesterol", "< 5.2 mmol/L", Colors.green),
        buildColorRange("Borderline High", "5.2 – 6.2 mmol/L", Colors.orange),
        buildColorRange("High Cholesterol", "> 6.2 mmol/L", Colors.red),
      ],
    );
  }

  return SizedBox();
}

void showConditionInfoDialog(BuildContext context, String condition) async {
  final doc = await Database.getDocument('usersInfo', null);
  final data = doc.data() as Map<String, dynamic>;

  double bmi = (data["bmi"] ?? 0).toDouble();
  double sys = data["bloodPressureSystolic"] ?? 0;
  double dia = data["bloodPressureDiastolic"] ?? 0;
  double sugar = (data["bloodSugar_mmolL"] ?? 0).toDouble();
  double chol = (data["cholesterol_mmolL"] ?? 0).toDouble();

  String current = "";
  String url = "";

  switch (condition) {
    case "Underweight":
    case "Normal Weight":
    case "Overweight":
    case "Obese I":
    case "Obese II":
    case "Obese III":

      url = "https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.moh.gov.my/moh/resources/Penerbitan/CPG/Endocrine/CPG_Management_of_Obesity_(Second_Edition)_2023.pdf&ved=2ahUKEwju5_LOoYWRAxXeS2cHHV1aAn4QFnoECDIQAQ&usg=AOvVaw1HFjWa8ouYxIym_i_Ld4za";
      current = "Your BMI: ${bmi.toStringAsFixed(1)} kg/m²";
      break;

    case "Normal Blood Pressure":
    case "Elevated Blood Pressure":
    case "Stage 1 Hypertension":
    case "Stage 2 Hypertension":
    case "Severe Hypertension":

      url = "https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings";
      current = "Your BP: $sys / $dia mmHg";
      break;

    case "Normal Blood Sugar":
    case "Prediabetes":
    case "Diabetes":

      url = "https://my.clevelandclinic.org/health/diagnostics/12363-blood-glucose-test";
      current = "Your Blood Sugar: ${sugar.toStringAsFixed(1)} mmol/L";
      break;

    case "Normal Cholesterol":
    case "Borderline High Cholesterol":
    case "High Cholesterol":

      url = "https://www.homage.com.my/health/cholesterol-level/";
      current = "Your Cholesterol: ${chol.toStringAsFixed(1)} mmol/L";
      break;
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              condition,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      current,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildRanges(condition),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => launchUrl(Uri.parse(url)),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.open_in_new, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Learn More",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text(
            "Close",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
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
  } else if (bmi < 23) {
    conditions.add("Normal Weight");
  } else if (bmi < 27.5) {
    conditions.add("Overweight");
  } else if (bmi < 32.5) {
    conditions.add("Obese I");
  } else if (bmi < 37.5) {
    conditions.add("Obese II");
  } else {
    conditions.add("Obese III");
  }

  if (systolic < 120 && diastolic < 80) {
    conditions.add("Normal Blood Pressure");
  } else if (systolic < 130 && diastolic < 80) {
    conditions.add("Elevated Blood Pressure");
  } else if (systolic < 140 || diastolic < 90) {
    conditions.add("Stage 1 Hypertension");
  } else if (systolic < 180 || diastolic < 120) {
    conditions.add("Stage 2 Hypertension");
  } else {
    conditions.add("Severe Hypertension");
  }

  if (bloodSugar < 5.5) {
    conditions.add("Normal Blood Sugar");
  } else if (bloodSugar < 7.0) {
    conditions.add("Prediabetes");
  } else {
    conditions.add("Diabetes");
  }

  if (cholesterol < 5.2) {
    conditions.add("Normal Cholesterol");
  } else if (cholesterol <= 6.2) {
    conditions.add("Borderline High Cholesterol");
  } else {
    conditions.add("High Cholesterol");
  }

  return conditions;
}

Future<List<String>> loadHealthConditions() async {
  final doc = await Database.getDocument('usersInfo', null);
  final data = doc.data() as Map<String, dynamic>;

  if (data.isEmpty) {
    return ["No health data found"];
  }

  double bmi = data["bmi"];
  double systolic = data["bloodPressureSystolic"];

  double diastolic = data["bloodPressureDiastolic"];
  double sugar = data["bloodSugar_mmolL"];
  double cholesterol = data["cholesterol_mmolL"];

  return detectConditions(
    bmi: bmi,
    systolic: systolic,
    diastolic: diastolic,
    bloodSugar: sugar,
    cholesterol: cholesterol,
  );
}

final Map<String, Map<String, dynamic>> nutrientDetails = {
  "Calories": {
    "icon": Icons.local_fire_department,
    "color": Colors.orange.shade100,
    "desc": "Calories represent the total energy your body gets from food.",
  },
  "Water": {
    "icon": Icons.water_drop,
    "color": Colors.lightBlue.shade100,
    "desc": "Water keeps your body hydrated and supports vital functions.",
  },
  "Protein": {
    "icon": Icons.fitness_center,
    "color": Colors.blue.shade100,
    "desc": "Protein helps repair tissues and build muscles.",
  },
  "Carbohydrates": {
    "icon": Icons.grain,
    "color": Colors.amber.shade100,
    "desc": "Carbohydrates are the body's main and fastest energy source.",
  },
  "Fat": {
    "icon": Icons.oil_barrel,
    "color": Colors.pink.shade100,
    "desc": "Fats provide long-term energy and support cell function.",
  },
  "Fibre": {
    "icon": Icons.eco,
    "color": Colors.green.shade100,
    "desc": "Fibre improves digestion and helps control blood sugar.",
  },
  "Ash": {
    "icon": Icons.science,
    "color": Colors.grey.shade300,
    "desc": "Ash represents the total mineral content in a food item.",
  },
  "Calcium": {
    "icon": Icons.construction,
    "color": Colors.indigo.shade100,
    "desc": "Calcium supports strong bones, teeth, and muscle function.",
  },
  "Iron": {
    "icon": Icons.bloodtype,
    "color": Colors.red.shade100,
    "desc": "Iron helps carry oxygen in the blood and prevents fatigue.",
  },
  "Phosphorus": {
    "icon": Icons.flash_on,
    "color": Colors.deepPurple.shade100,
    "desc": "Phosphorus supports energy production and bone health.",
  },
  "Potassium": {
    "icon": Icons.bolt,
    "color": Colors.teal.shade100,
    "desc": "Potassium helps regulate fluid balance and muscle function.",
  },
  "Sodium": {
    "icon": Icons.spa,
    "color": Colors.blueGrey.shade100,
    "desc": "Too much sodium may increase blood pressure.",
  },
};
