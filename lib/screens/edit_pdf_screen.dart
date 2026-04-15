import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/app_file.dart';
import '../services/app_controller.dart';
import '../services/pdf_service.dart';
import '../utils/formatters.dart';
import '../utils/instant_page_route.dart';
import '../utils/theme_utils.dart';
import 'document_viewer_screen.dart';

class EditPdfScreen extends StatefulWidget {
  const EditPdfScreen({
    super.key,
    required this.inputPath,
  });

  final String inputPath;

  @override
  State<EditPdfScreen> createState() => _EditPdfScreenState();
}

enum _EditTool { view, draw, text }

class _EditPdfScreenState extends State<EditPdfScreen> {
  final ScrollController _scrollController = ScrollController();
  static const List<Color> _presetColors = <Color>[
    Color(0xFF18181B),
    Color(0xFFE11D48),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
  ];
  bool _isSaving = false;
  int _pageCount = 1;
  int _selectedPage = 1;
  _EditTool _selectedTool = _EditTool.view;
  Color _selectedDrawColor = const Color(0xFF18181B);
  List<List<Offset>> _activeStrokePaths = <List<Offset>>[];
  final Map<int, List<PdfEditStroke>> _strokeMap = <int, List<PdfEditStroke>>{};
  final Map<int, List<PdfEditTextItem>> _textMap = <int, List<PdfEditTextItem>>{};

