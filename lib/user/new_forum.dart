import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../functions.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel("TOPIC TITLE"),
                    const SizedBox(height: 12),
                    _buildInputCard(
                      child: TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          hintText: "Enter a descriptive title...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a title' : null,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSectionLabel("YOUR STORY"),
                    const SizedBox(height: 12),
                    _buildInputCard(
                      child: TextFormField(
                        controller: _contentCtrl,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: "Share your thoughts, recipes, or experiences...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter some content' : null,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildPostButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
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
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Topic',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                Text(
                  'Start a new community discussion',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.blueGrey.shade300,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _handlePost,
          child: const Text(
            "Publish Topic",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePost() async {
    if (_formKey.currentState!.validate()) {
      final userID = FirebaseAuth.instance.currentUser!.uid;
      final userInfo = await Database.getDocument('usersInfo', null);
      final userInfoData = userInfo.data() as Map<String, dynamic>;

      await Database.addItems('posts', {
        'userId': userID,
        'username': userInfoData['name'],
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_titleCtrl.text}" published successfully!'),
          backgroundColor: const Color(0xFF1E88E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
