import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final Set<String> _protectedReminders = {'Breakfast', 'Lunch', 'Dinner'};

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    final loaded = await loadReminders();
    if (loaded.isNotEmpty) {
      setState(() => reminders = loaded);
      NotificationService.scheduleAllReminders(reminders);
    }
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
          elevation: 4,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Reminders",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              Text(
                "Stay consistent with your goals",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 24),
            onPressed: () {
              HapticFeedback.mediumImpact();
              NotificationService.testNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sending test notification...", style: TextStyle(fontWeight: FontWeight.bold)),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTip() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Missing reminders?",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 14),
                ),
                Text(
                  "Ensure Alarms are Allowed and Battery is Unrestricted in System Settings.",
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Row(
      children: [
        Icon(Icons.touch_app_rounded, size: 16, color: Colors.blueGrey.shade300),
        const SizedBox(width: 8),
        Text(
          "Long press a card to delete custom reminders",
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildReminderCard(MealReminder r, int index) {
    final color = _getReminderColor(r.name);
    final isEnabled = r.isEnabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isEnabled ? Colors.black.withValues(alpha: 0.03) : Colors.transparent,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: _protectedReminders.contains(r.name) ? null : () => _deleteReminder(index),
            onTap: () {
              HapticFeedback.selectionClick();
              _selectTime(r);
            },
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
                            color: isEnabled ? color.withValues(alpha: 0.8) : Colors.grey,
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
                      HapticFeedback.lightImpact();
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
      ),
    );
  }

  void _showAddReminderDialog() {
    final nameController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("New Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Reminder Name (e.g. Snack)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Pick Time", style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  DateFormat('hh:mm a').format(DateTime(0, 0, 0, selectedTime.hour, selectedTime.minute)),
                  style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onTap: () async {
                  final picked = await _pickTime(selectedTime);
                  if (picked != null) setDialogState(() => selectedTime = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    reminders.add(MealReminder(
                      name: nameController.text.trim(),
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      isEnabled: true,
                    ));
                  });
                  saveReminders(reminders);
                  NotificationService.scheduleAllReminders(reminders);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5), foregroundColor: Colors.white),
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
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
  }

  void _deleteReminder(int index) async {
    final reminderName = reminders[index].name;
    if (_protectedReminders.contains(reminderName)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Reminder?"),
        content: Text("Do you want to remove the '$reminderName' reminder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => reminders.removeAt(index));
      saveReminders(reminders);
      NotificationService.scheduleAllReminders(reminders);
    }
  }

  void _selectTime(MealReminder r) async {
    TimeOfDay? picked = await _pickTime(TimeOfDay(hour: r.hour, minute: r.minute));

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
      "remindersList": reminders.map((r) => r.toMap()).toList(),
    };
    await FirebaseFirestore.instance.collection("reminders").doc(uid).set(data);
  }

  Future<List<MealReminder>> loadReminders() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection("reminders").doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    
    if (data.containsKey("remindersList")) {
      final list = data["remindersList"] as List<dynamic>;
      return list.map((item) => MealReminder.fromMap(Map<String, dynamic>.from(item))).toList();
    }
    
    // Legacy support for fixed fields
    return [
      if (data["breakfast"] != null) MealReminder.fromMap(data["breakfast"]),
      if (data["lunch"] != null) MealReminder.fromMap(data["lunch"]),
      if (data["dinner"] != null) MealReminder.fromMap(data["dinner"]),
    ];
  }

  String _formatTime(int hour, int minute) {
    final dt = DateTime(0, 0, 0, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }
}

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
    existing.clear();

    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i].isEnabled) {
        final totalMinutes = reminders[i].hour * 60 + reminders[i].minute;
        existing.add('$i|${reminders[i].name}|$totalMinutes');
      }
    }
    await prefs.setStringList('pending_reminders', existing);

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
    }
  }

  static Future testNotification() async {
    await _noti.show(
      999,
      "Notification Test",
      "Your FoodWise reminders are working correctly!",
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
}
