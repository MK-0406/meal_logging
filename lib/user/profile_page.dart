import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meal_logging/login_screen.dart';
import 'package:meal_logging/main.dart';
import 'input_personal_health_info.dart';
import '../functions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? userInfoData;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final userDoc = await Database.getDocument('users', null);
    final userInfoDoc = await Database.getDocument('usersInfo', null);
    if (userDoc.exists && userInfoDoc.exists) {
      setState(() {
        userData = userDoc.data() as Map<String, dynamic>?;
        userInfoData = userInfoDoc.data() as Map<String, dynamic>?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: userInfoData == null
                ? _buildLoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      children: [
                        _buildUserOverview(),
                        const SizedBox(height: 32),
                        _buildInfoSection(
                          title: "Personal Profile",
                          icon: Icons.person_outline_rounded,
                          color: Colors.blue,
                          children: [
                            _buildInfoRow('Name', userInfoData!['name']),
                            _buildInfoRow('Gender', userInfoData!['gender']),
                            _buildInfoRow('Age', '${userInfoData!['age']} years'),
                            _buildInfoRow('Height', '${userInfoData!['height_m']} m'),
                            _buildInfoRow('Weight', '${userInfoData!['weight_kg']} kg'),
                            _buildInfoRow('BMI', '${userInfoData!['bmi']} kg/m²', isLast: true),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildInfoSection(
                          title: "Health Metrics",
                          icon: Icons.favorite_outline_rounded,
                          color: Colors.redAccent,
                          children: [
                            _buildHealthMetric(
                              'Blood Pressure',
                              '${userInfoData!['bloodPressureSystolic']}/${userInfoData!['bloodPressureDiastolic']}',
                              'mmHg',
                            ),
                            _buildHealthMetric(
                              'Blood Sugar',
                              '${userInfoData!['bloodSugar_mmolL']}',
                              'mmol/L',
                            ),
                            _buildHealthMetric(
                              'Cholesterol',
                              '${userInfoData!['cholesterol_mmolL']}',
                              'mmol/L',
                              isLast: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _buildActionButtons(),
                      ],
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
          const Text(
            'My Profile',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF42A5F5)),
          const SizedBox(height: 20),
          Text("Loading your profile...", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUserOverview() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.2), width: 4),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF42A5F5).withOpacity(0.1),
            child: const Icon(Icons.person_rounded, size: 60, color: Color(0xFF1E88E5)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userData!['email'] ?? 'No email',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            userData!['role']?.toUpperCase() ?? 'MEMBER',
            style: const TextStyle(color: Color(0xFF1E88E5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500)),
            Text(value?.toString() ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
          ],
        ),
        if (!isLast) Divider(height: 32, thickness: 1, color: Colors.grey.shade50),
      ],
    );
  }

  Widget _buildHealthMetric(String label, String value, String unit, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                Text(unit, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade300, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        if (!isLast) Divider(height: 32, thickness: 1, color: Colors.grey.shade50),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileFormScreen())),
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: const Text("Update Health Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            label: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
