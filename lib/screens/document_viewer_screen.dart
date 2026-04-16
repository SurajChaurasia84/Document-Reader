import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
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
  PdfControllerPinch? _pdfController;
  late AppFile _currentFile = widget.file;
  late final AppController _appController;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  double _zoomScale = 1;
  bool _isFindMode = false;
  bool _isSearching = false;
  String _searchQuery = '';
  List<_DocumentSearchMatch> _searchMatches = const <_DocumentSearchMatch>[];
  int _currentMatchIndex = 0;
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
    _pdfController?.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
    super.dispose();
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
    final usePdfChrome = _currentFile.isPdf && _fileExists;
    final isPaperLike = _isPaperLikeFile;
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
      if (_isPreparingPdf) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_pdfController != null) {
        final pdfController = _pdfController!;
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(
              color: pdfBackground,
              child: PdfViewPinch(
                controller: pdfController,
                backgroundDecoration: BoxDecoration(color: pdfBackground),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? Colors.black.withValues(alpha: 0.58)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: context.isDarkMode
                        ? null
                        : Border.all(color: context.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: PdfPageNumber(
                      controller: pdfController,
                      builder: (context, loadingState, page, pagesCount) {
                        final total = pagesCount ?? 0;
                        return Text(
                          '$page / $total',
                          style: TextStyle(
                            color: pdfForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ZoomActionButton(
                  icon: Icons.add_rounded,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 10),
                _ZoomActionButton(
                  icon: Icons.remove_rounded,
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),
        ],
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
      if (_currentFile.extension.toLowerCase() == 'xlsx' && _searchQuery.isEmpty) {
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
            return _SpreadsheetPreview(data: preview);
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
            return _PresentationPreview(data: preview);
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

  void _zoomIn() {
    _setZoom((_zoomScale + 0.25).clamp(1.0, 4.0));
  }

  void _zoomOut() {
    _setZoom((_zoomScale - 0.25).clamp(1.0, 4.0));
  }

  void _setZoom(double nextScale) {
    if (_pdfController == null) {
      return;
    }
    setState(() {
      _zoomScale = nextScale;
      _pdfController!.value = Matrix4.diagonal3Values(
        _zoomScale,
        _zoomScale,
        1,
      );
    });
  }

  Future<void> _preparePdf([String? password]) async {
    if (!_currentFile.isPdf || !_fileExists) {
      return;
    }
    setState(() {
      _isPreparingPdf = true;
      _pdfOpenError = null;
      _pdfNeedsPassword = false;
    });

    try {
      final bytes = await File(_currentFile.path).readAsBytes();
      final validator = sfpdf.PdfDocument(
        inputBytes: bytes,
        password: password,
      );
      validator.dispose();

      _pdfController?.dispose();
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(
          _currentFile.path,
          password: password,
        ),
      );
      _pdfPassword = password;
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingPdf = false;
      });
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      final passwordIssue = _looksLikePasswordError(message);
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingPdf = false;
        _pdfController?.dispose();
        _pdfController = null;
        _pdfNeedsPassword = passwordIssue;
        _pdfOpenError = passwordIssue ? null : message;
      });
    }
  }

  bool _looksLikePasswordError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('password') ||
        lower.contains('encrypted') ||
        lower.contains('cannot open an encrypted document');
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
        if (nextName == null) {
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
    return result?.trim().isEmpty ?? true ? null : result!.trim();
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
    if (_currentFile.isPdf && _pdfController != null) {
      await _pdfController!.animateToPage(
        pageNumber: match.pageNumber,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
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
  });

  final int pageNumber;
  final String snippet;
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

class _SpreadsheetPreview extends StatelessWidget {
  const _SpreadsheetPreview({
    required this.data,
  });

  final SpreadsheetPreviewData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      itemCount: data.sheets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final sheet = data.sheets[index];
        final visibleRows = sheet.rows;
        final columnCount = visibleRows.fold<int>(
          0,
          (max, row) => row.length > max ? row.length : max,
        );
        final normalizedRows = visibleRows
            .map(
              (row) => List<String>.generate(
                columnCount,
                (columnIndex) => columnIndex < row.length ? row[columnIndex] : '',
              ),
            )
            .toList();
        final header = normalizedRows.first;
        final rows = normalizedRows.skip(1).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sheet.name,
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: <TableRow>[
                    TableRow(
                      decoration: BoxDecoration(
                        color: context.softPanel,
                      ),
                      children: header
                          .map(
                            (cell) => Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                cell,
                                style: TextStyle(
                                  color: context.primaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...rows.map(
                      (row) => TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: context.borderColor),
                          ),
                        ),
                        children: row
                            .map(
                              (cell) => Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  cell,
                                  style: TextStyle(
                                    color: context.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresentationPreview extends StatelessWidget {
  const _PresentationPreview({
    required this.data,
  });

  final PresentationPreviewData data;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      itemCount: data.slides.length,
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final slide = data.slides[index];
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                context.toolbarBlueStart.withValues(alpha: 0.35),
                context.toolbarBlueEnd.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Slide ${index + 1}',
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  slide.title,
                  style: TextStyle(
                    color: context.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (slide.bullets.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  ...slide.bullets.take(6).map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB020),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: TextStyle(
                                color: context.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
