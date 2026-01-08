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

  // Replace your existing ProfileScreen build body with this:

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFF1F8E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
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
                child: const Row(
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: userInfoData == null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: lightBlueTheme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading profile...',
                        style: TextStyle(
                          color: lightBlueTheme.colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // PROFILE AVATAR
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              lightBlueTheme.colorScheme.primary,
                              lightBlueTheme.colorScheme.secondary
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 70,
                            color: lightBlueTheme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // EMAIL + ROLE
                      Text(
                        userData!['email'] ?? 'No email',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: lightBlueTheme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightBlueTheme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userData!['role']?.toUpperCase() ?? 'USER',
                          style: TextStyle(
                            color: lightBlueTheme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // PERSONAL INFO CARD
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.lightBlue.shade50,
                                Colors.lightBlue.shade100,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_2, color: lightBlueTheme.colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Personal Information",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: lightBlueTheme.colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('Name', userInfoData!['name']),
                              _divider(),
                              _buildInfoRow('Gender', userInfoData!['gender']),
                              _divider(),
                              _buildInfoRow('Age', '${userInfoData!['age']} years'),
                              _divider(),
                              _buildInfoRow('Height', '${userInfoData!['height_m']} m'),
                              _divider(),
                              _buildInfoRow('Weight', '${userInfoData!['weight_kg']} kg'),
                              _divider(),
                              _buildInfoRow('BMI', '${userInfoData!['bmi']} kg/m²'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // HEALTH METRICS CARD
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.lightBlue.shade50,
                                Colors.lightBlue.shade100,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.monitor_heart, color: lightBlueTheme.colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Health Metrics",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: lightBlueTheme.colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildHealthMetric(
                                'Blood Pressure',
                                '${userInfoData!['bloodPressureSystolic']}/${userInfoData!['bloodPressureDiastolic']}',
                                'mmHg',
                              ),
                              _divider(),
                              _buildHealthMetric(
                                'Blood Sugar',
                                '${userInfoData!['bloodSugar_mmolL']}',
                                'mmol/L',
                              ),
                              _divider(),
                              _buildHealthMetric(
                                'Cholesterol',
                                '${userInfoData!['cholesterol_mmolL']}',
                                'mmol/L',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ACTION BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileFormScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: const Icon(Icons.edit, size: 20),
                              label: const Text(
                                "Update Profile",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoginScreen(),
                                      ));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: lightBlueTheme.colorScheme.secondary,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: lightBlueTheme.colorScheme.secondary),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: const Icon(Icons.logout, size: 20),
                              label: const Text(
                                "Logout",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value?.toString() ?? '-',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: lightBlueTheme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          //Icon(icon, color: Colors.deepOrange, size: 20),
          //const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: lightBlueTheme.colorScheme.secondary,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 20,
      thickness: 1,
      color: Colors.grey[200],
    );
  }
}