  bool get _isEditingFocused => _selectedTool != _EditTool.view;

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final file = File(widget.inputPath);
    final name = p.basename(widget.inputPath);
    final size = file.existsSync() ? formatFileSize(file.lengthSync()) : '--';
    final strokes = _strokeMap[_selectedPage] ?? const <PdfEditStroke>[];
    final textItems = _textMap[_selectedPage] ?? const <PdfEditTextItem>[];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : () => _save(context, controller),
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: _isEditingFocused
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Preview your PDF and use the tools below to draw, add text, or erase edits.',
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Original size: $size',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _EditorChip(
                            label: 'Page',
                            value: '$_selectedPage / $_pageCount',
                            onTap: _pageCount < 2 ? null : _showPagePicker,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _EditorChip(
                            label: 'Mode',
                            value: _toolLabel(_selectedTool),
                            onTap: null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PdfEditorPreview(
                      inputPath: widget.inputPath,
                      pageNumber: _selectedPage,
                      strokes: strokes,
                      textItems: textItems,
                      isDrawMode: _selectedTool == _EditTool.draw,
                      liveStrokeColor: _selectedDrawColor,
                      onStartStroke: _handleStrokeStart,
                      onUpdateStroke: _handleStrokeUpdate,
                      onEndStroke: _handleStrokeEnd,
                      onTapForText: _selectedTool == _EditTool.text
                          ? _handleTextPlacement
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isEditingFocused
                          ? 'Editing is active. PDF scroll is paused until you tap Done.'
                          : 'Tap Draw or Text below to start editing. In view mode, normal scroll stays on.',
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'File: $name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_selectedTool == _EditTool.draw) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        'Draw color',
                        style: TextStyle(
                          color: context.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          ..._presetColors.map(
                            (color) => _ColorSwatchButton(
                              color: color,
                              selected: color.toARGB32() ==
                                  _selectedDrawColor.toARGB32(),
                              onTap: () {
                                setState(() {
                                  _selectedDrawColor = color;
                                });
                              },
                            ),
                          ),
                          _ColorPickerButton(
                            selectedColor: _selectedDrawColor,
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (_) => _ManualColorPickerDialog(
                                  initialColor: _selectedDrawColor,
                                ),
                              );
                              if (color == null || !mounted) {
                                return;
                              }
                              setState(() {
                                _selectedDrawColor = color;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _EditorToolbar(
              selectedTool: _selectedTool,
              onSelectTool: (tool) {
                setState(() {
                  _selectedTool = tool;
                });
              },
              onErase: _eraseLastEdit,
              onDone: _selectedTool == _EditTool.view
                  ? null
                  : () {
                      setState(() {
                        _selectedTool = _EditTool.view;
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _toolLabel(_EditTool tool) {
    switch (tool) {
      case _EditTool.view:
        return 'View';
      case _EditTool.draw:
        return 'Draw';
      case _EditTool.text:
        return 'Text';
    }
  }

  Future<void> _loadPageCount() async {
    final controller = context.read<AppController>();
    final pageCount = await controller.pdfService.getPageCount(widget.inputPath);
    if (!mounted) {
      return;
    }
    setState(() {
      _pageCount = pageCount;
      _selectedPage = pageCount < _selectedPage ? pageCount : _selectedPage;
    });
  }

  Future<void> _showPagePicker() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: _pageCount,
          itemBuilder: (context, index) {
            final page = index + 1;
            return ListTile(
              title: Text('Page $page'),
              trailing: page == _selectedPage
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(context).pop(page),
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _selectedPage = result;
      _activeStrokePaths = <List<Offset>>[];
    });
  }

  void _handleStrokeStart(Offset point) {
    setState(() {
      _activeStrokePaths = <List<Offset>>[<Offset>[point]];
    });
  }

  void _handleStrokeUpdate(Offset point) {
    if (_activeStrokePaths.isEmpty) {
      return;
    }
    setState(() {
      _activeStrokePaths.last.add(point);
    });
  }

  void _handleStrokeEnd() {
    if (_activeStrokePaths.isEmpty || _activeStrokePaths.last.length < 2) {
      setState(() {
        _activeStrokePaths = <List<Offset>>[];
      });
      return;
    }
    final next = Map<int, List<PdfEditStroke>>.from(_strokeMap);
    final current = List<PdfEditStroke>.from(next[_selectedPage] ?? const <PdfEditStroke>[]);
    current.add(
      PdfEditStroke(
        points: List<Offset>.from(_activeStrokePaths.last),
        colorValue: _selectedDrawColor.toARGB32(),
      ),
    );
    next[_selectedPage] = current;
    setState(() {
      _strokeMap
        ..clear()
        ..addAll(next);
      _activeStrokePaths = <List<Offset>>[];
    });
  }

  Future<void> _handleTextPlacement(Offset point) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _AddTextDialog(),
    );
    if (text == null || text.trim().isEmpty || !mounted) {
      return;
    }
    final next = Map<int, List<PdfEditTextItem>>.from(_textMap);
    final current = List<PdfEditTextItem>.from(
      next[_selectedPage] ?? const <PdfEditTextItem>[],
    );
    current.add(
      PdfEditTextItem(
        text: text.trim(),
        normalizedOffset: point,
      ),
    );
    setState(() {
      _textMap
        ..clear()
        ..addAll(next..[_selectedPage] = current);
      _selectedTool = _EditTool.view;
    });
  }

  void _eraseLastEdit() {
    final currentTexts = List<PdfEditTextItem>.from(
      _textMap[_selectedPage] ?? const <PdfEditTextItem>[],
    );
    final currentStrokes = List<PdfEditStroke>.from(
      _strokeMap[_selectedPage] ?? const <PdfEditStroke>[],
    );

    if (currentTexts.isEmpty && currentStrokes.isEmpty) {
      return;
    }

    if (currentTexts.length >= currentStrokes.length && currentTexts.isNotEmpty) {
      currentTexts.removeLast();
      _textMap[_selectedPage] = currentTexts;
    } else if (currentStrokes.isNotEmpty) {
      currentStrokes.removeLast();
      _strokeMap[_selectedPage] = currentStrokes;
    }

    setState(() {});
  }

  Future<void> _save(
    BuildContext context,
    AppController controller,
  ) async {
    final edits = <int, PdfPageEditBundle>{};
    final pages = <int>{..._strokeMap.keys, ..._textMap.keys};
    for (final page in pages) {
      final strokes = _strokeMap[page] ?? const <PdfEditStroke>[];
      final textItems = _textMap[page] ?? const <PdfEditTextItem>[];
      if (strokes.isEmpty && textItems.isEmpty) {
        continue;
      }
      edits[page] = PdfPageEditBundle(
        strokes: strokes,
        textItems: textItems,
      );
    }

    if (edits.isEmpty) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Add a drawing or text before saving.')),
      );
      return;
    }

    final outputName = await _promptForOutputName(
      context,
      _suggestedOutputName(),
    );
    if (outputName == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    final output = await controller.editPdfPath(
      widget.inputPath,
      editsByPage: edits,
      outputFileName: outputName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    if (output == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(controller.statusMessage ?? 'Editing failed')),
      );
      return;
    }

    final outputFile = File(output);
    final editedFile = AppFile(
      path: output,
      name: p.basename(output),
      extension: 'pdf',
      size: await outputFile.length(),
      modifiedAt: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(this.context).pushReplacement(
      InstantPageRoute<void>(
        builder: (_) => DocumentViewerScreen(file: editedFile),
      ),
    );
  }

  String _suggestedOutputName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'edited_$stamp';
  }

  Future<String?> _promptForOutputName(
    BuildContext context,
    String initialValue,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameEditedPdfDialog(initialValue: initialValue),
    );
  }
}

class _PdfEditorPreview extends StatelessWidget {
  const _PdfEditorPreview({
    required this.inputPath,
    required this.pageNumber,
    required this.strokes,
    required this.textItems,
    required this.isDrawMode,
    required this.liveStrokeColor,
    required this.onStartStroke,
    required this.onUpdateStroke,
    required this.onEndStroke,
    required this.onTapForText,
  });

  final String inputPath;
  final int pageNumber;
  final List<PdfEditStroke> strokes;
  final List<PdfEditTextItem> textItems;
  final bool isDrawMode;
  final Color liveStrokeColor;
  final ValueChanged<Offset> onStartStroke;
  final ValueChanged<Offset> onUpdateStroke;
  final VoidCallback onEndStroke;
  final ValueChanged<Offset>? onTapForText;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.panelBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: FutureBuilder<Uint8List?>(
        future: controller.pdfService.renderPageAsImage(inputPath, pageNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return SizedBox(
              height: 420,
              child: Center(
                child: Text(
                  'Unable to preview this page.',
                  style: TextStyle(color: context.secondaryText),
                ),
              ),
            );
          }

          return _EditorCanvas(
            bytes: bytes,
            strokes: strokes,
            textItems: textItems,
            isDrawMode: isDrawMode,
            liveStrokeColor: liveStrokeColor,
            onStartStroke: onStartStroke,
            onUpdateStroke: onUpdateStroke,
            onEndStroke: onEndStroke,
            onTapForText: onTapForText,
          );
        },
      ),
    );
  }
}

