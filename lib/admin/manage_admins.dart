import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../functions.dart';

class AdminRegPage extends StatefulWidget {
  const AdminRegPage({super.key});

  @override
  State<AdminRegPage> createState() => _AdminRegPageState();
}

class _AdminRegPageState extends State<AdminRegPage> {
  final CollectionReference users = FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: users.where('role', isEqualTo: 'admin').orderBy('registrationStatus', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading admins'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }

                final data = snapshot.data!.docs.map((doc) {
                  final user = doc.data() as Map<String, dynamic>;
                  user['id'] = doc.id;
                  return user;
                }).toList();

                if (data.isEmpty) return const Center(child: Text('No admin requests found.'));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: data.length,
                  itemBuilder: (context, index) => _buildAdminCard(data[index]),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Admin Management", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          Text("Review and approve admin registrations", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final status = admin['registrationStatus'] ?? 'pending';
    final color = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () => _showAdminDetails(admin),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(_getStatusIcon(status), color: color, size: 24),
        ),
        title: Text(admin['email'].split('@')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(admin['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  void _showAdminDetails(Map<String, dynamic> admin) {
    final status = admin['registrationStatus'] ?? 'pending';
    final color = _getStatusColor(status);

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
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(_getStatusIcon(status), size: 40, color: color),
              ),
              const SizedBox(height: 16),
              const Text("Admin Request", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(admin['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 24),
              _detailRow("Current Status", status.toUpperCase(), color: color),
              _detailRow("Role", "ADMIN"),
              const SizedBox(height: 32),
              Row(
                children: [
                  if (status == 'pending') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Database.setItems('users', admin['id'], {'registrationStatus': 'declined', 'updatedAt': FieldValue.serverTimestamp()});
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Decline"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await Database.setItems('users', admin['id'], {'registrationStatus': 'approved', 'updatedAt': FieldValue.serverTimestamp()});
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Approve"),
                      ),
                    ),
                  ] else
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

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? const Color(0xFF2C3E50))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'declined': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Icons.verified_user_rounded;
      case 'declined': return Icons.gpp_bad_rounded;
      default: return Icons.admin_panel_settings_rounded;
    }
  }
}
