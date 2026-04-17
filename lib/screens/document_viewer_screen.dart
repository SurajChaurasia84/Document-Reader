import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../services/office_service.dart';
import '../utils/theme_utils.dart';
import '../widgets/glass_card.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.file});

  final AppFile file;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final bool _fileExists = File(widget.file.path).existsSync();
  late AppFile _currentFile = widget.file;
  late final AppController _appController;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  
  double _zoomScale = 1;
  bool _isFindMode = false;
  bool _isSearching = false;
  String _searchQuery = '';
  List<_DocumentSearchMatch> _searchMatches = const <_DocumentSearchMatch>[];
  int _currentMatchIndex = 0;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showScrubber = false;
  Timer? _scrubberHideTimer;
  bool _isDraggingScrubber = false;
  double _totalPdfHeight = 0;
  double _currentScrollY = 0;
  double _viewportHeight = 0;
  Timer? _scrollTimer;
  late final Future<String?> _textContentFuture = _currentFile.isText && _fileExists
      ? File(_currentFile.path).readAsString()
      : Future<String?>.value(null);
  late final Future<String?> _officeContentFuture;
  late final Future<SpreadsheetPreviewData?> _spreadsheetPreviewFuture;
  late final Future<PresentationPreviewData?> _presentationPreviewFuture;
  bool _isPreparingPdf = false;

  bool get _isPaperLikeFile =>
      widget.file.isText ||
      <String>['doc', 'docx'].contains(widget.file.extension.toLowerCase());
  bool _pdfNeedsPassword = false;
  bool _isPasswordPromptOpen = false;
  String? _pdfPassword;
  String? _pdfOpenError;

  @override
  void initState() {
    super.initState();
    _appController = context.read<AppController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _appController.openFile(widget.file);
    });
    _officeContentFuture = _isPreviewableOfficeFile(_currentFile) && _fileExists
        ? _appController.officeService.extractPreviewText(_currentFile.path)
        : Future<String?>.value(null);
    _spreadsheetPreviewFuture =
        _currentFile.extension.toLowerCase() == 'xlsx' && _fileExists
        ? _appController.officeService.extractSpreadsheetPreview(_currentFile.path)
        : Future<SpreadsheetPreviewData?>.value(null);
    _presentationPreviewFuture =
        _currentFile.extension.toLowerCase() == 'pptx' && _fileExists
        ? _appController.officeService.extractPresentationPreview(_currentFile.path)
        : Future<PresentationPreviewData?>.value(null);
    if (_currentFile.isPdf && _fileExists) {
      _preparePdf();
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
    _scrubberHideTimer?.cancel();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
    _showScrubberTemporarily();
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    double totalHeight = 0;
    for (int i = 0; i < details.document.pages.count; i++) {
      totalHeight += details.document.pages[i].size.height;
    }
    // Add page spacing (5px as defined in SfPdfViewer)
    totalHeight += (details.document.pages.count - 1) * 5;

    setState(() {
      _totalPages = details.document.pages.count;
      _totalPdfHeight = totalHeight;
      _isPreparingPdf = false;
    });

    // Start polling for scroll updates since SfPdfViewer has no onScrollChanged
    _startScrollPolling();
  }

  void _startScrollPolling() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final newOffset = _pdfViewerController.scrollOffset.dy;
      if (newOffset != _currentScrollY && !_isDraggingScrubber) {
        setState(() {
          _currentScrollY = newOffset;
        });
        if (newOffset != 0) _showScrubberTemporarily();
      }
    });
  }

  void _showScrubberTemporarily() {
    if (_isDraggingScrubber) return;
    
    _scrubberHideTimer?.cancel();
    if (!_showScrubber) {
      setState(() => _showScrubber = true);
    }
    
    _scrubberHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isDraggingScrubber) {
        setState(() => _showScrubber = false);
      }
    });
  }

  void _onScrubberDragStart(DragStartDetails details) {
    _scrubberHideTimer?.cancel();
    setState(() {
      _isDraggingScrubber = true;
      _showScrubber = true;
    });
  }

  void _onScrubberDragUpdate(DragUpdateDetails details, double maxHeight) {
    if (_totalPdfHeight <= 0) return;
    
    final ratio = (details.localPosition.dy / maxHeight).clamp(0.0, 1.0);
    final targetY = ratio * (_totalPdfHeight - _viewportHeight);
    
    _pdfViewerController.jumpTo(yOffset: targetY);
    
    setState(() {
      _currentScrollY = targetY;
    });
    _showScrubberTemporarily();
  }

  void _onScrubberDragEnd(DragEndDetails details) {
    setState(() => _isDraggingScrubber = false);
    _showScrubberTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    final usePdfChrome = _currentFile.isPdf && _fileExists;
    final isPaperLike = _isPaperLikeFile;
    final pdfBackground = context.isDarkMode ? Colors.black : Colors.white;
    final pdfForeground =
        context.isDarkMode ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: usePdfChrome ? pdfBackground : null,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: usePdfChrome ? pdfBackground : null,
        foregroundColor: usePdfChrome ? pdfForeground : null,
        leading: _isFindMode
            ? IconButton(
                onPressed: _closeFindMode,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: _isFindMode
            ? _FindBar(
                controller: _findController,
                focusNode: _findFocusNode,
                hintColor: usePdfChrome
                    ? Colors.white70
                    : context.secondaryText,
                textColor: usePdfChrome ? Colors.white : context.primaryText,
                surfaceColor: usePdfChrome
                    ? (context.isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFF3F4F6))
                    : context.searchBackground,
                onChanged: _onFindQueryChanged,
                onClear: _clearFindQuery,
              )
            : Text(
                _currentFile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (Theme.of(context).appBarTheme.titleTextStyle ??
                        Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(
                      fontSize:
                          MediaQuery.of(context).size.width < 380 ? 16 : 18,
                      color: usePdfChrome ? pdfForeground : context.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
        actions: <Widget>[
          if (!_isFindMode)
            IconButton(
              onPressed: _openFindMode,
              icon: const Icon(Icons.find_in_page_rounded),
            ),
          if (!_isFindMode)
            IconButton(
              onPressed: () => _shareFile(context),
              icon: const Icon(Icons.share_rounded),
            ),
          if (_isFindMode) ...<Widget>[
            IconButton(
              onPressed: _canGoToPreviousMatch ? _goToPreviousMatch : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Center(
                child: _FindCountLabel(
                  isSearching: _isSearching,
                  query: _searchQuery,
                  total: _searchMatches.length,
                  currentIndex: _currentMatchIndex,
                  usePdfChrome: usePdfChrome,
                ),
              ),
            ),
            IconButton(
              onPressed: _canGoToNextMatch ? _goToNextMatch : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
          if (!_isFindMode)
            PopupMenuButton<_ViewerAction>(
              color: usePdfChrome ? context.panelBackground : null,
              surfaceTintColor: Colors.transparent,
              onSelected: (value) => _handleViewerAction(context, value),
              itemBuilder: (context) {
                return <PopupMenuEntry<_ViewerAction>>[
                  PopupMenuItem<_ViewerAction>(
                    value: _ViewerAction.openExternally,
                    child: Text(
                      'Open externally',
                      style: TextStyle(color: context.primaryText),
                    ),
                  ),
                  PopupMenuItem<_ViewerAction>(
                    value: _ViewerAction.favorite,
                    child: Text(
                      _currentFile.isFavorite
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      style: TextStyle(color: context.primaryText),
                    ),
                  ),
                  PopupMenuItem<_ViewerAction>(
                    value: _ViewerAction.rename,
                    child: Text(
                      'Rename',
                      style: TextStyle(color: context.primaryText),
                    ),
                  ),
                  PopupMenuItem<_ViewerAction>(
                    value: _ViewerAction.download,
                    child: Text(
                      'Download',
                      style: TextStyle(color: context.primaryText),
                    ),
                  ),
                  PopupMenuItem<_ViewerAction>(
                    value: _ViewerAction.delete,
                    child: Text(
                      'Delete',
                      style: TextStyle(color: context.primaryText),
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          _buildContent(context),
          if (_isFindMode &&
              _searchQuery.isNotEmpty &&
              !_isSearching &&
              _searchMatches.isEmpty)
            _buildNoSearchResults(context, usePdfChrome),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final pdfBackground = context.isDarkMode ? Colors.black : Colors.white;
    final pdfForeground = context.isDarkMode
        ? Colors.white
        : const Color(0xFF111827);
    if (!_fileExists) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: GlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'File not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'This file looks deleted, moved, or no longer accessible.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.file.isPdf) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _viewportHeight = constraints.maxHeight;
          final scrubHeight = constraints.maxHeight - 40;
          double thumbY = 0;
          
          final maxScroll = _totalPdfHeight - _viewportHeight;
          if (maxScroll > 0) {
            thumbY = (_currentScrollY / maxScroll) * scrubHeight;
          }

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  color: pdfBackground,
                  child: SfPdfViewer.file(
                    File(_currentFile.path),
                    controller: _pdfViewerController,
                    pageSpacing: 5,
                    onPageChanged: _onPageChanged,
                    onDocumentLoaded: _onDocumentLoaded,
                    password: _pdfPassword,
                    enableDoubleTapZooming: true,
                    canShowScrollHead: false,
                  ),
                ),
              ),
              // THE SCRUBBER TRACK
              Positioned(
                right: 4,
                top: 20,
                bottom: 20,
                child: AnimatedOpacity(
                  opacity: _showScrubber ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onVerticalDragStart: _onScrubberDragStart,
                    onVerticalDragUpdate: (d) => _onScrubberDragUpdate(d, scrubHeight),
                    onVerticalDragEnd: _onScrubberDragEnd,
                    child: Container(
                      width: 32,
                      color: Colors.transparent,
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: pdfForeground.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_showScrubber && _totalPages > 0)
                Positioned(
                  right: 8,
                  top: 20 + thumbY.clamp(0.0, scrubHeight),
                  child: GestureDetector(
                    onVerticalDragStart: _onScrubberDragStart,
                    onVerticalDragUpdate: (details) {
                      if (_totalPdfHeight <= 0) return;
                      // Move based on delta to allow grabbing the bubble itself
                      final deltaRatio = details.delta.dy / scrubHeight;
                      final newScrollY = (_currentScrollY + deltaRatio * (_totalPdfHeight - _viewportHeight))
                          .clamp(0.0, _totalPdfHeight - _viewportHeight);
                      
                      _pdfViewerController.jumpTo(yOffset: newScrollY);
                      setState(() {
                        _currentScrollY = newScrollY;
                      });
                      _showScrubberTemporarily();
                    },
                    onVerticalDragEnd: _onScrubberDragEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // THE BUBBLE
                      AnimatedOpacity(
                        opacity: (_showScrubber || _isDraggingScrubber) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: _PageBubble(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          backgroundColor: context.panelBackground,
                          textColor: pdfForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // THE THUMB
                      Container(
                        width: 6,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 12),
                    _ZoomActionButton(
                      icon: Icons.add_rounded,
                      onTap: () => _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0),
                    ),
                    const SizedBox(height: 10),
                    _ZoomActionButton(
                      icon: Icons.remove_rounded,
                      onTap: () => _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

      if (_pdfNeedsPassword) {
        return _buildPasswordPrompt(context);
      }

      if (_pdfOpenError != null) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GlassCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Preview unavailable',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  _pdfOpenError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: context.secondaryText),
                ),
              ],
            ),
          ),
        );
      }

    if (widget.file.isText) {
      return FutureBuilder<String>(
        future: _textContentFuture.then((value) => value ?? ''),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox.expand(
              child: _HighlightedDocumentText(
                text: snapshot.data ?? '',
                query: _searchQuery,
                currentMatchIndex: _currentMatchIndex,
                forceDarkText: true,
              ),
            ),
          );
        },
      );
    }

    if (widget.file.isImage) {
      return Center(
        child: SizedBox(
          width: double.infinity,
          child: Image.file(File(widget.file.path), fit: BoxFit.contain),
        ),
      );
    }

    if (_isPreviewableOfficeFile(_currentFile)) {
      if (_currentFile.extension.toLowerCase() == 'xlsx') {
        return FutureBuilder<SpreadsheetPreviewData?>(
          future: _spreadsheetPreviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _OfficePreviewError(message: snapshot.error.toString());
            }
            final preview = snapshot.data;
            if (preview == null) {
              return const _OfficePreviewError(
                message: 'No readable data found in this Excel file.',
              );
            }
            return _SpreadsheetPreview(
              key: ValueKey('spreadsheet_${_currentFile.path}'),
              data: preview,
              searchQuery: _searchQuery,
              currentMatchIndex: _currentMatchIndex,
              matches: _searchMatches,
            );
          },
        );
      }

      if (_currentFile.extension.toLowerCase() == 'pptx' && _searchQuery.isEmpty) {
        return FutureBuilder<PresentationPreviewData?>(
          future: _presentationPreviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _OfficePreviewError(message: snapshot.error.toString());
            }
            final preview = snapshot.data;
            if (preview == null) {
              return const _OfficePreviewError(
                message: 'No readable text found in this PowerPoint file.',
              );
            }
            return _PresentationPreview(
              data: preview,
              searchQuery: _searchQuery,
            );
          },
        );
      }

      return FutureBuilder<String?>(
        future: _officeContentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _OfficePreviewError(
              message: snapshot.error.toString(),
            );
          }

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox.expand(
              child: _HighlightedDocumentText(
                text: snapshot.data ?? '',
                query: _searchQuery,
                currentMatchIndex: _currentMatchIndex,
                forceDarkText: true,
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Preview unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Office documents are supported for file management in-app and can be opened with an installed viewer.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.secondaryText),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _preparePdf([String? password]) async {
    if (!_currentFile.isPdf || !_fileExists) {
      return;
    }
    setState(() {
      _isPreparingPdf = true;
      _pdfOpenError = null;
      _pdfNeedsPassword = false;
      _pdfPassword = password;
    });
    // Syncfusion SfPdfViewer.file handles the actual loading 
    // when password or path changes.
  }


  Future<void> _requestPdfPassword({bool showInvalidMessage = false}) async {
    if (_isPasswordPromptOpen || !mounted) {
      return;
    }
    _isPasswordPromptOpen = true;
    try {
      final password = await _promptForPdfPassword(
        context,
        invalid: showInvalidMessage,
      );
      if (!mounted || password == null || password.isEmpty) {
        return;
      }
      await _preparePdf(password);
    } finally {
      _isPasswordPromptOpen = false;
    }
  }

  Widget _buildPasswordPrompt(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Password required',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'This PDF is protected. Enter the password to preview it.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.secondaryText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _requestPdfPassword(),
              child: const Text('Enter password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleViewerAction(
    BuildContext context,
    _ViewerAction action,
  ) async {
    final controller = context.read<AppController>();
    switch (action) {
      case _ViewerAction.openExternally:
        await controller.openExternally(_currentFile.path);
        return;
      case _ViewerAction.favorite:
        await controller.toggleFavorite(_currentFile);
        if (!mounted) {
          return;
        }
        setState(() {
          _currentFile = _currentFile.copyWith(isFavorite: !_currentFile.isFavorite);
        });
        return;
      case _ViewerAction.rename:
        final nextName = await _promptForFileName(
          context,
          _currentFile.name,
        );
        if (!mounted || nextName == null || nextName == _currentFile.name) {
          return;
        }
        final renamed = await controller.renameFile(_currentFile, nextName);
        if (!mounted || renamed == null) {
          return;
        }
        setState(() {
          _currentFile = renamed;
        });
        return;
      case _ViewerAction.download:
        final savedPath = await controller.fileService.saveToPdfStudioFolder(
          _currentFile.path,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Saved to $savedPath')),
        );
        return;
      case _ViewerAction.delete:
        final shouldDelete = await _confirmDelete(context);
        if (!shouldDelete) {
          return;
        }
        await controller.deleteManagedFile(_currentFile);
        if (!mounted) {
          return;
        }
        Navigator.of(this.context).pop();
        return;
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    if (!_fileExists) {
      return;
    }
    await Share.shareXFiles(
      <XFile>[XFile(_currentFile.path)],
      subject: _currentFile.name,
      text: 'Shared from PDF Studio',
    );
  }

  void _openFindMode() {
    setState(() {
      _isFindMode = true;
      _searchQuery = '';
      _searchMatches = const <_DocumentSearchMatch>[];
      _currentMatchIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _findFocusNode.requestFocus();
      }
    });
  }

  void _closeFindMode() {
    _findFocusNode.unfocus();
    setState(() {
      _isFindMode = false;
      _isSearching = false;
      _searchQuery = '';
      _searchMatches = const <_DocumentSearchMatch>[];
      _currentMatchIndex = 0;
      _findController.clear();
    });
  }

  void _clearFindQuery() {
    _findController.clear();
    _findFocusNode.requestFocus();
    setState(() {
      _searchQuery = '';
      _searchMatches = const <_DocumentSearchMatch>[];
      _currentMatchIndex = 0;
      _isSearching = false;
    });
  }

  Future<void> _onFindQueryChanged(String value) async {
    final query = value.trim();
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _searchMatches = const <_DocumentSearchMatch>[];
        _currentMatchIndex = 0;
      }
    });

    if (query.isEmpty) {
      return;
    }

    final results = await _searchContent(query);
    if (!mounted || _searchQuery != query) {
      return;
    }
    setState(() {
      _isSearching = false;
      _searchMatches = results;
      _currentMatchIndex = 0;
    });
    if (_searchMatches.isNotEmpty) {
      await _openMatch(_searchMatches.first);
    }
  }

  Future<List<_DocumentSearchMatch>> _searchContent(String query) async {
    final lowercaseQuery = query.toLowerCase();
    if (_currentFile.isText) {
      final text = await File(_currentFile.path).readAsString();
      return _collectMatches(text, lowercaseQuery, 1);
    } else if (_currentFile.extension.toLowerCase() == 'xlsx') {
      final preview = await _spreadsheetPreviewFuture;
      if (preview == null) return const <_DocumentSearchMatch>[];
      
      final matches = <_DocumentSearchMatch>[];
      for (int s = 0; s < preview.sheets.length; s++) {
        final sheet = preview.sheets[s];
        for (int r = 0; r < sheet.rows.length; r++) {
          for (int c = 0; c < sheet.rows[r].length; c++) {
            final cellText = sheet.rows[r][c];
            if (cellText.toLowerCase().contains(lowercaseQuery)) {
              matches.add(
                _DocumentSearchMatch(
                  pageNumber: 1,
                  snippet: cellText,
                  excelSheetIndex: s,
                  excelRowIndex: r,
                  excelColIndex: c,
                ),
              );
            }
          }
        }
      }
      return matches;
    } else if (_currentFile.extension.toLowerCase() == 'pptx') {
      final preview = await _presentationPreviewFuture;
      if (preview == null) return const <_DocumentSearchMatch>[];
      
      final matches = <_DocumentSearchMatch>[];
      for (int i = 0; i < preview.slides.length; i++) {
        final slide = preview.slides[i];
        final content = '${slide.title} ${slide.bullets.join(' ')}';
        if (content.toLowerCase().contains(lowercaseQuery)) {
          matches.add(
            _DocumentSearchMatch(
              pageNumber: i + 1, // Store slide number
              snippet: slide.title.isNotEmpty ? slide.title : slide.bullets.firstOrNull ?? '',
            ),
          );
        }
      }
      return matches;
    } else if (_isPreviewableOfficeFile(_currentFile)) {
      final text = await _officeContentFuture ?? '';
      return _collectMatches(text, lowercaseQuery, 1);
    } else if (_currentFile.isPdf) {
      final document = sfpdf.PdfDocument(
        inputBytes: await File(_currentFile.path).readAsBytes(),
      );
      final extractor = sfpdf.PdfTextExtractor(document);
      final matches = <_DocumentSearchMatch>[];
      for (var page = 0; page < document.pages.count; page++) {
        final pageText = extractor.extractText(startPageIndex: page, endPageIndex: page);
        matches.addAll(_collectMatches(pageText, lowercaseQuery, page + 1));
      }
      document.dispose();
      return matches;
    } else {
      return const <_DocumentSearchMatch>[];
    }
  }

  List<_DocumentSearchMatch> _collectMatches(
    String text,
    String lowercaseQuery,
    int pageNumber,
  ) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = collapsed.toLowerCase();
    final matches = <_DocumentSearchMatch>[];
    var start = 0;
    while (matches.length < 100) {
      final index = lower.indexOf(lowercaseQuery, start);
      if (index == -1) {
        break;
      }
      final snippetStart = (index - 35).clamp(0, collapsed.length);
      final snippetEnd = (index + lowercaseQuery.length + 55).clamp(
        0,
        collapsed.length,
      );
      matches.add(
        _DocumentSearchMatch(
          pageNumber: pageNumber,
          snippet: collapsed.substring(snippetStart, snippetEnd).trim(),
        ),
      );
      start = index + lowercaseQuery.length;
    }
    return matches;
  }

  Future<String?> _promptForFileName(
    BuildContext context,
    String initialName,
  ) async {
    final controller = TextEditingController(text: initialName);
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename file'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter file name'),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<String?> _promptForPdfPassword(
    BuildContext context, {
    bool invalid = false,
  }) async {
    final controller = TextEditingController(text: _pdfPassword ?? '');
    var obscure = true;
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Open protected PDF'),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  errorText: invalid ? 'Incorrect password' : null,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: const Text('Open'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete file?'),
          content: Text('Are you sure you want to delete "${_currentFile.name}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return shouldDelete ?? false;
  }

  Widget _buildNoSearchResults(BuildContext context, bool usePdfChrome) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: usePdfChrome
              ? const Color(0xFF141414).withValues(alpha: 0.94)
              : context.panelBackground.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: usePdfChrome
                ? Colors.white.withValues(alpha: 0.08)
                : context.borderColor,
          ),
        ),
        child: Text(
          'No search result',
          style: TextStyle(
            color: usePdfChrome ? Colors.white70 : context.secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool get _canGoToPreviousMatch => _searchMatches.length > 1;

  bool get _canGoToNextMatch => _searchMatches.length > 1;

  Future<void> _goToPreviousMatch() async {
    if (_searchMatches.isEmpty) {
      return;
    }
    final nextIndex =
        (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    setState(() {
      _currentMatchIndex = nextIndex;
    });
    await _openMatch(_searchMatches[nextIndex]);
  }

  Future<void> _goToNextMatch() async {
    if (_searchMatches.isEmpty) {
      return;
    }
    final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    setState(() {
      _currentMatchIndex = nextIndex;
    });
    await _openMatch(_searchMatches[nextIndex]);
  }

  Future<void> _openMatch(_DocumentSearchMatch match) async {
    if (_currentFile.isPdf) {
      _pdfViewerController.jumpToPage(match.pageNumber);
    }
  }

  bool _isPreviewableOfficeFile(AppFile file) {
    return <String>{
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    }.contains(file.extension.toLowerCase());
  }
}

enum _ViewerAction { openExternally, favorite, rename, download, delete }

class _ZoomActionButton extends StatelessWidget {
  const _ZoomActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final radius = BorderRadius.circular(14);
    return Material(
      color: isDark
          ? Colors.black.withValues(alpha: 0.58)
          : Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: isDark
            ? BorderSide.none
            : BorderSide(color: context.borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: isDark ? Colors.white : context.primaryText),
        ),
      ),
    );
  }
}

