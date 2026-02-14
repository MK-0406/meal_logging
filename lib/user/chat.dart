import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class NutritionChat extends StatefulWidget {
  const NutritionChat({super.key});

  @override
  State<NutritionChat> createState() => _NutritionChatState();
}

class _NutritionChatState extends State<NutritionChat> {
  GenerativeModel? _model;
  ChatSession? _chat;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  final List<String> _availableModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-robotics-er-1.5-preview',
  ];
  int _currentModelIndex = 0;

  @override
  void initState() {
    super.initState();
    _initModel();
    _loadChatHistory();
  }

  void _initModel() {
    try {
      _model = GenerativeModel(
        model: _availableModels[_currentModelIndex],
        apiKey: '[PLACE_YOUR_OWN_API_KEY_HERE]',
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          //maxOutputTokens: 4096,
        ),
        systemInstruction: Content.system(
            'You are a expert nutrition assistant integrated into a meal logging app. '
            'Your goal is to provide feedback on logged meals and recommend meals ONLY from the provided database list. '
            'IMPORTANT: You CANNOT change the user\'s information (like weight, height, or age). If asked to do so, politely explain that you are an assistant and cannot modify their profile data. '
            'Use the provided [SYSTEM CONTEXT] regarding meal logs and health data only when relevant to the user\'s query. For general nutrition questions, answer directly. '
            'Always be encouraging, professional, and practical.'),
      );
      _chat = _model!.startChat();
    } catch (e) {
      debugPrint('Error initializing model: $e');
    }
  }

  bool _switchToNextModel() {
    if (_currentModelIndex < _availableModels.length - 1) {
      _currentModelIndex++;
      _initModel();
      return true;
    }
    return false;
  }

  Future<void> _saveMessage(String role, String text) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(uid)
        .collection('chat')
        .add({
      'role': role,
      'text': text,
      'time': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _loadChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(uid)
        .collection('chat')
        .orderBy('time', descending: false)
        .get();

    setState(() {
      _messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _messages.add({
          'role': data['role'],
          'text': data['text'],
          'time': (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }
    });

    if (_messages.isEmpty) {
      _sendTodaySummary();
    }
    _scrollToBottom();
  }

  Future<String> _getAppContext(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(date);

    final userDoc = await FirebaseFirestore.instance.collection('usersInfo').doc(uid).get();
    String healthProfile = "Not available";
    if (userDoc.exists) {
      final u = userDoc.data()!;
      healthProfile = "Age: ${u['age']}, Weight: ${u['weight_kg']}kg, Height: ${u['height_m']}m, BMI: ${u['bmi']}, "
          "BP: ${u['bloodPressureSystolic']}/${u['bloodPressureDiastolic']}, "
          "Cholesterol: ${u['cholesterol_mmolL']} mmol/L, Blood Sugar: ${u['bloodSugar_mmolL']} mmol/L";
    }

    final recommendationDoc = await FirebaseFirestore.instance
        .collection('recommendations')
        .doc(uid)
        .collection('dates')
        .doc(dateStr)
        .get();
    String targetInfo = "No specific targets found for this date.";
    if (recommendationDoc.exists) {
      final data = recommendationDoc.data()!;
      targetInfo = "Daily Targets: ${data['Calories']} kcal, ${data['Protein_g']}g Protein, ${data['Carbs_g']}g Carbs, ${data['Fats_g']}g Fats.";
    }

    final logSummary = await _getMealSummary(date);

    final snapshot = await FirebaseFirestore.instance.collection('meals').limit(15).get();
    String availableMeals = snapshot.docs.map((doc) {
      final d = doc.data();
      return "- ${d['name']} (${d['calorie']} kcal, P:${d['protein']}g, C:${d['carb']}g, F:${d['fat']}g)";
    }).join("\n");

    return """
[SYSTEM CONTEXT]
USER HEALTH PROFILE: $healthProfile
DAILY TARGETS ($dateStr): $targetInfo
LOGGED MEALS ($dateStr):
$logSummary

AVAILABLE MEALS IN APP DATABASE:
$availableMeals
[END CONTEXT]
""";
  }

  Future<void> _sendTodaySummary() async {
    if (_chat == null) return;
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(now);

    setState(() {
      _messages.add({
        'role': 'model',
        'text': "Hello! Let me take a look at your logs for today...",
        'time': DateTime.now(),
        'isStatus': true,
      });
    });

    await _callAiWithRetry(now, dateStr: dateStr, isSummary: true);
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_chat == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });
    _scrollToBottom();
    await _saveMessage('user', text);

    await _callAiWithRetry(DateTime.now(), manualText: text);
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _callAiWithRetry(DateTime date, {String? dateStr, String? manualText, bool isSummary = false}) async {
    try {
      final contextData = await _getAppContext(date);
      final prompt = isSummary
          ? "$contextData\n\nPlease analyze my diet for $dateStr and provide feedback and recommendations."
          : "$contextData\n\nUser Question: $manualText";

      final response = await _chat!.sendMessage(Content.text(prompt));
      final botMsg = response.text ?? "I'm sorry, I couldn't process that.";

      setState(() {
        _messages.add({
          'role': 'model',
          'text': botMsg,
          'time': DateTime.now(),
        });
      });
      await _saveMessage('model', botMsg);
    } catch (e) {
      String errorStr = e.toString().toLowerCase();
      if (errorStr.contains('429') || errorStr.contains('quota') || errorStr.contains('limit') || errorStr.contains('503') || errorStr.contains('overloaded')) {
        if (_switchToNextModel()) {
          await _callAiWithRetry(date, dateStr: dateStr, manualText: manualText, isSummary: isSummary);
        } else {
          _addErrorMessage("All models are busy. Please try again later.");
        }
      } else {
        _addErrorMessage("Sorry, I encountered an error. Please try again.");
      }
    }
  }

  void _addErrorMessage(String text) {
    setState(() {
      _messages.add({
        'role': 'model',
        'text': text,
        'time': DateTime.now(),
      });
    });
  }

  Future<String> _getMealSummary(DateTime date) async {
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(date);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final logs = await FirebaseFirestore.instance
        .collection('mealLogs')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: dateStr)
        .get();

    if (logs.docs.isEmpty) return "No meals logged for this day.";

    String summary = "";
    double totalCal = 0, totalP = 0, totalC = 0, totalF = 0;

    for (var doc in logs.docs) {
      final data = doc.data();
      final mealId = data['mealID'];
      final serving = data['servingSize'] ?? 100;
      final type = data['mealType'] ?? 'Meal';

      var mealDoc = await FirebaseFirestore.instance.collection('meals').doc(mealId).get();
      if (!mealDoc.exists) {
        mealDoc = await FirebaseFirestore.instance
            .collection('custom_meal')
            .doc(uid)
            .collection('meals')
            .doc(mealId)
            .get();
      }

      if (mealDoc.exists) {
        final mData = mealDoc.data()!;
        final ratio = serving / 100;
        final cal = (mData['calorie'] ?? 0) * ratio;
        final p = (mData['protein'] ?? 0) * ratio;
        final c = (mData['carb'] ?? 0) * ratio;
        final f = (mData['fat'] ?? 0) * ratio;

        summary += "- $type: ${mData['name']} (${serving}g) - ${cal.toStringAsFixed(0)}kcal (P:${p.toStringAsFixed(1)}g, C:${c.toStringAsFixed(1)}g, F:${f.toStringAsFixed(1)}g)\n";
        totalCal += cal; totalP += p; totalC += c; totalF += f;
      }
    }
    summary += "\nTotal Intake: ${totalCal.toStringAsFixed(0)} kcal (P:${totalP.toStringAsFixed(1)}g, C:${totalC.toStringAsFixed(1)}g, F:${totalF.toStringAsFixed(1)}g)";
    return summary;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  if (msg['isStatus'] == true) {
                    return _buildStatusMessage(msg['text']);
                  }
                  return _buildChatBubble(msg);
                },
              ),
            ),
            if (_isLoading) _buildLoadingIndicator(),
            _buildInputArea(),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NutriBot",
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  Text(
                    "Your AI Nutritionist",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Clear Chat?"),
                      content: const Text("This will delete your conversation history."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    await FirebaseFirestore.instance.collection('chats').doc(uid).collection('chat').get().then((s) {
                      for (var d in s.docs) {
                        d.reference.delete();
                      }
                    });
                    setState(() { _messages.clear(); if (_model != null) _chat = _model!.startChat(); });
                    _sendTodaySummary();
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final timeStr = DateFormat('hh:mm a').format(msg['time'] ?? DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser)
                Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                    child: const Icon(Icons.smart_toy_rounded, size: 18, color: Color(0xFF1E88E5)),
                  ),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF42A5F5) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isUser
                      ? Text(
                          msg['text'],
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                        )
                      : MarkdownBody(
                          data: msg['text'],
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.4),
                            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 4, left: isUser ? 0 : 44, right: isUser ? 4 : 0),
            child: Text(
              timeStr,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.1),
            child: const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "NutriBot is typing...",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Ask about your diet...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              height: 48,
              width: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF42A5F5),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
