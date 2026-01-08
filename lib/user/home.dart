import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
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
          Text(
            'Welcome Back 👋',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track your meals and stay healthy every day!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),

          FutureBuilder(
            future: loadHealthConditions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final conditions = snapshot.data as List<String>;

              return Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Detected Health Conditions",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      ...conditions.map((c) => _buildConditionChip(context, c)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(
                  "Nutrient Information",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text("Tap to view the info"),
                children: [
                  ..._buildNutrientList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildConditionChip(BuildContext context, String condition) {
  final data = _getConditionVisual(condition);

  return GestureDetector(
    onTap: () => showConditionInfoDialog(context, condition),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        color: data['bg'],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(data['icon'], color: data['color'], size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              condition,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: data['color'],
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: data['color'])
        ],
      ),
    ),
  );
}

Map<String, dynamic> _getConditionVisual(String c) {
  // Colors
  final green = Colors.green.shade700;
  final yellow = Colors.orange.shade700;
  final red = Colors.red.shade700;

  if (c.contains("Normal")) {
    return {
      "color": green,
      "bg": green.withOpacity(0.12),
      "icon": Icons.check_circle,
    };
  }
  if (c.contains("Borderline") || c.contains("Elevated")) {
    return {
      "color": yellow,
      "bg": yellow.withOpacity(0.12),
      "icon": Icons.error_outline,
    };
  }
  return {
    "color": red,
    "bg": red.withOpacity(0.12),
    "icon": Icons.warning_amber_rounded,
  };
}

List<Widget> _buildNutrientList() {
  return nutrientDetails.entries.map((item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.value['color'],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(item.value['icon'], size: 26, color: Colors.black87),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value['desc'],
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }).toList();
}

Widget buildColorRange(String label, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
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
        Text("BMI Ranges", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
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
        Text("Blood Pressure Ranges", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
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
        Text("Blood Sugar (Fasting)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
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
        Text("Cholesterol Levels", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        buildColorRange("Normal Cholesterol", "< 5.2 mmol/L", Colors.green),
        buildColorRange("Borderline High", "5.2 – 6.2 mmol/L", Colors.orange),
        buildColorRange("High Cholesterol", "> 6.2 mmol/L", Colors.red),
      ],
    );
  }

  return SizedBox();
}

void showConditionInfoDialog(BuildContext context, String condition) async {
  // Load user health data
  final doc = await Database.getDocument('usersInfo', null);
  final data = doc.data() as Map<String, dynamic>;

  double bmi = (data["bmi"] ?? 0).toDouble();
  double sys = data["bloodPressureSystolic"] ?? 0;
  double dia = data["bloodPressureDiastolic"] ?? 0;
  double sugar = (data["bloodSugar_mmolL"] ?? 0).toDouble();
  double chol = (data["cholesterol_mmolL"] ?? 0).toDouble();

  String explanation = "";
  String current = "";
  String url = "";

  // Determine which condition was clicked
  switch (condition) {
    case "Underweight":
    case "Normal Weight":
    case "Overweight":
    case "Obese I":
    case "Obese II":
    case "Obese III":
      explanation = """
BMI Ranges:
• Underweight: < 18.5
• Normal: 18.5 – 22.9
• Overweight: 23.0 – 27.4
• Obese I: 27.5 – 32.4
• Obese II: 32.5 – 37.4
• Obese III: ≥ 37.5
""";
      url =
      "https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.moh.gov.my/moh/resources/Penerbitan/CPG/Endocrine/CPG_Management_of_Obesity_(Second_Edition)_2023.pdf&ved=2ahUKEwju5_LOoYWRAxXeS2cHHV1aAn4QFnoECDIQAQ&usg=AOvVaw1HFjWa8ouYxIym_i_Ld4za";
      current = "Your BMI: ${bmi.toStringAsFixed(1)} kg/m²";
      break;

    case "Normal Blood Pressure":
    case "Elevated Blood Pressure":
    case "Stage 1 Hypertension":
    case "Stage 2 Hypertension":
    case "Severe Hypertension":
      explanation = """
Blood Pressure Categories:
• Normal Blood Pressure: <120 / <80
• Elevated Blood Pressure: 120-129 / <80
• Stage 1 Hypertension: 130–139 / 80–89
• Stage 2 Hypertension: 140-179 / 90-119
• Severe Hypertension*: >180 / >120

*symptoms: chest pain, shortness of breath, back pain, numbness, weakness, change in vision or difficulty speaking

*if there is any symptoms mentioned above, please call ambulance
""";
      url =
      "https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings";
      current = "Your BP: $sys / $dia mmHg";
      break;

    case "Normal Blood Sugar":
    case "Prediabetes":
    case "Diabetes":
      explanation = """
Blood Sugar (Fasting):
• Normal: < 5.5 mmol/L
• Prediabetes: 5.6 - 6.9 mmol/L
• High: ≥ 7.0 mmol/L
""";
      url =
      "https://my.clevelandclinic.org/health/diagnostics/12363-blood-glucose-test";
      current = "Your Blood Sugar: ${sugar.toStringAsFixed(1)} mmol/L";
      break;

    case "Normal Cholesterol":
    case "Borderline High Cholesterol":
    case "High Cholesterol":
      explanation = """
Cholesterol Levels:
• Normal: < 5.2 mmol/L
• Borderline High: 5.2 - 6.2 mmol/L
• High: > 6.2 mmol/L
""";
      url = "https://www.homage.com.my/health/cholesterol-level/";
      current = "Your Cholesterol: ${chol.toStringAsFixed(1)} mmol/L";
      break;
  }

  // Show dialog
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        condition,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRanges(condition),
            const SizedBox(height: 12),
            Text(
              current,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(url)),
              child: const Text(
                "Tap here for more information",
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Close"),
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

  // BMI
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

  // Blood Pressure
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

  // Blood Sugar
  if (bloodSugar < 5.5) {
    conditions.add("Normal Blood Sugar");
  } else if (bloodSugar < 7.0) {
    conditions.add("Prediabetes");
  } else {
    conditions.add("Diabetes");
  }

  // Cholesterol
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

  print("here 1");
  if (data.isEmpty) {
    return ["No health data found"];
  }
  print("here 2");
  print(data);

  double bmi = data["bmi"];
  double systolic = data["bloodPressureSystolic"];
  print("here");

  double diastolic = data["bloodPressureDiastolic"];
  double sugar = data["bloodSugar_mmolL"];
  double cholesterol = data["cholesterol_mmolL"];
  print("here 3");

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
    "desc": "Carbohydrates are the body’s main and fastest energy source.",
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
    "icon": Icons.construction, // bone-like symbol alternative
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

Widget _buildNutrientItem({
  required String title,
  required String description,
}) {
  return ListTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(description),
  );
}