class _FindBar extends StatelessWidget {
  const _FindBar({
    required this.controller,
    required this.focusNode,
    required this.hintColor,
    required this.textColor,
    required this.surfaceColor,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color hintColor;
  final Color textColor;
  final Color surfaceColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Find in document',
          hintStyle: TextStyle(
            color: hintColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: hintColor, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: hintColor, size: 20),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _FindCountLabel extends StatelessWidget {
  const _FindCountLabel({
    required this.isSearching,
    required this.query,
    required this.total,
    required this.currentIndex,
    required this.usePdfChrome,
  });

  final bool isSearching;
  final String query;
  final int total;
  final int currentIndex;
  final bool usePdfChrome;

  @override
  Widget build(BuildContext context) {
    final color = usePdfChrome ? Colors.white : context.primaryText;
    final muted = usePdfChrome ? Colors.white70 : context.secondaryText;

    if (isSearching) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(muted),
        ),
      );
    }

    if (query.isEmpty) {
      return Text(
        '0',
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (total == 0) {
      return Text(
        '0',
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Text(
      '${currentIndex + 1}/$total',
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DocumentSearchMatch {
  const _DocumentSearchMatch({
    required this.pageNumber,
    required this.snippet,
    this.excelSheetIndex,
    this.excelRowIndex,
    this.excelColIndex,
  });

  final int pageNumber;
  final String snippet;
  final int? excelSheetIndex;
  final int? excelRowIndex;
  final int? excelColIndex;
}

class _HighlightedDocumentText extends StatelessWidget {
  const _HighlightedDocumentText({
    required this.text,
    required this.query,
    required this.currentMatchIndex,
    required this.forceDarkText,
  });

  final String text;
  final String query;
  final int currentMatchIndex;
  final bool forceDarkText;

  @override
  Widget build(BuildContext context) {
    final textColor = forceDarkText ? const Color(0xFF111827) : context.primaryText;
    if (query.trim().isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          height: 1.6,
        ),
      );
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    var matchIndex = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        );
      }

      final isCurrent = matchIndex == currentMatchIndex;
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            color: Colors.black,
            fontSize: 15,
            height: 1.6,
            fontWeight: FontWeight.w700,
            backgroundColor: isCurrent
                ? const Color(0xFFFFD54F)
                : const Color(0xFFFFF176),
          ),
        ),
      );

      start = index + query.length;
      matchIndex++;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}

class _OfficePreviewError extends StatelessWidget {
  const _OfficePreviewError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Preview unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              message.replaceFirst('Exception: ', ''),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpreadsheetPreview extends StatefulWidget {
  const _SpreadsheetPreview({
    super.key,
    required this.data,
    this.searchQuery = '',
    this.currentMatchIndex = 0,
    this.matches = const [],
  });

  final SpreadsheetPreviewData data;
  final String searchQuery;
  final int currentMatchIndex;
  final List<_DocumentSearchMatch> matches;

  @override
  State<_SpreadsheetPreview> createState() => _SpreadsheetPreviewState();
}

class _SpreadsheetPreviewState extends State<_SpreadsheetPreview> with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _activeMatchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.data.sheets.length, vsync: this);
    _checkInitialMatch();
  }

