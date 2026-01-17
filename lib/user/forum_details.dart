import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../functions.dart';

class ForumPostDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot post;

  const ForumPostDetailPage({
    super.key,
    required this.post
  });

  @override
  State<ForumPostDetailPage> createState() => _ForumPostDetailPage();
}

class _ForumPostDetailPage extends State<ForumPostDetailPage> {
  final _commentCtrl = TextEditingController();
  int _commentCount = 0;
  bool _isPosting = false;
  String? _replyToId;
  String? _replyToName;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainPost(),
                  const SizedBox(height: 28),
                  const Text(
                    "Discussion",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 12),
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
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
          const Text(
            'Topic Details',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPost() {
    final data = widget.post.data() as Map<String, dynamic>;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.person_rounded, color: Colors.blue.shade400, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['username'] ?? "Member", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(timeAgo(data['createdAt']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              _buildLikeButton(),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            data['title'] ?? "",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            data['content'] ?? "",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .doc(widget.post.id)
          .collection("likes")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final liked = snapshot.data?.exists ?? false;
        return Container(
          decoration: BoxDecoration(
            color: liked ? Colors.red.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? Colors.red : Colors.grey,
              size: 24,
            ),
            onPressed: () => liked 
              ? unlikePost(widget.post.id, FirebaseAuth.instance.currentUser!.uid) 
              : likePost(widget.post.id, FirebaseAuth.instance.currentUser!.uid),
          ),
        );
      },
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final allDocs = snapshot.data!.docs;
        if (allDocs.isEmpty) return Center(child: Text("No comments yet. Start the conversation!", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)));
        
        _commentCount = allDocs.length;

        // Group comments into parents and replies
        final List<QueryDocumentSnapshot> parents = [];
        final Map<String, List<QueryDocumentSnapshot>> replies = {};

        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final parentId = data['parentId'];
          if (parentId == null) {
            parents.add(doc);
          } else {
            if (!replies.containsKey(parentId)) {
              replies[parentId] = [];
            }
            replies[parentId]!.add(doc);
          }
        }

        return Column(
          children: parents.map((p) {
            final parentId = p.id;
            final List<Widget> children = [];
            children.add(_buildCommentCard(p.id, p.data() as Map<String, dynamic>, false));
            
            if (replies.containsKey(parentId)) {
              for (var r in replies[parentId]!) {
                children.add(_buildCommentCard(r.id, r.data() as Map<String, dynamic>, true));
              }
            }
            return Column(children: children);
          }).toList(),
        );
      },
    );
  }

  Widget _buildCommentCard(String commentId, Map<String, dynamic> data, bool isReply) {
    return Container(
      margin: EdgeInsets.only(bottom: 12, left: isReply ? 32 : 0),
      padding: EdgeInsets.fromLTRB(16, 16, 16, (isReply == false) ? 5 : 16),
      decoration: BoxDecoration(
        color: isReply ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey.shade100,
            child: Icon(Icons.person_rounded, size: 16, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['authorName'] ?? 'Member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(timeAgo(data['createdAt']), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(data['text'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4)),
                if (!isReply) 
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _replyToId = commentId;
                          _replyToName = data['authorName'] ?? 'Member';
                        });
                      },
                      child: const Text("Reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, (_replyToId != null) ? 5 : 12, 20, 25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Replying to $_replyToName",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _replyToId = null;
                      _replyToName = null;
                    }),
                  )
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: InputDecoration(
                    hintText: _replyToId != null ? "Write a reply..." : "Add a comment...",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isPosting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : GestureDetector(
                    onTap: () => addComment(widget.post.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Color(0xFF42A5F5), shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> addComment(String postId) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPosting = true);
    final userData = await Database.getDocument('usersInfo', null);
    await FirebaseFirestore.instance.collection("posts").doc(postId).collection("comments").add({
      "text": text,
      "authorId": FirebaseAuth.instance.currentUser!.uid,
      "authorName": userData['name'],
      "createdAt": FieldValue.serverTimestamp(),
      "parentId": _replyToId,
    });
    await FirebaseFirestore.instance.collection("posts").doc(postId).update({"commentCount": _commentCount});
    _commentCtrl.clear();
    setState(() {
      _isPosting = false;
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> likePost(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    await postRef.collection('likes').doc(userId).set({'liked': true, 'createdAt': FieldValue.serverTimestamp()});
    await postRef.update({'likeCount': FieldValue.increment(1)});
  }

  Future<void> unlikePost(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    await postRef.collection('likes').doc(userId).delete();
    await postRef.update({'likeCount': FieldValue.increment(-1)});
  }

  String timeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime dateTime = (timestamp is Timestamp) ? timestamp.toDate() : DateTime.now();
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
