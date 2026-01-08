import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meal_logging/main.dart';
import 'manage_meals.dart';
import '../functions.dart';

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
    /*_NotificationsPage(),
    _MessagesPage(),*/
    MealsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: NavigationBar(
        //backgroundColor: Colors.white,
        elevation: 3,
        //indicatorColor: Colors.deepOrange.shade100,
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fastfood_outlined),
            selectedIcon: Icon(Icons.fastfood),
            label: 'Meals',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Users',
            enabled: false,
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admins',
            enabled: false,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _pages[currentPageIndex],
          ),
        ),
      ),
    );
  }
}

/// 🏠 Home Page
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Future<Map<String, int>> getDashboardStats() async {
      final users = await FirebaseFirestore.instance.collection('users').get();
      final meals = await FirebaseFirestore.instance.collection('meals').get();

      // Change this collection name if different
      final adminRequests = await FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      return {
        'users': users.docs.length,
        'meals': meals.docs.length,
        'approvals': adminRequests.docs.length,
      };
    }

    return Padding(
      key: const ValueKey('home'),
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<Map<String, int>>(
        future: getDashboardStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? {
            'users': 0,
            'meals': 0,
            'approvals': 0,
          };

          return ListView(
            children: [
              Text(
                'Admin Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 20),

              // ⭐ TOTAL USERS
              _buildDashboardCard(
                icon: Icons.person,
                iconColor: Colors.blue.shade600,
                title: 'Total Users',
                value: '${stats['users']}',
              ),

              const SizedBox(height: 12),

              // ⭐ ACTIVE MEALS
              _buildDashboardCard(
                icon: Icons.fastfood,
                iconColor: Colors.orange.shade600,
                title: 'Total Meals',
                value: '${stats['meals']}',
                onTap: () {
                  final dashboardState = context.findAncestorStateOfType<_MainDashboardState>();
                  dashboardState?.setState(() {
                    dashboardState.currentPageIndex = 1; // go to Meals tab
                  });
                }
              ),

              const SizedBox(height: 12),

              // ⭐ PENDING APPROVALS
              _buildDashboardCard(
                icon: Icons.admin_panel_settings,
                iconColor: Colors.red.shade600,
                title: 'Pending Admin Approvals',
                value: '${stats['approvals']}',
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
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.blue.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.18),
          radius: 22,
          child: Icon(icon, size: 26, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

}

/*/// 🔔 Notifications Page
class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('notifications'),
      padding: const EdgeInsets.all(16),
      children: const [
        _NotificationCard(
          title: 'System Update',
          message: 'New version 2.0 deployed successfully.',
        ),
        _NotificationCard(
          title: 'Meal Added',
          message: 'New meal “Vegan Bowl” was added by Chef Lisa.',
        ),
        _NotificationCard(
          title: 'Admin Request',
          message: 'A new admin request is pending approval.',
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;

  const _NotificationCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(Icons.notifications, color: lightBlueTheme.colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(message),
      ),
    );
  }
}

/// 💬 Messages Page
class _MessagesPage extends StatelessWidget {
  const _MessagesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      key: const ValueKey('messages'),
      padding: const EdgeInsets.all(16),
      reverse: true,
      itemCount: 2,
      itemBuilder: (context, index) {
        final isSent = index == 0;
        return Align(
          alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSent
                  ? lightBlueTheme.colorScheme.secondary
                  : lightBlueTheme.colorScheme.tertiary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isSent ? 'Hello' : 'Hi!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isSent ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }
}*/
