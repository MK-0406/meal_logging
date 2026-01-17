import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'manage_meals.dart';
import 'manage_users.dart';
import 'manage_admins.dart';

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
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.01),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
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
                  selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
                  label: 'Home',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.people_outline_rounded, color: Colors.grey),
                  label: 'Users',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.admin_panel_settings_outlined, color: Colors.grey),
                  label: 'Admins',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.restaurant_menu_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.restaurant_menu_outlined, color: Colors.grey),
                  label: 'Meals',
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
    Future<Map<String, int>> getDashboardStats() async {
      final users = await FirebaseFirestore.instance.collection('users').get();
      final meals = await FirebaseFirestore.instance.collection('meals').get();
      final adminRequests = await FirebaseFirestore.instance
          .collection('users')
          .where('registrationStatus', isEqualTo: 'pending')
          .get();

      return {
        'users': users.docs.length,
        'meals': meals.docs.length,
        'approvals': adminRequests.docs.length,
      };
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Monitor application activity and manage data',
            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          FutureBuilder<Map<String, int>>(
            future: getDashboardStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {'users': 0, 'meals': 0, 'approvals': 0};
              return Column(
                children: [
                  _buildDashboardCard(
                    icon: Icons.person_rounded,
                    iconColor: Colors.blue,
                    title: 'Total Active Users',
                    value: '${stats['users']}',
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCard(
                    icon: Icons.fastfood_rounded,
                    iconColor: Colors.orange,
                    title: 'Meals in Database',
                    value: '${stats['meals']}',
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCard(
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: Colors.redAccent,
                    title: 'Pending Approvals',
                    value: '${stats['approvals']}',
                  ),
                ],
              );
            },
          ),
        ],
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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}
