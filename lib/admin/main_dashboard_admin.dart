import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'manage_meals.dart';
import 'manage_users.dart';
import 'manage_admins.dart';
import 'manage_reports.dart';
import '../login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainDashboardAdmin extends StatelessWidget {
  const MainDashboardAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MainDashboard();
  }
}

class _MainDashboard extends StatefulWidget {
  const _MainDashboard();

  @override
  State<_MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<_MainDashboard> {
  int currentPageIndex = 0;

  final List<Widget> _pages = const [
    _HomePage(),
    UsersPage(),
    AdminRegPage(),
    MealsPage(),
    ManageReportsPage(),
  ];

  void _onDestinationSelected(int index) {
    if (index == currentPageIndex) return;
    HapticFeedback.lightImpact();
    setState(() {
      currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8FAFF), Color(0xFFE8F4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey<int>(currentPageIndex),
                child: _pages[currentPageIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavigationBar(),
    );
  }

  Widget _buildFloatingNavigationBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xFF42A5F5).withValues(alpha: 0.12),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF42A5F5),
                  );
                }
                return const TextStyle(fontSize: 11, color: Colors.grey);
              }),
            ),
            child: NavigationBar(
              elevation: 0,
              height: 72,
              selectedIndex: currentPageIndex,
              onDestinationSelected: _onDestinationSelected,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  selectedIcon: Icon(
                    Icons.home_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  icon: Icon(Icons.home_outlined, color: Colors.grey),
                  label: 'Home',
                ),
                NavigationDestination(
                  selectedIcon: Icon(
                    Icons.people_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  icon: Icon(Icons.people_outline_rounded, color: Colors.grey),
                  label: 'Users',
                ),
                NavigationDestination(
                  selectedIcon: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  icon: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.grey,
                  ),
                  label: 'Admins',
                ),
                NavigationDestination(
                  selectedIcon: Icon(
                    Icons.fastfood_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  icon: Icon(Icons.fastfood_outlined, color: Colors.grey),
                  label: 'Meals',
                ),
                NavigationDestination(
                  selectedIcon: Icon(
                    Icons.report_rounded,
                    color: Color(0xFF42A5F5),
                  ),
                  icon: Icon(Icons.report_outlined, color: Colors.grey),
                  label: 'Reports',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    bool isLoading = false;
    Future<Map<String, int>> getDashboardStats() async {
      isLoading = true;
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      final meals = await FirebaseFirestore.instance
          .collection('meals')
          .where('deleted', isEqualTo: false)
          .get();
      final adminRequests = await FirebaseFirestore.instance
          .collection('users')
          .where('registrationStatus', isEqualTo: 'pending')
          .get();
      final reports = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();

      isLoading = false;

      return {
        'users': users.docs.length,
        'admins': admins.docs.length,
        'meals': meals.docs.length,
        'approvals': adminRequests.docs.length,
        'reports': reports.docs.length,
      };
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<Map<String, int>>(
        future: getDashboardStats(),
        builder: (context, snapshot) {
          final stats =
              snapshot.data ??
              {'users': 0, 'meals': 0, 'approvals': 0, 'reports': 0};

          return ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF0D47A1),
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              isLoading == true
                  ? const Center(
                      heightFactor: 10,
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildDashboardCard(
                          icon: Icons.person,
                          iconColor: Colors.blue.shade600,
                          title: 'Total Users',
                          value: '${stats['users']}',
                        ),
                        const SizedBox(height: 12),
                        _buildDashboardCard(
                          icon: Icons.admin_panel_settings,
                          iconColor: Colors.green.shade600,
                          title: 'Total Admins',
                          value: '${stats['admins']}',
                        ),
                        const SizedBox(height: 12),
                        _buildDashboardCard(
                          icon: Icons.fastfood,
                          iconColor: Colors.orange.shade600,
                          title: 'Total Meals',
                          value: '${stats['meals']}',
                        ),
                        const SizedBox(height: 12),
                        _buildDashboardCard(
                          icon: Icons.approval,
                          iconColor: Colors.red.shade600,
                          title: 'Pending Admin Approvals',
                          value: '${stats['approvals']}',
                        ),
                        const SizedBox(height: 12),
                        _buildDashboardCard(
                          icon: Icons.report_problem_rounded,
                          iconColor: Colors.purple.shade600,
                          title: 'Total Reports',
                          value: '${stats['reports']}',
                        ),
                      ],
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.18),
          radius: 22,
          child: Icon(icon, size: 26, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