class _EditorCanvas extends StatefulWidget {
  const _EditorCanvas({
    required this.bytes,
    required this.strokes,
    required this.textItems,
    required this.isDrawMode,
    required this.liveStrokeColor,
    required this.onStartStroke,
    required this.onUpdateStroke,
    required this.onEndStroke,
    required this.onTapForText,
  });

  final Uint8List bytes;
  final List<PdfEditStroke> strokes;
  final List<PdfEditTextItem> textItems;
  final bool isDrawMode;
  final Color liveStrokeColor;
  final ValueChanged<Offset> onStartStroke;
  final ValueChanged<Offset> onUpdateStroke;
  final VoidCallback onEndStroke;
  final ValueChanged<Offset>? onTapForText;

  @override
  State<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<_EditorCanvas> {
  List<Offset> _liveStroke = <Offset>[];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: GestureDetector(
        onPanStart: widget.isDrawMode
            ? (details) => _withNormalizedPoint(
                  details.localPosition,
                  context.size,
                  (point) {
                    _liveStroke = <Offset>[point];
                    widget.onStartStroke(point);
                  },
                )
            : null,
        onPanUpdate: widget.isDrawMode
            ? (details) => _withNormalizedPoint(
                  details.localPosition,
                  context.size,
                  (point) {
                    _liveStroke.add(point);
                    widget.onUpdateStroke(point);
                    setState(() {});
                  },
                )
            : null,
        onPanEnd: widget.isDrawMode
            ? (_) {
                _liveStroke = <Offset>[];
                widget.onEndStroke();
                setState(() {});
              }
            : null,
        onTapUp: widget.onTapForText == null
            ? null
            : (details) => _withNormalizedPoint(
                  details.localPosition,
                  context.size,
                  widget.onTapForText!,
                ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: Colors.white,
                child: Image.memory(widget.bytes, fit: BoxFit.cover),
              ),
              CustomPaint(
                painter: _PdfEditPainter(
            strokes: widget.strokes,
            liveStroke: _liveStroke,
            liveStrokeColor: widget.liveStrokeColor,
            textItems: widget.textItems,
          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _withNormalizedPoint(
    Offset localPosition,
    Size? size,
    ValueChanged<Offset> onPoint,
  ) {
    if (size == null || size.width <= 0 || size.height <= 0) {
      return;
    }
    final dx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (localPosition.dy / size.height).clamp(0.0, 1.0);
    onPoint(Offset(dx, dy));
  }
}

class _PdfEditPainter extends CustomPainter {
  const _PdfEditPainter({
    required this.strokes,
    required this.liveStroke,
    required this.liveStrokeColor,
    required this.textItems,
  });

  final List<PdfEditStroke> strokes;
  final List<Offset> liveStroke;
  final Color liveStrokeColor;
  final List<PdfEditTextItem> textItems;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final strokePaint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final current = stroke.points[i];
        final next = stroke.points[i + 1];
        canvas.drawLine(
          Offset(current.dx * size.width, current.dy * size.height),
          Offset(next.dx * size.width, next.dy * size.height),
          strokePaint,
        );
      }
    }

    if (liveStroke.length > 1) {
      final livePaint = Paint()
        ..color = liveStrokeColor
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      for (var i = 0; i < liveStroke.length - 1; i++) {
        final current = liveStroke[i];
        final next = liveStroke[i + 1];
        canvas.drawLine(
          Offset(current.dx * size.width, current.dy * size.height),
          Offset(next.dx * size.width, next.dy * size.height),
          livePaint,
        );
      }
    }

    for (final item in textItems) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: Colors.black,
            fontSize: item.fontSize * 0.72,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: size.width * 0.56);
      painter.paint(
        canvas,
        Offset(
          item.normalizedOffset.dx * size.width,
          item.normalizedOffset.dy * size.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PdfEditPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.liveStroke != liveStroke ||
        oldDelegate.liveStrokeColor != liveStrokeColor ||
        oldDelegate.textItems != textItems;
  }
}

class _EditorChip extends StatelessWidget {
  const _EditorChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.selectedTool,
    required this.onSelectTool,
    required this.onErase,
    required this.onDone,
  });

