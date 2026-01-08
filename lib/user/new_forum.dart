import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../custom_styles.dart';
import '../functions.dart';
import '../main.dart';

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
                      'New Post',
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

            const SizedBox(height: 16),

            // ----- BODY -----
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [

                        // Title Input
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          child: TextFormField(
                              controller: _titleCtrl,
                              decoration: const InputDecoration(
                                labelText: "Title",
                                border: InputBorder.none,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              }
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Content Input
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          child: TextFormField(
                            controller: _contentCtrl,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: "Content",
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter some content';
                              }
                              return null;
                            }
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Post Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              shape: MaterialStateProperty.all(RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              )),
                              backgroundColor: MaterialStateProperty.all(
                                lightBlueTheme.colorScheme.primary,
                              ),
                              elevation: MaterialStateProperty.all(4),
                            ),
                            onPressed: () async {
                              if(_formKey.currentState!.validate()) {
                                final userID = FirebaseAuth.instance.currentUser!.uid;
                                final userInfo = await Database.getDocument('usersInfo', null);
                                final userInfoData = userInfo.data() as Map<String, dynamic>;

                                await Database.addItems('posts', {
                                  'userId': userID,
                                  'username': userInfoData['name'],
                                  'title': _titleCtrl.text,
                                  'content': _contentCtrl.text,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'likeCount': 0,
                                  'commentCount': 0
                                });

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${_titleCtrl.text} posted successfully!'),
                                    backgroundColor: lightBlueTheme.colorScheme.secondary,
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              "Post",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
            )
          ],
        ),
      ),
    );
  }
}
