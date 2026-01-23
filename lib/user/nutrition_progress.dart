import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class NutritionProgressPage extends StatefulWidget {
  const NutritionProgressPage({super.key});

  @override
  State<NutritionProgressPage> createState() => _NutritionProgressPageState();
}

class _NutritionProgressPageState extends State<NutritionProgressPage> {
  bool _isLoading = true;
  String _selectedMetric = 'Calories';
  final List<String> _metrics = ['Calories', 'Protein', 'Carbs', 'Fats', 'Water'];
  
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _fetchTrendData();
  }

  Future<void> _fetchTrendData() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    List<Map<String, dynamic>> data = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('EEEE, dd MMM yyyy').format(date);
      final label = DateFormat('dd MMM').format(date);

      // 1. Get Recommendations (Targets)
      final recDoc = await FirebaseFirestore.instance
          .collection('recommendations')
          .doc(uid)
          .collection('dates')
          .doc(dateStr)
          .get();
      
      Map<String, dynamic> targets = recDoc.exists ? recDoc.data()! : {};

      // 2. Get Actual Meal Intake
      final logs = await FirebaseFirestore.instance
          .collection('mealLogs')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: dateStr)
          .get();

      double intakeCal = 0, intakeP = 0, intakeC = 0, intakeF = 0;
      for (var doc in logs.docs) {
        final logData = doc.data();
        final serving = logData['servingSize'] ?? 100;
        var mealDoc = await FirebaseFirestore.instance.collection('meals').doc(logData['mealID']).get();
        if (!mealDoc.exists) {
          mealDoc = await FirebaseFirestore.instance.collection('custom_meal').doc(uid).collection('meals').doc(logData['mealID']).get();
        }
        if (mealDoc.exists) {
          final mData = mealDoc.data()!;
          final ratio = serving / 100;
          intakeCal += (mData['calorie'] ?? 0) * ratio;
          intakeP += (mData['protein'] ?? 0) * ratio;
          intakeC += (mData['carb'] ?? 0) * ratio;
          intakeF += (mData['fat'] ?? 0) * ratio;
        }
      }

      // 3. Get Water Intake
      final wLogs = await FirebaseFirestore.instance
          .collection('waterLogs')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: dateStr)
          .get();
      int intakeWater = 0;
      for (var d in wLogs.docs) {
        intakeWater += (d.data()['amountMl'] as int? ?? 0);
      }

      data.add({
        'label': label,
        'date': date,
        'targets': {
          'Calories': targets['Calories']?.toDouble() ?? 0.0,
          'Protein': targets['Protein_g']?.toDouble() ?? 0.0,
          'Carbs': targets['Carbs_g']?.toDouble() ?? 0.0,
          'Fats': targets['Fats_g']?.toDouble() ?? 0.0,
          'Water': 2000.0, // Default Water Goal
        },
        'intake': {
          'Calories': intakeCal,
          'Protein': intakeP,
          'Carbs': intakeC,
          'Fats': intakeF,
          'Water': intakeWater.toDouble(),
        }
      });
    }

    setState(() {
      _chartData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading 
                ? _buildLoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricSelector(),
                        const SizedBox(height: 24),
                        _buildChartCard(),
                        const SizedBox(height: 24),
                        _buildSummaryCard(),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          const Text('Nutrition Trends', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF42A5F5)),
      const SizedBox(height: 20),
      Text("Generating trend reports...", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
    ]));
  }

  Widget _buildMetricSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _metrics.map((m) {
          final isSelected = _selectedMetric == m;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(m),
              selected: isSelected,
              onSelected: (selected) { if (selected) setState(() => _selectedMetric = m); },
              selectedColor: const Color(0xFF42A5F5),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey.shade400, fontWeight: FontWeight.bold),
              backgroundColor: Colors.white,
              elevation: isSelected ? 4 : 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartCard() {
    final color = _selectedMetric == 'Water' ? const Color(0xFF1E88E5) : const Color(0xFF42A5F5);
    final intakeColor = _selectedMetric == 'Water' ? const Color(0xFF26C6DA) : const Color(0xFFFFA726);

    return Container(
      height: 350, width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("7-Day $_selectedMetric Trend", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        const SizedBox(height: 8),
        Row(children: [_buildLegendItem("Target", color), const SizedBox(width: 16), _buildLegendItem("Intake", intakeColor)]),
        const SizedBox(height: 32),
        Expanded(child: _buildLineChart(color, intakeColor)),
      ]),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [Container(width: 12, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600))]);
  }

  Widget _buildLineChart(Color targetColor, Color intakeColor) {
    List<FlSpot> targetSpots = [];
    List<FlSpot> intakeSpots = [];
    double maxY = 0;

    for (int i = 0; i < _chartData.length; i++) {
      double t = _chartData[i]['targets'][_selectedMetric];
      double v = _chartData[i]['intake'][_selectedMetric];
      targetSpots.add(FlSpot(i.toDouble(), t));
      intakeSpots.add(FlSpot(i.toDouble(), v));
      if (t > maxY) maxY = t;
      if (v > maxY) maxY = v;
    }
    maxY = maxY == 0 ? 10 : maxY * 1.2;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx < 0 || idx >= _chartData.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_chartData[idx]['label'].split(' ')[0], style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 5,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(value.toInt().toString(), style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: 6, minY: 0, maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: targetSpots,
            isCurved: true,
            color: targetColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: targetColor.withValues(alpha: 0.05)),
          ),
          LineChartBarData(
            spots: intakeSpots,
            isCurved: true,
            color: intakeColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    double avgIntake = 0, avgTarget = 0;
    int count = 0;
    for (var d in _chartData) {
      if (d['targets'][_selectedMetric] > 0 || d['intake'][_selectedMetric] > 0) {
        avgTarget += d['targets'][_selectedMetric];
        avgIntake += d['intake'][_selectedMetric];
        count++;
      }
    }
    if (count > 0) { avgTarget /= count; avgIntake /= count; }
    final unit = _selectedMetric == 'Calories' ? 'kcal' : (_selectedMetric == 'Water' ? 'ml' : 'g');
    final color = _selectedMetric == 'Water' ? const Color(0xFF1E88E5) : const Color(0xFF42A5F5);
    final intakeColor = _selectedMetric == 'Water' ? const Color(0xFF26C6DA) : const Color(0xFFFFA726);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Average Statistics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildStatItem("Avg Target", "${avgTarget.toStringAsFixed(0)} $unit", color),
          _buildStatItem("Avg Intake", "${avgIntake.toStringAsFixed(0)} $unit", intakeColor),
        ]),
      ]),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
