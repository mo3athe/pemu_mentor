import 'package:flutter/material.dart';
import 'package:pemu_mentor/screens/auth/profile.dart';
import 'package:pemu_mentor/screens/home/mentee/mentee_resources_tab.dart';
import 'package:pemu_mentor/screens/home/mentee/mentor_list_screen.dart';
import 'package:pemu_mentor/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';

class MenteeHomeScreen extends StatefulWidget {
  final UserModel user;

  const MenteeHomeScreen({super.key, required this.user});

  @override
  State<MenteeHomeScreen> createState() => _MenteeHomeScreenState();
}

class _MenteeHomeScreenState extends State<MenteeHomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      MentorListScreen(),
      const MenteeResourcesTab(), // Replaced Center with MenteeResourcesTab
      Profile(user: user),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    try {
      await context.read<AuthService>().signOut();
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _titles = ['Mentors', 'Resources', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Logout'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _handleLogout();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Mentors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Resources',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}