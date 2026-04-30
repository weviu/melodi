import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../data/song_model.dart';
import '../services/download_provider.dart';
import '../services/music_folder_provider.dart';
import '../services/playlist_provider.dart';
import '../services/scanner_service.dart';
import '../theme.dart';
import 'playlist_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _db = DatabaseHelper();
  final _scanner = ScannerService();

  List<Song> _songs = [];
  bool _isScanning = false;
  int _filterIndex = 0; // 0 = Playlists, 1 = Artists
  Map<String, int> _playlistCounts = {};

  @override
  void initState() {
    super.initState();
    _loadFromDb();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().addListener(_onDownloadChanged);
      context.read<PlaylistProvider>().addListener(_onPlaylistsChanged);
      _loadPlaylists();
    });
  }

  @override
  void dispose() {
    context.read<DownloadProvider>().removeListener(_onDownloadChanged);
    context.read<PlaylistProvider>().removeListener(_onPlaylistsChanged);
    super.dispose();
  }

  void _onDownloadChanged() => _loadFromDb();
  void _onPlaylistsChanged() => _loadPlaylistCounts();

  void _loadPlaylists() {
    final folder = context.read<MusicFolderProvider>().folder;
    if (folder != null) {
      context.read<PlaylistProvider>().load(folder).then((_) => _loadPlaylistCounts());
    }
  }

  Future<void> _loadFromDb() async {
    final songs = await _db.getAllSongs();
    if (!mounted) return;
    setState(() => _songs = songs);
    await _loadPlaylistCounts();
  }

  Future<void> _loadPlaylistCounts() async {
    if (!mounted) return;
    final provider = context.read<PlaylistProvider>();
    final counts = <String, int>{};
    for (final name in provider.playlists) {
      final songList = await provider.getSongs(name, _songs);
      counts[name] = songList.length;
    }
    if (mounted) setState(() => _playlistCounts = counts);
  }

  Future<void> _pickAndScan() async {
    String? dir;
    try {
      dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Music Folder',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder picker error: $e')),
        );
      }
      return;
    }

    if (dir == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No folder selected')),
        );
      }
      return;
    }

    if (mounted) {
      await context.read<MusicFolderProvider>().setFolder(dir);
      if (mounted) await context.read<PlaylistProvider>().load(dir);
    }

    setState(() => _isScanning = true);
    try {
      final songs = await _scanner.scanDirectory(dir);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${songs.length} MP3 file(s)')),
        );
      }
      await _db.clearSongs();
      await _db.insertSongs(songs);
      await _loadFromDb();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  List<String> get _artists {
    final set = <String>{};
    for (final s in _songs) {
      set.add(s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist);
    }
    final list = set.toList()
      ..sort((a, b) {
        if (a == 'Unknown Artist') return 1;
        if (b == 'Unknown Artist') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return list;
  }

  Uint8List? _artistArt(String artist) {
    try {
      return _songs.firstWhere(
        (s) =>
            (s.artist.trim().isEmpty ? 'Unknown Artist' : s.artist) == artist &&
            s.albumArt != null,
      ).albumArt;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().playlists;
    final artists = _artists;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgSurface,
        title: const _MelodiLogo(),
        centerTitle: true,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Choose Music Folder',
              onPressed: _pickAndScan,
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Library header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _LibraryFilterChip(
                    label: 'Playlists',
                    active: _filterIndex == 0,
                    onTap: () => setState(() => _filterIndex = 0),
                  ),
                  const SizedBox(width: 8),
                  _LibraryFilterChip(
                    label: 'Artists',
                    active: _filterIndex == 1,
                    onTap: () => setState(() => _filterIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  _HoverIconButton(
                    icon: Icons.add,
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
                ],
              ),
            ),
          ),

          // ── Grid content ────────────────────────────────────────────
          if (_filterIndex == 0) ...[
            if (playlists.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.music_note,
                  title: 'Create your first playlist',
                  subtitle: 'Organise your music into playlists.',
                  buttonLabel: 'New Playlist',
                  onButton: () => _showCreatePlaylistDialog(context),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _PlaylistCard(
                      name: playlists[i],
                      songCount: _playlistCounts[playlists[i]] ?? 0,
                      allSongs: _songs,
                    ),
                    childCount: playlists.length,
                  ),
                ),
              ),
          ] else ...[
            if (artists.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _ArtistEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ArtistCard(
                      name: artists[i],
                      art: _artistArt(artists[i]),
                    ),
                    childCount: artists.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kHoverBg,
        title: const Text('New Playlist', style: TextStyle(color: kTextPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: kTextPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Color(0x61FFFFFF)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: kLilyDark),
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              context.read<PlaylistProvider>().create(v.trim());
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<PlaylistProvider>().create(ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Create', style: TextStyle(color: kLilyLight)),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────

class _LibraryFilterChip extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LibraryFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_LibraryFilterChip> createState() => _LibraryFilterChipState();
}

class _LibraryFilterChipState extends State<_LibraryFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active
                ? kTextPrimary
                : _hovered
                    ? kLilyLight.withAlpha(51)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: widget.active ? null : Border.all(color: Colors.white38),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.active ? kBgDark : kTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hover icon button ──────────────────────────────────────────────────────────

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _HoverIconButton({required this.icon, required this.onPressed});

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? kLilyLight : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(widget.icon, color: kTextPrimary, size: 20),
        ),
      ),
    );
  }
}

// ── Playlist card ──────────────────────────────────────────────────────────────

class _PlaylistCard extends StatefulWidget {
  final String name;
  final int songCount;
  final List<Song> allSongs;

  const _PlaylistCard({
    required this.name,
    required this.songCount,
    required this.allSongs,
  });

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistDetailPage(
              playlistName: widget.name,
              allSongs: widget.allSongs,
            ),
          ),
        ),
        onSecondaryTap: () => _showDeleteDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()..scale(_hovered ? 1.03 : 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered ? kHoverBg : kBgSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [kLilyLight, kBgDark],
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Playlist \u2022 ${widget.songCount} songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kHoverBg,
        title: Text('Delete "${widget.name}"?',
            style: const TextStyle(color: kTextPrimary)),
        content: const Text('This will delete the playlist file.',
            style: TextStyle(color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<PlaylistProvider>().delete(widget.name);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Artist card ────────────────────────────────────────────────────────────────

class _ArtistCard extends StatefulWidget {
  final String name;
  final Uint8List? art;

  const _ArtistCard({required this.name, this.art});

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..scale(_hovered ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered ? kHoverBg : kBgSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1000),
                child: widget.art != null
                    ? Image.memory(widget.art!, fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [kLilyLight, kBgDark],
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Artist',
              style: TextStyle(color: kTextSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty states ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onButton;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: kTextSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: kTextSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onButton,
            style: ElevatedButton.styleFrom(
              backgroundColor: kLilyDark,
              foregroundColor: kTextPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ArtistEmptyState extends StatelessWidget {
  const _ArtistEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No music in your library yet.\nUse the Search tab to download songs.',
        textAlign: TextAlign.center,
        style: TextStyle(color: kTextSecondary, fontSize: 14),
      ),
    );
  }
}

// ── Melodi logo ────────────────────────────────────────────────────────────────

class _MelodiLogo extends StatelessWidget {
  const _MelodiLogo();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1E4A9E);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'lily.svg',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
        const SizedBox(width: 8),
        const Text(
          'MELODI',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'Analogue BC',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
