import 'dart:io';

import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/now_playing_page.dart';
import 'pages/search_page.dart';
import 'theme.dart';
import 'services/download_provider.dart';
import 'services/music_folder_provider.dart';
import 'services/player_provider.dart';
import 'services/playlist_provider.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite FFI only needed on desktop (Linux/Windows/macOS)
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
  }

  // MetadataGod uses a Rust/CargoKit native library that is not compiled
  // for Android in this build. Skip it on Android to avoid a startup hang.
  if (!Platform.isAndroid && !Platform.isIOS) {
    await MetadataGod.initialize().catchError((e) {
      debugPrint('MetadataGod init failed (non-fatal): $e');
    });
  }

  // Request runtime permissions on Android before anything else
  if (Platform.isAndroid) {
    // MANAGE_EXTERNAL_STORAGE (Android 11+) lets the user pick any folder for
    // their music library and have the app write downloaded files there.
    // This opens the system "Allow access to manage all files" settings screen.
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
    await [
      Permission.audio,        // READ_MEDIA_AUDIO
      Permission.notification, // POST_NOTIFICATIONS (mandatory Android 13+)
    ].request();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => MusicFolderProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        // PlaylistProvider auto-loads when MusicFolderProvider's folder changes
        ChangeNotifierProxyProvider<MusicFolderProvider, PlaylistProvider>(
          create: (_) => PlaylistProvider(),
          update: (_, folderProvider, playlistProvider) {
            final folder = folderProvider.folder;
            final provider = playlistProvider ?? PlaylistProvider();
            if (folder != null) provider.load(folder);
            return provider;
          },
        ),
      ],
      child: const MelodiApp(),
    ),
  );
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
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kBgSurface,
          indicatorColor: kLilyDark.withAlpha(40),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: kLilyDark);
            }
            return const IconThemeData(color: kTextSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: kLilyDark, fontSize: 12);
            }
            return const TextStyle(color: kTextSecondary, fontSize: 12);
          }),
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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        onGoToSearch: () => setState(() => _selectedIndex = 1),
        onGoToLibrary: () => setState(() => _selectedIndex = 2),
      ),
      const SearchPage(),
      const LibraryPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NowPlayingPage()),
            ),
          ),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
