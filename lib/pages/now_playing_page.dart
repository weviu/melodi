import 'package:flutter/material.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Now Playing – coming soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
