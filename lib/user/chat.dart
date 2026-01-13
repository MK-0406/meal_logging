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

  // Updated with VALID Google AI Model identifiers
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
        apiKey: 'AIzaSyDAFxRZVqCv-B-BR5cV9w1F6Me_2MJPLL0',
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 4096,
        ),
        systemInstruction: Content.system(
            'You are a expert nutrition assistant. Your goal is to provide feedback on logged meals and recommend meals ONLY from the provided database list. '
                'IMPORTANT: You CANNOT change the user\'s information (like weight, height, or age). If asked to do so, politely explain that you are an assistant and cannot modify their profile data. '
                'Use the provided [SYSTEM CONTEXT] regarding meal logs and health data only when relevant to the user\'s query. For general nutrition questions, answer directly. '
                'Always be encouraging, professional, and practical.'),
      );
      _chat = _model!.startChat();
      debugPrint('Active Model: ${_availableModels[_currentModelIndex]}');
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

  // Core logic to handle AI calls with automatic model fallback and improved error catching
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
      // Added 503 and 'overloaded' to the switching logic
      if (errorStr.contains('429') || errorStr.contains('quota') || errorStr.contains('limit') || errorStr.contains('503') || errorStr.contains('overloaded')) {
        debugPrint("Model ${_availableModels[_currentModelIndex]} busy or limit reached. Switching...");
        if (_switchToNextModel()) {
          // Retry with next model
          await _callAiWithRetry(date, dateStr: dateStr, manualText: manualText, isSummary: isSummary);
        } else {
          _addErrorMessage("All available AI models are currently at their capacity. Please wait a few minutes and try again.");
        }
      } else {
        _addErrorMessage("Sorry, I encountered an unexpected error. Please check your connection and try again.");
        debugPrint("AI Error Details: $e");
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
        final name = mData['name'] ?? 'Unknown';
        final ratio = serving / 100;
        final cal = (mData['calorie'] ?? 0) * ratio;
        final p = (mData['protein'] ?? 0) * ratio;
        final c = (mData['carb'] ?? 0) * ratio;
        final f = (mData['fat'] ?? 0) * ratio;

        summary += "- $type: $name (${serving}g) - ${cal.toStringAsFixed(0)}kcal (P:${p.toStringAsFixed(1)}g, C:${c.toStringAsFixed(1)}g, F:${f.toStringAsFixed(1)}g)\n";
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
              child: _messages.isEmpty ? _buildEmptyState() : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _buildChatBubble(_messages[index]),
              ),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF42A5F5))),
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
        gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("NutriBot", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade200),
        const SizedBox(height: 16),
        const Text("Hello! I'm your Nutrition Assistant.", style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    ));
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF42A5F5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isUser ? Text(msg['text'], style: const TextStyle(color: Colors.white)) : MarkdownBody(
          data: msg['text'],
          styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: TextField(
            controller: _textController,
            decoration: InputDecoration(hintText: "Ask about nutrition...", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
            onSubmitted: (_) => _sendMessage(),
          )),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: const Color(0xFF42A5F5), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
        ],
      ),
    );
  }
}