import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'user/forum_details.dart';
import 'user/new_forum.dart';

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
  int itemCount = 0;

  Future<QuerySnapshot> getPosts() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .get();

    itemCount = querySnapshot.docs.length;

    return querySnapshot;
  }

  late final querySnapshot = getPosts();

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
                    const SizedBox(height: 5),
                    StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return CircularProgressIndicator();
                          }

                          final posts = snapshot.data!.docs;
                          final postCount = posts.length;

                          return Expanded(
                            child: ListView.builder(
                              itemCount: postCount + 1, // 10 posts + 1 for "See more"
                              itemBuilder: (context, index) {
                                if (index < postCount) {
                                  final post = posts[index];

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),

                                      title: Text(post['title']),

                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(post['content']),

                                          const SizedBox(height: 6),

                                          Row(
                                            children: [
                                              const Icon(Icons.favorite_border, size: 16),
                                              const SizedBox(width: 4),
                                              Text(post['likeCount'].toString()),

                                              const SizedBox(width: 16),

                                              const Icon(Icons.comment_outlined, size: 16),
                                              const SizedBox(width: 4),
                                              Text(post['commentCount'].toString()),
                                            ],
                                          ),
                                        ],
                                      ),

                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (
                                              context) => ForumPostDetailPage(post: post)),
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
                                          setState(() => itemCount += 10); // Load more posts
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
                            ),
                          );
                        }
                    ),
                  ]
              )
          )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

