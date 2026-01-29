import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ------------------ MODEL ------------------

class MealReminder {
  String name;
  int hour;
  int minute;
  bool isEnabled;

  MealReminder({
    required this.name,
    required this.hour,
    required this.minute,
    required this.isEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
    };
  }

  factory MealReminder.fromMap(Map<String, dynamic> map) {
    return MealReminder(
      name: map['name'] ?? 'Reminder',
      hour: map['hour'] ?? 8,
      minute: map['minute'] ?? 0,
      isEnabled: map['isEnabled'] ?? true,
    );
  }
}

// ------------------ TOP-LEVEL CALLBACK ------------------

@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final pendingReminders = prefs.getStringList('pending_reminders') ?? [];
    final uid = prefs.getString('reminders_uid');
    
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;

    for (String reminderData in pendingReminders) {
      final parts = reminderData.split('|');
      if (parts.length != 4) continue;
      
      final id = int.parse(parts[0]);
      final title = parts[1];
      final reminderMinute = int.parse(parts[2]);
      final isEarlyWarning = parts[3] == 'early';

      if (currentMinute == reminderMinute) {
        // SKIP if it's an early warning and the meal is already logged
        if (isEarlyWarning && uid != null) {
          final isLogged = await _isMealAlreadyLogged(uid, title);
          if (isLogged) continue; // Don't send early warning if already ate
        }

        final notifications = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        await notifications.initialize(const InitializationSettings(android: androidInit));

        if (isEarlyWarning && uid != null) {
          final data = await _getEarlyWarningData(uid, title);
          await notifications.show(
            id,
            "Upcoming $title",
            "Target: ${data['targets']}. Try: ${data['meals']}!",
            _notifDetails(),
          );
        } else if (!isEarlyWarning) {
          await notifications.show(
            id,
            "$title Reminder",
            "It's time for your $title!",
            _notifDetails(),
          );
        }
      }
    }
  } catch (e) {
    debugPrint("Alarm callback error: $e");
  }
}

Future<bool> _isMealAlreadyLogged(String uid, String mealType) async {
  try {
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());
    final query = await FirebaseFirestore.instance
        .collection('mealLogs')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: dateStr)
        .where('mealType', isEqualTo: mealType)
        .limit(1)
        .get();
    
    return query.docs.isNotEmpty;
  } catch (e) {
    return false;
  }
}

NotificationDetails _notifDetails() {
  return const NotificationDetails(
    android: AndroidNotificationDetails(
      'meal_channel', 'Meal Reminders',
      importance: Importance.max, priority: Priority.high,
      showWhen: true, playSound: true, enableVibration: true,
    ),
  );
}

Future<Map<String, String>> _getEarlyWarningData(String uid, String mealType) async {
  try {
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());
    
    final recDoc = await FirebaseFirestore.instance
        .collection('recommendations')
        .doc(uid)
        .collection('dates')
        .doc(dateStr)
        .get();
        
    double targetCal = 500, targetP = 30, targetC = 60, targetF = 20; 
    if (recDoc.exists) {
      final t = recDoc.data()!;
      final targets = t[mealType];
      if (targets != null) {
        targetCal = (targets['Calories'] ?? 500).toDouble();
        targetP = (targets['Protein_g'] ?? 30).toDouble();
        targetC = (targets['Carbs_g'] ?? 60).toDouble();
        targetF = (targets['Fats_g'] ?? 20).toDouble();
      }
    }

    final mealsSnap = await FirebaseFirestore.instance.collection('meals')
        .where('calorie', isLessThanOrEqualTo: targetCal)
        .limit(30)
        .get();
    
    final filteredMeals = mealsSnap.docs.where((doc) {
      final d = doc.data();
      return (d['protein'] ?? 0) <= targetP && 
             (d['carb'] ?? 0) <= targetC && 
             (d['fat'] ?? 0) <= targetF &&
             (d['foodCategory']?.toString().contains(mealType) == true || d['foodCategory']?.toString().contains('Anytime') == true);
    }).toList()..shuffle();

    final recommended = filteredMeals.take(2).map((d) => d.data()['name'].toString()).join(", ");

    return {
      'targets': '${targetCal.toStringAsFixed(0)}kcal (P:${targetP.toStringAsFixed(0)}g, C:${targetC.toStringAsFixed(0)}g, F:${targetF.toStringAsFixed(0)}g)',
      'meals': recommended.isNotEmpty ? recommended : "a balanced option",
    };
  } catch (e) {
    return {'targets': 'a healthy amount', 'meals': 'a balanced meal'};
  }
}

