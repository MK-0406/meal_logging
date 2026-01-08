import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'forum_details.dart';
import 'new_forum.dart';

class ForumPage extends StatelessWidget {
  const ForumPage({
    super.key,

  });

  @override
  Widget build(BuildContext context) {
    return const _ForumPage();
  }
}

class _ForumPage extends StatefulWidget {
  const _ForumPage();

  @override
  State<_ForumPage> createState() => ForumHomePage();
}

class ForumHomePage extends State<_ForumPage> {
  int itemCount = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lightBlueTheme.colorScheme.primary, lightBlueTheme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.forum, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Community Forum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Forum posts list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No posts yet.\nBe the first to create one!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    final posts = snapshot.data!.docs;
                    var postCount = posts.length;

                    if (itemCount > postCount) {
                      itemCount = postCount;
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: itemCount + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        print('$index $itemCount');

                        if (index < itemCount && index < postCount) {
                          final post = posts[index];
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                post['title'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    post['content'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(post['likeCount'].toString(), style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.comment_outlined, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(post['commentCount'].toString(), style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForumPostDetailPage(post: post),
                                  ),
                                );
                              },
                            ),
                          );
                        } else if (index == postCount) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text('No more posts', style: TextStyle(fontSize: 16)),
                            ),
                          );
                        } else {
                          // Last item: "See more" button
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() =>
                                  itemCount += 5); // Load more posts
                                  print("See more pressed");
                                  // Load more posts from backend or Firestore
                                },
                                child: const Text(
                                  "See more",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

}

