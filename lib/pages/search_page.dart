import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_provider.dart';
import '../services/music_folder_provider.dart';
import '../services/yt_dlp_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _ytDlp = YtDlpService();

  List<YtSearchResult> _results = [];
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;

  // Bulk select
  bool _bulkMode = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
      _selected.clear();
    });
    try {
      final results = await _ytDlp.search(query);
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _downloadSingle(String videoId, String outputDir, String thumbnailUrl) {
    final downloads = context.read<DownloadProvider>();
    final musicFolder = context.read<MusicFolderProvider>();
    downloads.download(
      videoId,
      outputDir,
      thumbnailUrl: thumbnailUrl,
      onLibraryChanged: () => musicFolder.setFolder(outputDir),
    );
  }

  void _downloadBulk(String outputDir) {
    if (_selected.isEmpty) return;
    final downloads = context.read<DownloadProvider>();
    final musicFolder = context.read<MusicFolderProvider>();
    final thumbMap = {
      for (final r in _results)
        if (_selected.contains(r.id)) r.id: r.thumbnailUrl,
    };
    downloads.enqueueBulk(
      _selected.toList(),
      outputDir,
      thumbnailUrls: thumbMap,
      onLibraryChanged: () => musicFolder.setFolder(outputDir),
    );
    setState(() {
      _bulkMode = false;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final musicFolder = context.watch<MusicFolderProvider>();
    final downloads = context.watch<DownloadProvider>();
    final outputDir = musicFolder.folder;

    return Scaffold(
      appBar: AppBar(
        title: const _MelodiLogoSearch(),
        actions: [
          if (_results.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() {
                _bulkMode = !_bulkMode;
                _selected.clear();
              }),
              icon: Icon(
                _bulkMode ? Icons.close : Icons.checklist,
                color: Colors.white70,
              ),
              label: Text(
                _bulkMode ? 'Cancel' : 'Select',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (_bulkMode && _selected.isNotEmpty)
            TextButton.icon(
              onPressed: outputDir != null
                  ? () => _downloadBulk(outputDir)
                  : _promptNoFolder,
              icon: const Icon(Icons.download, color: Color(0xFF0b007f)),
              label: Text(
                'Download ${_selected.length}',
                style: const TextStyle(color: Color(0xFF0b007f)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _focusNode.unfocus(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search YouTube...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF282828),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // No folder warning
          if (outputDir == null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF282828),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No music folder set. Choose one in the Library tab first.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error: $_error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _controller.text.isEmpty
                                  ? 'Type to search'
                                  : 'No results',
                              style: const TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final r = _results[i];
                              final dlState = downloads.stateFor(r.id);
                              final isSelected = _selected.contains(r.id);

                              return _SearchResultTile(
                                result: r,
                                dlState: dlState,
                                bulkMode: _bulkMode,
                                isSelected: isSelected,
                                onToggleSelect: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selected.remove(r.id);
                                    } else {
                                      _selected.add(r.id);
                                    }
                                  });
                                },
                                onDownload: () {
                                  if (outputDir != null) {
                                    _downloadSingle(r.id, outputDir, r.thumbnailUrl);
                                  } else {
                                    _promptNoFolder();
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _promptNoFolder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choose a music folder in the Library tab first.'),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final YtSearchResult result;
  final DownloadState dlState;
  final bool bulkMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDownload;

  const _SearchResultTile({
    required this.result,
    required this.dlState,
    required this.bulkMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 60,
              height: 45,
              child: result.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      result.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF282828),
                        child: const Icon(Icons.music_video,
                            color: Colors.white38, size: 24),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF282828),
                      child: const Icon(Icons.music_video,
                          color: Colors.white38, size: 24),
                    ),
            ),
          ),
          if (bulkMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0x880b007f)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isSelected
                    ? const Icon(Icons.check_circle,
                        color: Colors.white, size: 20)
                    : null,
              ),
            ),
        ],
      ),
      title: Text(
        result.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        '${result.channel} • ${result.duration}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      onTap: bulkMode ? onToggleSelect : null,
      trailing: bulkMode
          ? null
          : _DownloadButton(state: dlState, onDownload: onDownload),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final DownloadState state;
  final VoidCallback onDownload;
  const _DownloadButton({required this.state, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                strokeWidth: 2.5,
                color: const Color(0xFF0b007f),
              ),
              const Icon(Icons.downloading,
                  size: 16, color: Colors.white38),
            ],
          ),
        );
      case DownloadStatus.done:
        return const Icon(Icons.check_circle,
            color: Colors.greenAccent, size: 28);
      case DownloadStatus.error:
        return IconButton(
          icon: const Icon(Icons.error_outline, color: Colors.red),
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Download failed'),
                content: SingleChildScrollView(
                  child: Text(state.error ?? 'Unknown error'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Dismiss'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDownload();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        );
      case DownloadStatus.idle:
        return IconButton(
          icon: const Icon(Icons.download, color: Colors.white70),
          onPressed: onDownload,
        );
    }
  }
}

class _MelodiLogoSearch extends StatelessWidget {
  const _MelodiLogoSearch();

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
        ),
        const SizedBox(width: 8),
        const Text(
          'MELODI',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            fontFamily: 'Analogue BC',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

