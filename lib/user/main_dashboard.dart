import 'package:flutter/material.dart';
import 'package:meal_logging/main.dart';
import 'profile_page.dart';
import 'diary.dart';
import 'forum.dart';
import 'home.dart';
import 'reminder.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({
    super.key,

  });

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
    HomePage(),
    MealDiary(),
    ForumPage(),
    ReminderPage(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 3,
        //indicatorColor: Colors.teal.shade100,
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
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Forum',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Reminder',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
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
/*class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: const ValueKey('home'),
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(
            'Welcome Back 👋',
            style: theme.textTheme.headlineSmall?.copyWith(
              //color: Colors.teal.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your meals and stay healthy every day!',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),

          // 🌟 Quick Stats Section
          Row(
            children: [
              _buildStatCard(Icons.local_fire_department, 'Calories', '1,870 kcal'),
              const SizedBox(width: 12),
              _buildStatCard(Icons.fastfood, 'Meals', '3 logged'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard(Icons.fitness_center, 'Protein', '92 g'),
              const SizedBox(width: 12),
              _buildStatCard(Icons.water_drop, 'Water', '2.1 L'),
            ],
          ),
          const SizedBox(height: 24),

          // 🍽️ Meal Highlight
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              leading: const Icon(Icons.fastfood, color: Colors.teal),
              title: const Text('Today\'s Best Meal'),
              subtitle: const Text('Grilled Chicken Salad • 450 kcal'),
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/

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
              color: isSent ? lightBlueTheme.colorScheme.secondary : lightBlueTheme.colorScheme.tertiary,
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
}
