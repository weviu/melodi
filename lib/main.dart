import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pages/library_page.dart';
import 'pages/now_playing_page.dart';
import 'pages/search_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  await MetadataGod.initialize();
  runApp(const MelodiApp());
}

class MelodiApp extends StatelessWidget {
  const MelodiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melodi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0b007f),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF121212),
          onSurface: Colors.white,
          surfaceContainerHighest: const Color(0xFF282828),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF181818),
          indicatorColor: Color(0xFF0b007f),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white, fontSize: 12),
          ),
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: Colors.white70),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181818),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    LibraryPage(),
    SearchPage(),
    NowPlayingPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_music_outlined),
            selectedIcon: Icon(Icons.queue_music),
            label: 'Now Playing',
          ),
        ],
      ),
    );
  }
}
