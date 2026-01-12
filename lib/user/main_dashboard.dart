import 'package:flutter/material.dart';
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: NavigationBar(
            backgroundColor: Colors.white,
            elevation: 0,
            height: 70,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
            selectedIndex: currentPageIndex,
            onDestinationSelected: (int index) {
              setState(() {
                currentPageIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                selectedIcon: Icon(Icons.home, color: Color(0xFF42A5F5)),
                icon: Icon(Icons.home_outlined, color: Colors.grey),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.book_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.book, color: Color(0xFF42A5F5)),
                label: 'Diary',
              ),
              NavigationDestination(
                icon: Icon(Icons.message_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.message, color: Color(0xFF42A5F5)),
                label: 'Forum',
              ),
              NavigationDestination(
                icon: Icon(Icons.alarm_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.alarm, color: Color(0xFF42A5F5)),
                label: 'Reminder',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: Colors.grey),
                selectedIcon: Icon(Icons.person, color: Color(0xFF42A5F5)),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F9FF), Color(0xFFE8F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _pages[currentPageIndex],
          ),
        ),
      ),
    );
  }
}
