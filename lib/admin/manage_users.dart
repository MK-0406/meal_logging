import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with SingleTickerProviderStateMixin { //add tab
  final CollectionReference users = FirebaseFirestore.instance.collection('users');
  late Map<String, Map<String, dynamic>> usersData;
  int banCount = 0;
  int activeCount = 0;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    _loadCounts();
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  Future<void> _loadCounts() async {
    final bannedUsers = await FirebaseFirestore.instance.collection('usersInfo').where('ban', isEqualTo: true).get();
    final activeUsers = await FirebaseFirestore.instance.collection('usersInfo').where('ban', isEqualTo: false).get();

    setState(() {
      banCount = bannedUsers.docs.length;
      activeCount = activeUsers.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(false),
                _buildUserList(true),
              ],
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Manage Users", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          Text("Monitor and manage active members", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search for emails...",
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF42A5F5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close), onPressed: () {
            _searchController.clear();
            setState(() => _searchQuery = "");
          })
              : null,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 21, vertical: 10),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
        ),
        labelColor: const Color(0xFF1E88E5),
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Active"),
          Tab(text: "Banned"),
        ],
      ),
    );
  }

  Widget _buildUserList(bool showBan) {
    if (showBan == true && banCount == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text("No banned users found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 100),
        ]
      );
    }
    if (showBan == false && activeCount == 0) {
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            const Text("No active users found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 100),
          ]
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: users.where('role', isEqualTo: 'user').orderBy('email').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error loading users'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final data = snapshot.data!.docs.map((doc) {
          final user = doc.data() as Map<String, dynamic>;
          user['id'] = doc.id;
            return user;
        }).where((user) {
          return user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        if (data.isEmpty) return const Center(child: Text('No users found.'));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: data.length,
          itemBuilder: (context, index) => _buildUserCard(data[index], showBan),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool showBan) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usersInfo').doc(user['id']).get(),
      builder: (context, snapshot) {
        final info = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final isBanned = info['ban'] == true;
        if (isBanned != showBan) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: isBanned ? Colors.red.withValues(alpha: 0.1) : Colors.transparent),
          ),
          child: ListTile(
            onTap: () => _showUserDetails(user, info),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isBanned ? Colors.red.shade50 : const Color(0xFF42A5F5).withValues(alpha: 0.1),
              child: Icon(isBanned ? Icons.block_rounded : Icons.person_rounded, color: isBanned ? Colors.redAccent : const Color(0xFF1E88E5)),
            ),
            title: Text(user['email'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text(info['name'] ?? user['email'].split('@')[0], style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
          ),
        );
      }
    );
  }

  void _showUserDetails(Map<String, dynamic> user, Map<String, dynamic> info) {
    var isBanned = info['ban'] == true;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: isBanned ? Colors.red.shade50 : const Color(0xFF42A5F5).withValues(alpha: 0.1),
                child: Icon(isBanned ? Icons.block_rounded : Icons.person_rounded, size: 40, color: isBanned ? Colors.redAccent : const Color(0xFF1E88E5)),
              ),
              const SizedBox(height: 16),
              Text(info['name'] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(user['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 24),
              _detailRow("Gender", info['gender']),
              _detailRow("Age", "${info['age'] ?? '-'} years"),
              _detailRow("Status", isBanned ? "Banned" : "Active", color: isBanned ? Colors.red : Colors.green),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () async {
                      final data = await FirebaseFirestore.instance
                          .collection('usersInfo')
                          .doc(user['id'])
                          .collection('logs')
                          .orderBy('updatedAt').get();
                      final snapshots = data.docs;
                      List<QueryDocumentSnapshot> timelines = snapshots.map((doc) => doc).toList();
                      _showTimelineDialog(timelines);
                    },
                    child: Text('View Timeline >', style: TextStyle(color: Colors.blue.shade500, fontSize: 14))
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (info.isNotEmpty) {
                          _showBanDialog(user, isBanned);
                        }
                        //if (context.mounted) Navigator.pop(context);
                      },
                      icon: Icon(isBanned ? Icons.check_circle_outline : Icons.block_flipped, size: 18),
                      label: Text(isBanned ? "Unban" : "Ban"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isBanned ? Colors.green : Colors.red,
                        side: BorderSide(color: isBanned ? Colors.green : Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          Text(value?.toString() ?? "-", style: TextStyle(fontWeight: FontWeight.bold, color: color ?? const Color(0xFF2C3E50))),
        ],
      ),
    );
  }

  void _showTimelineDialog(List<QueryDocumentSnapshot> timelines) {
    showDialog(
      context: context,
      builder: (logContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Timeline",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: timelines.isEmpty
              ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline_outlined, size: 80, color: Colors.grey.shade200),
              const SizedBox(height: 16),
              const Text("No timeline found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
            ]
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: timelines.map((doc) => _buildTimeline(doc)).toList(),
          )
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(logContext),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final time = data['updatedAt'];
    final status = data['ban'] ? " Banned  " : "Unbanned"; //put extra spaces for better interface
    final reason = data['reason'] == '' ? "No reason" : data['reason'];
    final updatedBy = data['updatedBy'] ?? "Unknown";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(7),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data['ban'] ? Icons.block_rounded : Icons.check_circle_rounded, size: 32, color: data['ban'] ? Colors.red : Colors.green),
            Text(status, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]
        ),
        title: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reason: $reason', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text('Done by: $updatedBy', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]
        ),
      ),
    );
  }

  void _showBanDialog(Map<String, dynamic> user, bool isBanned) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (logContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isBanned ? "Unban User" : "Ban User",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBanned ? "Are you sure you want to unban this user?" : "Why you are banning this user?",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Enter reason (optional)...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(logContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBanned ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final admin = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
              final adminData = admin.data() as Map<String, dynamic>;

              await FirebaseFirestore.instance.collection('usersInfo').doc(user['id']).update({
                'ban': !isBanned,
                'updatedAt': FieldValue.serverTimestamp()
              });
              await FirebaseFirestore.instance
                  .collection('usersInfo')
                  .doc(user['id'])
                  .collection('logs')
                  .doc(DateFormat('yyyyMMddHHmmss').format(DateTime.now()))
                  .set({
                'ban': !isBanned,
                'updatedAt': DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now()),
                'reason': reasonCtrl.text,
                'updatedBy': adminData['email'].split('@')[0],
              });

              setState(() {
                _loadCounts();
              });

              if (!logContext.mounted) return;
              Navigator.pop(logContext);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("User banned successfully"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(isBanned ? "Unban" : "Ban"),
          ),
        ],
      ),
    );
  }
}
