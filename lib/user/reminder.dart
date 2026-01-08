import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../functions.dart';

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
    debugPrint("🔔 Alarm callback triggered at ${DateTime.now()}");

    // Get stored reminder info - force reload from disk
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final pendingReminders = prefs.getStringList('pending_reminders') ?? [];

    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;

    debugPrint("⏰ Current time: ${now.hour}:${now.minute} (minute: $currentMinute)");
    debugPrint("📋 Pending reminders: $pendingReminders");

    for (String reminderData in pendingReminders) {
      final parts = reminderData.split('|');
      if (parts.length != 3) continue;

      final id = int.parse(parts[0]);
      final title = parts[1];
      final reminderMinute = int.parse(parts[2]);

      debugPrint("🔍 Checking $title: reminder minute=$reminderMinute, current=$currentMinute, diff=${currentMinute - reminderMinute}");

      // Check if this reminder should fire now (EXACT time only)
      if (currentMinute == reminderMinute) {
        debugPrint("✅ Matched! Showing notification for $title");

        // Show notification
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

        debugPrint("✅ Notification shown for $title at ${DateTime.now()}");

        // If it's a test reminder, remove it to avoid repeated notifications
        if (id == 998) {
          final updated = List<String>.from(pendingReminders);
          updated.removeWhere((item) => item.startsWith('998|'));
          await prefs.setStringList('pending_reminders', updated);
          await prefs.reload();
          debugPrint("🗑️ Removed test reminder from list");
        }
      }
    }
  } catch (e) {
    debugPrint("❌ Error in alarm callback: $e");
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
        setState(() {
          reminders = loaded;
        });

        // schedule enabled reminders
        NotificationService.scheduleAllReminders(reminders);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // ----- HEADER -----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lightBlueTheme.colorScheme.primary,
                    lightBlueTheme.colorScheme.secondary
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.alarm, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Reminders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            const SizedBox(height: 10),

            // ----- REMINDERS LIST -----
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final r = reminders[index];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        r.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _formatTime(r.hour, r.minute),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      trailing: Switch(
                        value: r.isEnabled,
                        onChanged: (value) {
                          setState(() => r.isEnabled = value);
                          saveReminders(reminders);
                          NotificationService.scheduleAllReminders(reminders);
                        },
                        activeColor: lightBlueTheme.colorScheme.primary,
                      ),
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
                          helpText: "Select time for ${r.name}",
                        );

                        if (picked != null) {
                          setState(() {
                            r.hour = picked.hour;
                            r.minute = picked.minute;
                          });

                          saveReminders(reminders);
                          NotificationService.scheduleAllReminders(reminders);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveReminders(List<MealReminder> reminders) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    Map<String, dynamic> data = {
      "breakfast": reminders[0].toMap(),
      "lunch": reminders[1].toMap(),
      "dinner": reminders[2].toMap(),
    };

    await FirebaseFirestore.instance
        .collection("reminders")
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<List<MealReminder>> loadReminders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("reminders")
        .doc(uid)
        .get();

    if (!doc.exists) return [];

    final data = doc.data()!;

    return [
      MealReminder.fromMap(data["breakfast"]),
      MealReminder.fromMap(data["lunch"]),
      MealReminder.fromMap(data["dinner"]),
    ];
  }

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }
}

// ------------------ NOTIFICATION SERVICE ------------------

class NotificationService {
  static final FlutterLocalNotificationsPlugin _noti =
  FlutterLocalNotificationsPlugin();

  static Future init() async {
    await AndroidAlarmManager.initialize();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _noti.initialize(
      const InitializationSettings(android: androidInit),
    );

    await _noti
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _createNotificationChannel();
  }

  static Future _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'meal_channel',
      'Meal Reminders',
      importance: Importance.max,
    );

    await _noti
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static bool _alarmInitialized = false;

  static Future scheduleAllReminders(List<MealReminder> reminders) async {
    // Store all enabled reminders in SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Get existing reminders (including test reminders)
    final existing = prefs.getStringList('pending_reminders') ?? [];

    // Remove old meal reminders (but keep test reminders with ID 998)
    existing.removeWhere((item) =>
    item.startsWith('0|') || item.startsWith('1|') || item.startsWith('2|'));

    // Add current enabled meal reminders
    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i].isEnabled) {
        final totalMinutes = reminders[i].hour * 60 + reminders[i].minute;
        existing.add('$i|${reminders[i].name}|$totalMinutes');
      }
    }

    await prefs.setStringList('pending_reminders', existing);

    // Only initialize the alarm once
    if (!_alarmInitialized) {
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 1),
        0,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
      _alarmInitialized = true;
      debugPrint("✅ Initialized periodic alarm checker");
    }

    debugPrint("✅ Updated reminders. Current list: $existing");
  }

  static Future testNotification() async {
    await _noti.show(
      999,
      "Test Reminder",
      "This is a test notification",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_channel',
          'Meal Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future testScheduledIn1Minute() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 1));
    final testMinute = testTime.hour * 60 + testTime.minute;

    // Add test reminder to shared preferences
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('pending_reminders') ?? [];

    // Remove any old test reminders first
    existing.removeWhere((item) => item.startsWith('998|'));

    // Add new test reminder
    existing.add('998|Test|$testMinute');
    await prefs.setStringList('pending_reminders', existing);

    debugPrint("🧪 Test scheduled for ${testTime.hour}:${testTime.minute} (minute: $testMinute)");
    debugPrint("📝 Saved to prefs: $existing");
  }
}