  void _checkInitialMatch() {
    if (widget.currentMatchIndex >= 0 && widget.currentMatchIndex < widget.matches.length) {
      final match = widget.matches[widget.currentMatchIndex];
      if (match.excelSheetIndex != null && match.excelSheetIndex! < _tabController.length) {
        _tabController.index = match.excelSheetIndex!;
      }
    }
  }

  @override
  void didUpdateWidget(_SpreadsheetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.sheets.length != widget.data.sheets.length) {
      _tabController.dispose();
      _tabController = TabController(length: widget.data.sheets.length, vsync: this);
    }

    if (oldWidget.currentMatchIndex != widget.currentMatchIndex &&
        widget.currentMatchIndex >= 0 &&
        widget.currentMatchIndex < widget.matches.length) {
      final match = widget.matches[widget.currentMatchIndex];
      if (match.excelSheetIndex != null && match.excelSheetIndex! < _tabController.length) {
        _tabController.animateTo(match.excelSheetIndex!);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.sheets.isEmpty) {
      return const _OfficePreviewError(message: 'No sheets found in this file.');
    }

    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: widget.data.sheets.asMap().entries.map((entry) {
              return _SpreadsheetGrid(
                sheet: entry.value,
                sheetIndex: entry.key,
                searchQuery: widget.searchQuery,
                currentMatchIndex: widget.currentMatchIndex,
                matches: widget.matches,
                activeMatchKey: _activeMatchKey,
              );
            }).toList(),
          ),
        ),
        // SHEET TABS AT BOTTOM
        Container(
          decoration: BoxDecoration(
            color: context.isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: SafeArea(
            top: false,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF16A34A),
              labelColor: const Color(0xFF16A34A),
              unselectedLabelColor: context.secondaryText,
              indicatorWeight: 3,
              tabs: widget.data.sheets.map((sheet) => Tab(text: sheet.name)).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpreadsheetGrid extends StatelessWidget {
  const _SpreadsheetGrid({
    required this.sheet,
    required this.sheetIndex,
    this.searchQuery = '',
    this.currentMatchIndex = 0,
    this.matches = const [],
    required this.activeMatchKey,
  });

  final SpreadsheetSheetData sheet;
  final int sheetIndex;
  final String searchQuery;
  final int currentMatchIndex;
  final List<_DocumentSearchMatch> matches;
  final GlobalKey activeMatchKey;

  String _getColumnLabel(int index) {
    String label = '';
    int n = index + 1;
    while (n > 0) {
      int m = (n - 1) % 26;
      label = String.fromCharCode(65 + m) + label;
      n = (n - m) ~/ 26;
    }
    return label;
  }

  Widget _buildCellValue(String text, int r, int c, BuildContext context) {
    if (searchQuery.trim().isEmpty || !text.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Check if this cell is the CURRENT match
    bool isCurrentMatch = false;
    if (currentMatchIndex >= 0 && currentMatchIndex < matches.length) {
      final m = matches[currentMatchIndex];
      if (m.excelSheetIndex == sheetIndex && m.excelRowIndex == r && m.excelColIndex == c) {
        isCurrentMatch = true;
      }
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + searchQuery.length),
          style: TextStyle(
            backgroundColor: isCurrentMatch ? const Color(0xFFF97316) : const Color(0xFFFACC15),
            color: isCurrentMatch ? Colors.white : Colors.black,
            fontWeight: isCurrentMatch ? FontWeight.w800 : FontWeight.bold,
          ),
        ),
      );
      start = index + searchQuery.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 13,
        ),
        children: spans,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int rowCount = sheet.rows.length;
    final int colCount = rowCount > 0 ? sheet.rows[0].length : 0;
    
    final headerBg = const Color(0xFFF3F4F6);
    final borderColor = const Color(0xFFE5E7EB);
    final cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return InteractiveViewer(
      alignment: Alignment.topLeft,
      constrained: false,
      boundaryMargin: EdgeInsets.zero,
      minScale: 0.5,
      maxScale: 2.5,
      child: Container(
        color: Colors.white,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: borderColor, width: 0.5),
          children: [
            // COLUMN HEADERS (A, B, C...)
            TableRow(
              children: [
                // Corner cell (empty)
                Container(
                  color: headerBg,
                  width: 40,
                  height: 32,
                  child: const Center(child: Text('', style: TextStyle(fontSize: 10))),
                ),
                for (int i = 0; i < colCount; i++)
                  Container(
                    color: headerBg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    constraints: const BoxConstraints(minWidth: 80),
                    child: Center(
                      child: Text(
                        _getColumnLabel(i),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // DATA ROWS
            for (int r = 0; r < rowCount; r++)
              TableRow(
                children: [
                  // ROW NUMBER (1, 2, 3...)
                  Builder(
                    builder: (context) {
                      final bool isMatchRow = currentMatchIndex >= 0 &&
                          currentMatchIndex < matches.length &&
                          matches[currentMatchIndex].excelSheetIndex == sheetIndex &&
                          matches[currentMatchIndex].excelRowIndex == r;

                      if (isMatchRow) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (activeMatchKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              activeMatchKey.currentContext!,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: 0.5,
                            );
                          }
                        });
                      }

                      return Container(
                        key: isMatchRow ? activeMatchKey : null,
                        color: headerBg,
                        width: 40,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            '${r + 1}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // CELLS
                  for (int c = 0; c < colCount; c++)
                    Container(
                      padding: cellPadding,
                      constraints: const BoxConstraints(minWidth: 80),
                      child: _buildCellValue(sheet.rows[r][c], r, c, context),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PresentationPreview extends StatelessWidget {
  const _PresentationPreview({
    required this.data,
    this.searchQuery = '',
  });

  final PresentationPreviewData data;
  final String searchQuery;

  Widget _buildSlideText(String text, bool isTitle, BuildContext context) {
    if (searchQuery.trim().isEmpty || !text.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Text(
        text,
        style: TextStyle(
          color: isTitle ? const Color(0xFF111827) : const Color(0xFF4B5563),
          fontSize: isTitle ? 20 : 14,
          fontWeight: isTitle ? FontWeight.w800 : FontWeight.w500,
          height: 1.2,
        ),
      );
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + searchQuery.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFFACC15), // Yellow highlight
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + searchQuery.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: isTitle ? const Color(0xFF111827) : const Color(0xFF4B5563),
          fontSize: isTitle ? 20 : 14,
          fontWeight: isTitle ? FontWeight.w800 : FontWeight.w500,
          height: 1.2,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = context.isDarkMode ? const Color(0xFF111827) : const Color(0xFFF3F4F6);

    return Container(
      color: bgColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        itemCount: data.slides.length,
        separatorBuilder: (context, index) => const SizedBox(height: 24),
        itemBuilder: (context, index) => _buildSlide(context, index),
      ),
    );
  }

  Widget _buildSlide(BuildContext context, int index) {
    final slide = data.slides[index];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Slide Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildSlideText(slide.title, true, context),
                      if (slide.bullets.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          children: slide.bullets.map(
                            (bullet) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSlideText(bullet, false, context),
                                  ),
                                ],
                              ),
                            ),
                          ).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Slide Number
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageBubble extends StatelessWidget {
  const _PageBubble({
    required this.currentPage,
    required this.totalPages,
    required this.backgroundColor,
    required this.textColor,
  });

  final int currentPage;
  final int totalPages;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Page $currentPage of $totalPages',
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
