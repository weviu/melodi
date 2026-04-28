import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
      ),
      body: const Center(
        child: Text(
          'Library – coming soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
