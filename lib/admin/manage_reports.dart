import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManageReportsPage extends StatefulWidget {
  const ManageReportsPage({super.key});

  @override
  State<ManageReportsPage> createState() => _ManageReportsPageState();
}

class _ManageReportsPageState extends State<ManageReportsPage> {
  final CollectionReference reports = FirebaseFirestore.instance.collection('reports');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: reports.where('status', isEqualTo: 'pending').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading reports'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }

                final data = snapshot.data!.docs;
                if (data.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: data.length,
                  itemBuilder: (context, index) => _buildReportCard(data[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Reports", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Text("Moderate community content and reports", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () async {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportPageHistory()));
            },
          ),
        ],
      )
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 64, color: Colors.green.shade100),
          const SizedBox(height: 16),
          const Text("Inbox Clear!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("No pending reports to review.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReportCard(DocumentSnapshot doc) {
    final report = doc.data() as Map<String, dynamic>;
    final type = report['type'] ?? 'post';
    final postId = report['postId'];
    final commentId = report['commendId'];
    final timestamp = report['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM, hh:mm a').format(timestamp.toDate()) : 'Recently';

    return FutureBuilder<DocumentSnapshot>(
      future: type == 'post' 
          ? FirebaseFirestore.instance.collection('posts').doc(postId).get()
          : FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').doc(commentId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (!snapshot.data!.exists) {
          // Content already deleted but report is pending
          return const SizedBox.shrink();
        }

        final contentData = snapshot.data!.data() as Map<String, dynamic>;
        final author = type == 'post' ? (contentData['username'] ?? 'Unknown') : (contentData['authorName'] ?? 'Unknown');
        final contentText = type == 'post' ? (contentData['content'] ?? '') : (contentData['text'] ?? '');
        final titleText = type == 'post' ? (contentData['title'] ?? '') : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (type == 'post' ? Colors.purple : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(color: type == 'post' ? Colors.purple : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(dateStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Author: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(author, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                  ],
                ),
                const SizedBox(height: 8),

                if (type == 'post')
                  Row(
                    children: [
                      const Text("Title: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(titleText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),

                const SizedBox(height: 8),
                const Text("Content:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  contentText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const Divider(height: 32),
                const Text("Reason for report:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  report['reason']?.toString().isEmpty ?? true ? "No reason provided" : report['reason'],
                  style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50), fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleReport(doc.id, 'ignored'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Ignore"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showDeleteConfirm(doc.id, report),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text("Delete Content"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleReport(String reportId, String status) async {
    final adminDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
    final adminData = adminDoc.data() as Map<String, dynamic>;

    await reports.doc(reportId).update({
      'status': status,
      'resolvedById': FirebaseAuth.instance.currentUser!.uid,
      'resolvedByName': adminData['email'].split('@')[0],
      'resolvedAt': FieldValue.serverTimestamp()}
    );
  }

  void _showDeleteConfirm(String reportId, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete this ${report['type']}? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteContent(report);
              await _handleReport(reportId, 'deleted');
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContent(Map<String, dynamic> report) async {
    final postId = report['postId'];
    final type = report['type'];
    final commentId = report['commendId'];

    if (type == 'post') {
      await FirebaseFirestore.instance.collection('posts').doc(postId).set(
          {'deleted': true}, SetOptions(merge: true));
    } else if (type == 'comment' && commentId != null) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .set({'deleted': true}, SetOptions(merge: true));
      
      // Update comment count
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });
    }
  }
}


//add history
class ReportPageHistory extends StatefulWidget {
  const ReportPageHistory({super.key});

  @override
  State<ReportPageHistory> createState() => _ReportPageHistoryState();
}

class _ReportPageHistoryState extends State<ReportPageHistory> {
  final CollectionReference reports = FirebaseFirestore.instance.collection('reports');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: reports.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading reports'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }

                final data = snapshot.data!.docs;
                if (data.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: data.length,
                  itemBuilder: (context, index) => _buildReportCard(data[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        ),
        child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 20),
              Text("History", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ]
        )
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 64, color: Colors.green.shade100),
          const SizedBox(height: 16),
          const Text("Inbox Clear!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("No pending reports to review.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReportCard(DocumentSnapshot doc) {
    final report = doc.data() as Map<String, dynamic>;
    final type = report['type'] ?? 'post';
    final postId = report['postId'];
    final commentId = report['commendId'];
    final timestamp = report['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('dd MMM, hh:mm a').format(timestamp.toDate()) : 'Recently';

    return FutureBuilder<DocumentSnapshot>(
      future: type == 'post'
          ? FirebaseFirestore.instance.collection('posts').doc(postId).get()
          : FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').doc(commentId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (!snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final contentData = snapshot.data!.data() as Map<String, dynamic>;
        final author = type == 'post' ? (contentData['username'] ?? 'Unknown') : (contentData['authorName'] ?? 'Unknown');
        final contentText = type == 'post' ? (contentData['content'] ?? '') : (contentData['text'] ?? '');
        final titleText = type == 'post' ? (contentData['title'] ?? '') : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (type == 'post' ? Colors.purple : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(color: type == 'post' ? Colors.purple : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(dateStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Author: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(author, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                  ],
                ),
                const SizedBox(height: 8),

                if (type == 'post')
                  Row(
                    children: [
                      const Text("Title: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(titleText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),

                const SizedBox(height: 8),
                const Text("Content:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  contentText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const Divider(height: 32),
                const Text("Reason for report:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  report['reason']?.toString().isEmpty ?? true ? "No reason provided" : report['reason'],
                  style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50), fontStyle: FontStyle.italic),
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    const Text("Resolved by: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(
                      report['resolvedByName'] ?? "Unknown",
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E88E5), fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}