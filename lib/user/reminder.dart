import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
      name: map['name'],
      hour: map['hour'],
      minute: map['minute'],
      isEnabled: map['isEnabled'],
    );
  }
}

// ------------------ TOP-LEVEL CALLBACK ------------------

@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final pendingReminders = prefs.getStringList('pending_reminders') ?? [];
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;

    for (String reminderData in pendingReminders) {
      final parts = reminderData.split('|');
      if (parts.length != 3) continue;
      final id = int.parse(parts[0]);
      final title = parts[1];
      final reminderMinute = int.parse(parts[2]);

      if (currentMinute == reminderMinute) {
        final notifications = FlutterLocalNotificationsPlugin();
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        await notifications.initialize(const InitializationSettings(android: androidInit));

        await notifications.show(
          id,
          "$title Reminder",
          "It's time for your $title!",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'meal_channel',
              'Meal Reminders',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              playSound: true,
              enableVibration: true,
            ),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint("Alarm callback error: $e");
  }
}

// ------------------ MAIN PAGE ------------------

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  List<MealReminder> reminders = [
    MealReminder(name: "Breakfast", hour: 8, minute: 0, isEnabled: true),
    MealReminder(name: "Lunch", hour: 12, minute: 30, isEnabled: true),
    MealReminder(name: "Dinner", hour: 19, minute: 0, isEnabled: true),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    loadReminders().then((loaded) {
      if (loaded.isNotEmpty) {
        setState(() => reminders = loaded);
        NotificationService.scheduleAllReminders(reminders);
      }
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  return _buildReminderCard(reminders[index], index);
                },
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reminders",
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          SizedBox(height: 4),
          Text(
            "Stay consistent with your healthy eating habits",
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(MealReminder r, int index) {
    final color = _getReminderColor(r.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectTime(r),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_getReminderIcon(r.name), color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(r.hour, r.minute),
                        style: TextStyle(
                          fontSize: 16, 
                          color: color.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: r.isEnabled,
                  activeThumbColor: const Color(0xFF42A5F5),
                  onChanged: (value) {
                    setState(() => r.isEnabled = value);
                    saveReminders(reminders);
                    NotificationService.scheduleAllReminders(reminders);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectTime(MealReminder r) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF42A5F5),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        r.hour = picked.hour;
        r.minute = picked.minute;
      });
      saveReminders(reminders);
      NotificationService.scheduleAllReminders(reminders);
    }
  }

  Color _getReminderColor(String name) {
    switch (name) {
      case "Breakfast": return Colors.orange;
      case "Lunch": return Colors.green;
      case "Dinner": return Colors.deepPurple;
      default: return Colors.blue;
    }
  }

  IconData _getReminderIcon(String name) {
    switch (name) {
      case "Breakfast": return Icons.wb_sunny_rounded;
      case "Lunch": return Icons.lunch_dining_rounded;
      case "Dinner": return Icons.dark_mode_rounded;
      default: return Icons.alarm_rounded;
    }
  }

  Future<void> saveReminders(List<MealReminder> reminders) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    Map<String, dynamic> data = {
      "breakfast": reminders[0].toMap(),
      "lunch": reminders[1].toMap(),
      "dinner": reminders[2].toMap(),
    };
    await FirebaseFirestore.instance.collection("reminders").doc(uid).set(data, SetOptions(merge: true));
  }

  Future<List<MealReminder>> loadReminders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection("reminders").doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    return [
      MealReminder.fromMap(data["breakfast"]),
      MealReminder.fromMap(data["lunch"]),
      MealReminder.fromMap(data["dinner"]),
    ];
  }

  String _formatTime(int hour, int minute) {
    final dt = DateTime(0, 0, 0, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }
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
    final existing = prefs.getStringList('pending_reminders') ?? [];
    existing.removeWhere((item) => item.startsWith('0|') || item.startsWith('1|') || item.startsWith('2|'));

    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i].isEnabled) {
        final totalMinutes = reminders[i].hour * 60 + reminders[i].minute;
        existing.add('$i|${reminders[i].name}|$totalMinutes');
      }
    }
    await prefs.setStringList('pending_reminders', existing);

    if (!_alarmInitialized) {
      await AndroidAlarmManager.periodic(const Duration(minutes: 1), 0, alarmCallback, exact: true, wakeup: true, rescheduleOnReboot: true, allowWhileIdle: true);
      _alarmInitialized = true;
    }
  }
}