  final _EditTool selectedTool;
  final ValueChanged<_EditTool> onSelectTool;
  final VoidCallback onErase;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: context.panelBackground,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _ToolbarButton(
                label: 'View',
                icon: Icons.pan_tool_alt_rounded,
                selected: selectedTool == _EditTool.view,
                onTap: () => onSelectTool(_EditTool.view),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToolbarButton(
                label: 'Draw',
                icon: Icons.brush_rounded,
                selected: selectedTool == _EditTool.draw,
                onTap: () => onSelectTool(_EditTool.draw),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToolbarButton(
                label: 'Text',
                icon: Icons.text_fields_rounded,
                selected: selectedTool == _EditTool.text,
                onTap: () => onSelectTool(_EditTool.text),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToolbarButton(
                label: 'Erase',
                icon: Icons.auto_fix_off_rounded,
                selected: false,
                onTap: onErase,
              ),
            ),
            if (onDone != null) ...<Widget>[
              const SizedBox(width: 10),
              Expanded(
                child: _ToolbarButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  selected: false,
                  onTap: onDone,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.12) : context.searchBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected ? primary : context.iconMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? primary : context.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withValues(alpha: 0.85),
            width: selected ? 3 : 1.4,
          ),
        ),
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  const _ColorPickerButton({
    required this.selectedColor,
    required this.onTap,
  });

  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: <Color>[
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.4),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: selectedColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualColorPickerDialog extends StatefulWidget {
  const _ManualColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ManualColorPickerDialog> createState() =>
      _ManualColorPickerDialogState();
}

class _ManualColorPickerDialogState extends State<_ManualColorPickerDialog> {
  late double _red = widget.initialColor.r * 255;
  late double _green = widget.initialColor.g * 255;
  late double _blue = widget.initialColor.b * 255;

  Color get _currentColor => Color.fromARGB(
        0xFF,
        _red.round(),
        _green.round(),
        _blue.round(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 14),
          _RgbSlider(
            label: 'R',
            value: _red,
            activeColor: Colors.red,
            onChanged: (value) => setState(() => _red = value),
          ),
          _RgbSlider(
            label: 'G',
            value: _green,
            activeColor: Colors.green,
            onChanged: (value) => setState(() => _green = value),
          ),
          _RgbSlider(
            label: 'B',
            value: _blue,
            activeColor: Colors.blue,
            onChanged: (value) => setState(() => _blue = value),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          child: const Text('Use'),
        ),
      ],
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: TextStyle(
              color: context.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _AddTextDialog extends StatefulWidget {
  const _AddTextDialog();

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add text'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Text',
          hintText: 'Type text to place on the PDF',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _RenameEditedPdfDialog extends StatefulWidget {
  const _RenameEditedPdfDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_RenameEditedPdfDialog> createState() => _RenameEditedPdfDialogState();
}

class _RenameEditedPdfDialogState extends State<_RenameEditedPdfDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename edited PDF'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'File name',
          hintText: 'Enter file name',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = _controller.text.trim();
            Navigator.of(context).pop(
              trimmed.isEmpty ? widget.initialValue : trimmed,
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
