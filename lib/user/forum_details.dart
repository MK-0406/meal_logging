import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../functions.dart';
import '../main.dart';

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

  late String time = timeAgo(widget.post['createdAt']);

  final _commentCtrl = TextEditingController();
  int commentCount = 0;
  bool _isPosting = false;

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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Post Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ----- BODY -----
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Post content in a card
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Like
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.post['title'],
                                    style: const TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection("posts")
                                      .doc(widget.post.id)
                                      .collection("likes")
                                      .doc(FirebaseAuth.instance.currentUser!.uid)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    final liked = snapshot.data?.exists ?? false;

                                    return IconButton(
                                      icon: Icon(
                                        liked ? Icons.favorite : Icons.favorite_border,
                                        color: liked ? Colors.red : Colors.grey,
                                        size: 30,
                                      ),
                                      onPressed: () {
                                        if (liked) {
                                          unlikePost(widget.post.id,
                                              FirebaseAuth.instance.currentUser!.uid);
                                        } else {
                                          likePost(widget.post.id,
                                              FirebaseAuth.instance.currentUser!.uid);
                                        }
                                      },
                                    );
                                  },
                                )
                              ],
                            ),

                            const SizedBox(height: 12),
                            // Username + time
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  child: Icon(Icons.person, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${widget.post['username']} • $time",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Post content
                            Text(widget.post['content'],
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ----- COMMENTS LIST -----
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Comments",
                          style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.post.id)
                              .collection('comments')
                              .orderBy('createdAt', descending: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final comments = snapshot.data!.docs;

                            if (comments.isEmpty) {
                              return const Center(child: Text("No comments yet."));
                            }

                            commentCount = comments.length;

                            return Column(
                              children: comments.map((c) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        child: Icon(Icons.person, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c['authorName'] ?? 'Unknown',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(c['text'] ?? ''),
                                            const SizedBox(height: 4),
                                            Text(
                                              (c['createdAt'] == null) ? 'Just now' : timeAgo(c['createdAt']),
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList()
                            );
                          },
                        ),

                      // ----- COMMENT INPUT -----
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              )
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPosting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : CircleAvatar(
                    backgroundColor:
                    lightBlueTheme.colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => addComment(widget.post.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


  Future<void> addComment(String postId) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    final userData = await Database.getDocument('usersInfo', null);
    final username = userData['name'];

    await FirebaseFirestore.instance
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .add({
      "text": text,
      "authorId": widget.post['userId'],
      "authorName": username,
      "createdAt": FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection("posts")
        .doc(postId)
        .update({
      "commentCount": commentCount,
    });

    _commentCtrl.clear();
    setState(() => _isPosting = false);
  }

  String timeAgo(Timestamp timestamp) {
    final DateTime createdAt = timestamp.toDate();
    final Duration diff = DateTime.now().difference(createdAt);

    int duration = diff.inSeconds;
    String time = '$duration seconds';

    if (duration < 1) {
      time = 'Just now';
    } else {
      if (duration >= 60) {
        duration = diff.inMinutes;
        time = '$duration minutes ago';
        if (duration >= 60) {
          duration = diff.inHours;
          time = '$duration hours ago';
          if (duration >= 24) {
            duration = diff.inDays;
            time = '$duration days ago';
            if (duration >= 7) {
              duration = diff.inDays ~/ 7;
              time = '$duration weeks ago';
              if (duration >= 30) {
                duration = diff.inDays ~/ 30;
                time = '$duration months ago';
                if (duration >= 12) {
                  duration = diff.inDays ~/ 365;
                  time = '$duration years ago';
                }
              }
            }
          }
        }
      }
    }
    return time;
  }

  Future<void> likePost(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    // Create a like document under likes/{userId}
    await postRef.collection('likes').doc(userId).set({
      'liked': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increase likeCount
    await postRef.update({
      'likeCount': FieldValue.increment(1),
    });
  }

  Future<void> unlikePost(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    // Remove like entry
    await postRef.collection('likes').doc(userId).delete();

    // Decrease likeCount
    await postRef.update({
      'likeCount': FieldValue.increment(-1),
    });
  }

}


