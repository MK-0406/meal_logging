import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../functions.dart';
import '../main.dart';

class AdminRegPage extends StatefulWidget {
  const AdminRegPage({super.key});

  @override
  State<AdminRegPage> createState() => _AdminRegPageState();
}

class _AdminRegPageState extends State<AdminRegPage> {
  final CollectionReference users = FirebaseFirestore.instance.collection(
    'users',
  );

  Future<void> _showUserDetails(Map<String, dynamic> data) async {

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFFE3F2FD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          data['email'],
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: lightBlueTheme.colorScheme.primary, thickness: 2),
            const SizedBox(height: 12),
            _buildInfoRow('Email', data['email']),
            _buildInfoRow('Role', data['role']),
            _buildInfoRow('Status', data['registrationStatus']),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.check_outlined, color: (data['registrationStatus'] != 'approved') ? lightBlueTheme.colorScheme.primary : Colors.grey),
            label: Text(
              'Approve',
              style: TextStyle(color: (data['registrationStatus'] != 'approved') ? lightBlueTheme.colorScheme.primary : Colors.grey),
            ),
            onPressed: (data['registrationStatus'] != 'approve')
              ? null
              : () async {
              Navigator.pop(context);
              await Database.setItems(
                'users',
                data['id'],
                {
                  'registrationStatus': 'approved',
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              );
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.block_outlined, color: (data['registrationStatus'] != 'pending') ? Colors.grey : Colors.red),
            label: Text('Decline', style: TextStyle(color: (data['registrationStatus'] != 'pending') ? Colors.grey : Colors.red)),

            onPressed: (data['registrationStatus'] != 'pending')
              ? null
              : () async {
              await Database.setItems(
                'users',
                data['id'],
                {
                  'registrationStatus': 'declined',
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Manage Admins',
          style: TextStyle(
            color: lightBlueTheme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: lightBlueTheme.colorScheme.tertiary,
        automaticallyImplyLeading: false,
      ),
      /*floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMealDialog(isEditing: false),
        backgroundColor: lightBlueTheme.colorScheme.secondary,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
      ),*/
      body: StreamBuilder<QuerySnapshot>(
        stream: users.where('role', isEqualTo: 'admin').orderBy('registrationStatus', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading admins'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: lightBlueTheme.colorScheme.primary,
              ),
            );
          }

          final data = snapshot.data!.docs.map((doc) {
            final user = doc.data() as Map<String, dynamic>;
            user['id'] = doc.id;
            return user;
          }).toList();

          if (data.isEmpty) {
            return const Center(child: Text('No admins found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final user = data[index];
              return Card(
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(
                    user['email'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${user['registrationStatus']}'),
                  trailing: Icon(
                    Icons.keyboard_arrow_right,
                    color: lightBlueTheme.colorScheme.secondary,
                  ),
                  onTap: () => _showUserDetails(user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Helper UI widgets
  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(': ${value ?? '-'}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
