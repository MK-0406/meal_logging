import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // --- Top Section: Title & Logo ---
                const Column(
                  children: [
                    Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E88E5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'FoodWise',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D47A1),
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(flex: 1),

                // --- Middle Section: Hero Image ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1).withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/welcome_img.png',
                      height: 280,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // --- Bottom Section: Description & Button ---
                Column(
                  children: [
                    Text(
                      'Smarter Eating Habits,\n healthier life.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Track nutrients, discover recipes, and get personalised recommendations tailored just for you.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blueGrey.shade400,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // --- Action Button ---
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