// ------------------ MAIN PAGE ------------------

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  List<MealReminder> reminders = [];
  final Set<String> _protectedReminders = {'Breakfast', 'Lunch', 'Dinner'};

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    final loaded = await loadReminders();
    setState(() => reminders = loaded.isNotEmpty ? loaded : [
      MealReminder(name: "Breakfast", hour: 8, minute: 0, isEnabled: true),
      MealReminder(name: "Lunch", hour: 12, minute: 30, isEnabled: true),
      MealReminder(name: "Dinner", hour: 19, minute: 0, isEnabled: true),
    ]);
    NotificationService.scheduleAllReminders(reminders);
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  _buildSettingsTip(),
                  const SizedBox(height: 16),
                  _buildInstructions(),
                  const SizedBox(height: 10),
                  ...reminders.asMap().entries.map((entry) => _buildReminderCard(entry.value, entry.key)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 85, right: 5),
        child: FloatingActionButton(
          onPressed: _showAddReminderDialog,
          backgroundColor: const Color(0xFF42A5F5),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Reminders", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            Text("Stay consistent with your goals", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.white),
            onPressed: () { NotificationService.testNotification(); HapticFeedback.mediumImpact(); },
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Missing reminders?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text("Ensure Alarms are Allowed and Battery is Unrestricted in System Settings.", style: TextStyle(fontSize: 12, height: 1.3)),
        ])),
      ]),
    );
  }

  Widget _buildInstructions() {
    return Row(children: [
      Icon(Icons.touch_app_rounded, size: 16, color: Colors.blueGrey.shade300),
      const SizedBox(width: 8),
      Text("Long press a card to delete custom reminders", style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
    ]);
  }

  Widget _buildReminderCard(MealReminder r, int index) {
    final color = _getReminderColor(r.name);
    final isEnabled = r.isEnabled;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: isEnabled ? Colors.black.withValues(alpha: 0.03) : Colors.transparent, blurRadius: 10, offset: const Offset(0, 4))]),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: _protectedReminders.contains(r.name) ? null : () => _deleteReminder(index),
            onTap: () { HapticFeedback.selectionClick(); _selectTime(r); },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(_getReminderIcon(r.name), color: color, size: 28)),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_formatTime(r.hour, r.minute), style: TextStyle(fontSize: 16, color: isEnabled ? color.withValues(alpha: 0.8) : Colors.grey, fontWeight: FontWeight.w700)),
                ])),
                Switch.adaptive(value: r.isEnabled, activeThumbColor: const Color(0xFF42A5F5), onChanged: (v) { setState(() => r.isEnabled = v); saveReminders(reminders); NotificationService.scheduleAllReminders(reminders); HapticFeedback.lightImpact(); }),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddReminderDialog() {
    final nameController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text("New Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameController, decoration: InputDecoration(labelText: "Reminder Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
        const SizedBox(height: 20),
        ListTile(title: const Text("Pick Time"), trailing: Text(DateFormat('hh:mm a').format(DateTime(0, 0, 0, selectedTime.hour, selectedTime.minute)), style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold)), onTap: () async {
          final picked = await _pickTime(selectedTime);
          if (picked != null) setDialogState(() => selectedTime = picked);
        }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          if (nameController.text.isNotEmpty) {
            setState(() => reminders.add(MealReminder(name: nameController.text.trim(), hour: selectedTime.hour, minute: selectedTime.minute, isEnabled: true)));
            saveReminders(reminders); NotificationService.scheduleAllReminders(reminders); Navigator.pop(context);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white), child: const Text("Add")),
      ],
    )));
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) async {
    return await showTimePicker(context: context, initialTime: initialTime, builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false), child: Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF42A5F5))), child: child!)));
  }

  void _deleteReminder(int index) async {
    final name = reminders[index].name;
    if (_protectedReminders.contains(name)) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Delete?"), content: Text("Remove '$name'?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red)))]));
    if (confirm == true) { setState(() => reminders.removeAt(index)); saveReminders(reminders); NotificationService.scheduleAllReminders(reminders); }
  }

  void _selectTime(MealReminder r) async {
    final picked = await _pickTime(TimeOfDay(hour: r.hour, minute: r.minute));
    if (picked != null) { setState(() { r.hour = picked.hour; r.minute = picked.minute; }); saveReminders(reminders); NotificationService.scheduleAllReminders(reminders); }
  }

  Color _getReminderColor(String name) => name == "Breakfast" ? Colors.orange : (name == "Lunch" ? Colors.green : (name == "Dinner" ? Colors.deepPurple : Colors.blue));
  IconData _getReminderIcon(String name) => name == "Breakfast" ? Icons.wb_sunny_rounded : (name == "Lunch" ? Icons.lunch_dining_rounded : (name == "Dinner" ? Icons.dark_mode_rounded : Icons.alarm_rounded));

  Future<void> saveReminders(List<MealReminder> reminders) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection("reminders").doc(uid).set({"remindersList": reminders.map((r) => r.toMap()).toList()});
  }

  Future<List<MealReminder>> loadReminders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection("reminders").doc(uid).get();
    if (!doc.exists) return [];
    final list = doc.data()?["remindersList"] as List<dynamic>?;
    return list?.map((i) => MealReminder.fromMap(Map<String, dynamic>.from(i))).toList() ?? [];
  }

  String _formatTime(int h, int m) => DateFormat('hh:mm a').format(DateTime(0, 0, 0, h, m));
}

