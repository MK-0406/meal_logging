import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Haptic Feedback
import 'dart:ui'; // Required for BackdropFilter
import 'home.dart';
import 'diary.dart';
import 'forum.dart';
import 'reminder.dart';
import 'profile_page.dart';

void main() {
  runApp(const MaterialApp(
    home: MainDashboard(),
    debugShowCheckedModeBanner: false,
  ));
}

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

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

  // These would typically be imported from your other files
  final List<Widget> _pages = [
    HomePage(),
    MealDiary(),
    ForumPage(),
    ReminderPage(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    if (index == currentPageIndex) return;

    // UX Improvement: Add a subtle vibration when switching tabs
    HapticFeedback.lightImpact();

    setState(() {
      currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody allows the body to flow behind the floating navigation bar
      extendBody: true,
      body: Stack(
        children: [
          // Global Background Gradient
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
      // Margin creates the "Floating" effect
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8), // Semi-transparent for glass effect
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
          // Blur the content behind the navigation bar (Glassmorphism)
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
                  selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.home_outlined, color: Colors.grey),
                  label: 'Home',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.auto_stories_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.auto_stories_outlined, color: Colors.grey),
                  label: 'Diary',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.forum_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.forum_outlined, color: Colors.grey),
                  label: 'Forum',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.notifications_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.notifications_none_rounded, color: Colors.grey),
                  label: 'Reminder',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF42A5F5)),
                  icon: Icon(Icons.person_outline_rounded, color: Colors.grey),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}