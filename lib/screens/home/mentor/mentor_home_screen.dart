import 'package:flutter/material.dart';
import 'package:pemu_mentor/screens/home/mentor/add_event.dart';
import 'package:pemu_mentor/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../auth/profile.dart';
import 'resources_screen.dart';

class MentorHomeScreen extends StatefulWidget {
  final UserModel user;

  const MentorHomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<MentorHomeScreen> createState() => _MentorHomeScreenState();
}

class _MentorHomeScreenState extends State<MentorHomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      Profile(user: user),
      const AddEvent(), 
      const ResourcesScreen(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 
          ? 'Profile' 
          : _selectedIndex == 1 
            ? 'Add Event' 
            : 'Resources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            backgroundColor: Colors.blueAccent,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            label: 'Add Event',
            backgroundColor: Colors.blueAccent,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Resources',
            backgroundColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}