// ------------------ NOTIFICATION SERVICE ------------------

class NotificationService {
  static final FlutterLocalNotificationsPlugin _noti = FlutterLocalNotificationsPlugin();

  static Future init() async {
    await AndroidAlarmManager.initialize();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _noti.initialize(const InitializationSettings(android: androidInit));
    await _noti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _createNotificationChannel();
  }

  static Future _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel('meal_channel', 'Meal Reminders', importance: Importance.max);
    await _noti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  static bool _alarmInitialized = false;

  static Future scheduleAllReminders(List<MealReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save the current user's ID for background isolate access
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await prefs.setString('reminders_uid', uid);

    final existing = prefs.getStringList('pending_reminders') ?? [];
    existing.clear();

    for (int i = 0; i < reminders.length; i++) {
      final totalMinutes = reminders[i].hour * 60 + reminders[i].minute;
      if (reminders[i].isEnabled) {
        // 1. Normal Reminder
        existing.add('$i|${reminders[i].name}|$totalMinutes|normal');
      }
      if (reminders[i].name == 'Breakfast' || reminders[i].name == 'Lunch' || reminders[i].name == 'Dinner'){ //early reminder is for the 3 meal periods only and they must be sent even the switch is closed
        // 2. Early Warning Reminder (1hr before)
        final earlyMinute = totalMinutes - 60;
        if (earlyMinute >= 0) {
          existing.add('${i + 100}|${reminders[i].name}|$earlyMinute|early');
        }
      }
    }
    await prefs.setStringList('pending_reminders', existing);

    if (!_alarmInitialized) {
      await AndroidAlarmManager.periodic(const Duration(minutes: 1), 0, alarmCallback, exact: true, wakeup: true, rescheduleOnReboot: true, allowWhileIdle: true);
      _alarmInitialized = true;
    }
  }

  static Future testNotification() async {
    await _noti.show(999, "Notification Test", "Reminders are configured!", const NotificationDetails(android: AndroidNotificationDetails('meal_channel', 'Meal Reminders', importance: Importance.max, priority: Priority.high)));
  }
}
