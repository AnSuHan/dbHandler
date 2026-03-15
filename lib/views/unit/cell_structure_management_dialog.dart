// lib/views/unit/cell_structure_management_dialog.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../stateManagement/setState/cell_structure.dart';
import '../../stateManagement/setState/cell_structure_export.dart';
import '../../stateManagement/setState/cell_structure_global_store.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';

Future<void> showCellStructureManagementDialog({
  required BuildContext context,
  required DataEditingParams dataEditingParams,
  String? initialColumn,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => _CellStructureManagementDialog(
      dataEditingParams: dataEditingParams,
      initialColumn: initialColumn,
    ),
  );
}

// ── 상태 헬퍼 클래스 ────────────────────────────────────────────

class _LineEntry {
  TextEditingController prefixController;
  String columnName;
  bool isExpression;
  TextEditingController expressionController;

  _LineEntry({
    required this.prefixController,
    required this.columnName,
    this.isExpression = false,
    TextEditingController? expressionController,
  }) : expressionController = expressionController ?? TextEditingController();

  void dispose() {
    prefixController.dispose();
    expressionController.dispose();
  }
}

class _LineState {
  final TextEditingController prefixCtrl;
  String column;
  final bool matched;
  final String raw;
  _LineState({required this.prefixCtrl, required this.column, required this.matched, this.raw = ''});
}

class _MatchResult {
  final String prefix;
  final String column;
  final bool matched;
  final String raw;
  const _MatchResult({required this.prefix, required this.column, required this.matched, this.raw = ''});
}

class _GlobalExportResult {
  final CellStructureMetadata metadata;
  final List<GlobalCellStructureEntry> entries;
  _GlobalExportResult(this.metadata, this.entries);
}

// ── 다이얼로그 ──────────────────────────────────────────────────

class _CellStructureManagementDialog extends ConsumerStatefulWidget {
  final DataEditingParams dataEditingParams;
  final String? initialColumn;

  const _CellStructureManagementDialog({
    required this.dataEditingParams,
    this.initialColumn,
  });

  @override
  ConsumerState<_CellStructureManagementDialog> createState() =>
      _CellStructureManagementDialogState();
}

class _CellStructureManagementDialogState
    extends ConsumerState<_CellStructureManagementDialog>
    with SingleTickerProviderStateMixin {

  // ── 편집 모드 ─────────────────────────────────────────────────
  bool _isEditing = false;
  String? _editingColumn;   // null = 새 구조, non-null = 기존 구조 수정
  String? _editorMainColumn;

  late TabController _tabController;

  // 공통 편집 필드
  final _displayNameCtrl = TextEditingController();

  // 수동 편집기
  List<_LineEntry> _manualLines = [];

  // 문자열 편집기
  final _inputCtrl  = TextEditingController();
  final _outputCtrl = TextEditingController();
  List<_LineState> _stringLines = [];
  String? _stringMainColumn;
  String? _stringInferError;

  // ── 생명주기 ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialColumn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final structures = ref.read(
          dataEditingProvider(widget.dataEditingParams).select((s) => s.cellStructures),
        );
        _openEditor(widget.initialColumn!, existing: structures[widget.initialColumn!]);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameCtrl.dispose();
    _inputCtrl.dispose();
    _outputCtrl.dispose();
    _disposeManualLines();
    _disposeStringLines();
    super.dispose();
  }

  void _disposeManualLines() {
    for (final e in _manualLines) e.dispose();
  }

  void _disposeStringLines() {
    for (final l in _stringLines) l.prefixCtrl.dispose();
  }

  // ── 편집 열기/닫기 ────────────────────────────────────────────

  void _openEditor(String mainColumn, {CellStructure? existing}) {
    _disposeManualLines();
    _disposeStringLines();

    _manualLines = existing?.lines.map((l) => _LineEntry(
      prefixController: TextEditingController(text: l.prefix),
      columnName: l.isExpression ? '' : l.columnName,
      isExpression: l.isExpression,
      expressionController: TextEditingController(text: l.expression ?? ''),
    )).toList() ?? [
      _LineEntry(prefixController: TextEditingController(), columnName: mainColumn),
    ];

    _inputCtrl.clear();
    _outputCtrl.clear();
    _stringLines = [];
    _stringMainColumn = mainColumn;
    _stringInferError = null;

    setState(() {
      _isEditing = true;
      _editingColumn = existing != null ? mainColumn : null;
      _editorMainColumn = mainColumn;
      _displayNameCtrl.text = existing?.displayName ?? '';
      _tabController.index = 0;
    });
  }

  void _closeEditor() => setState(() { _isEditing = false; _editorMainColumn = null; });

  void _saveEditor(DataEditingNotifier notifier, List<String> availableColumns) {
    if (_editorMainColumn == null) return;
    final dn = _displayNameCtrl.text.trim();

    CellStructure structure;
    if (_tabController.index == 0) {
      // 수동
      structure = CellStructure(
        mainColumnName: _editorMainColumn!,
        lines: _manualLines.map((e) => e.isExpression
            ? CellStructureLine(
                prefix: e.prefixController.text,
                columnName: '',
                expression: e.expressionController.text.trim(),
              )
            : CellStructureLine(
                prefix: e.prefixController.text,
                columnName: e.columnName,
              )).toList(),
        displayName: dn.isEmpty ? null : dn,
      );
    } else {
      // 문자열
      if (_stringLines.isEmpty || _stringMainColumn == null) return;
      structure = CellStructure(
        mainColumnName: _stringMainColumn!,
        lines: _stringLines.map((l) => CellStructureLine(
          prefix: l.prefixCtrl.text,
          columnName: l.column,
        )).toList(),
        displayName: dn.isEmpty ? null : dn,
      );
    }

    notifier.setCellStructure(_editorMainColumn!, structure);
    // 구조가 설정되면 자동으로 표시 모드로 전환
    final isDisplayMode = ref.read(
      dataEditingProvider(widget.dataEditingParams).select((s) => s.isDisplayMode),
    );
    if (!isDisplayMode) notifier.toggleDisplayMode();
    _closeEditor();
  }

  // ── 문자열 추론 ───────────────────────────────────────────────

  Map<String, String> _parseInput(String text) {
    final map = <String, String>{};
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final eqIdx = line.indexOf('=');
      final clIdx = line.indexOf(':');
      int split = -1;
      if (eqIdx > 0 && (clIdx < 0 || eqIdx <= clIdx)) split = eqIdx;
      else if (clIdx > 0) split = clIdx;
      if (split < 0) continue;
      final key = line.substring(0, split).trim();
      final val = line.substring(split + 1).trim();
      if (key.isNotEmpty) map[key] = val;
    }
    return map;
  }

  _MatchResult _matchLine(String outputLine, Map<String, String> inputMap) {
    final sorted = inputMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final e in sorted) {
      if (e.value.isEmpty) continue;
      if (outputLine.endsWith(e.value)) {
        return _MatchResult(
          prefix: outputLine.substring(0, outputLine.length - e.value.length),
          column: e.key, matched: true, raw: outputLine,
        );
      }
    }
    for (final e in sorted) {
      if (e.value.isEmpty) continue;
      final idx = outputLine.indexOf(e.value);
      if (idx >= 0) {
        return _MatchResult(
          prefix: outputLine.substring(0, idx),
          column: e.key, matched: true, raw: outputLine,
        );
      }
    }
    return _MatchResult(prefix: '', column: '', matched: false, raw: outputLine);
  }

  void _runInfer(List<String> availableColumns) {
    final inputText  = _inputCtrl.text;
    final outputText = _outputCtrl.text;

    if (inputText.trim().isEmpty || outputText.trim().isEmpty) {
      setState(() { _disposeStringLines(); _stringLines = []; _stringInferError = null; });
      return;
    }
    final inputMap = _parseInput(inputText);
    if (inputMap.isEmpty) {
      setState(() { _disposeStringLines(); _stringLines = [];
        _stringInferError = '"컬럼 = 값" 또는 "컬럼: 값" 형식으로 입력하세요.'; });
      return;
    }
    final outputLines = outputText.split('\n').where((l) => l.isNotEmpty).toList();
    if (outputLines.isEmpty) {
      setState(() { _disposeStringLines(); _stringLines = []; _stringInferError = null; });
      return;
    }

    final newLines = outputLines.map((l) {
      final m = _matchLine(l, inputMap);
      return _LineState(prefixCtrl: TextEditingController(text: m.prefix),
          column: m.column, matched: m.matched, raw: m.raw);
    }).toList();

    if (_stringMainColumn == null || !availableColumns.contains(_stringMainColumn)) {
      final first = newLines.firstWhere(
        (l) => l.matched && availableColumns.contains(l.column),
        orElse: () => newLines.first,
      );
      _stringMainColumn = first.column.isNotEmpty ? first.column : null;
    }

    final unmatched = newLines.where((l) => !l.matched).length;
    setState(() {
      _disposeStringLines();
      _stringLines = newLines;
      _stringInferError = unmatched > 0
          ? '$unmatched개 줄의 컬럼을 찾지 못했습니다. 드롭다운으로 직접 지정하세요.'
          : null;
    });
  }

  // ── 빌드 ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cellStructures = ref.watch(
      dataEditingProvider(widget.dataEditingParams).select((s) => s.cellStructures),
    );
    final columns = ref.watch(
      dataEditingProvider(widget.dataEditingParams).select((s) => s.columns),
    );
    final notifier = ref.read(dataEditingProvider(widget.dataEditingParams).notifier);
    final availableColumns = columns.map((c) => c['name']!).toList();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: Row(
        children: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              visualDensity: VisualDensity.compact,
              tooltip: '목록으로',
              onPressed: _closeEditor,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _editingColumn == null ? '새 구조 추가' : '구조 수정',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_editorMainColumn != null)
                    Text(
                      _editorMainColumn!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.normal),
                    ),
                ],
              ),
            ),
          ] else ...[
            const Icon(Icons.view_agenda_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('셀 구조 관리',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    widget.dataEditingParams.table,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 580,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isEditing
              ? _buildEditorView(availableColumns, notifier)
              : _buildListView(context, cellStructures, notifier, availableColumns),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: _isEditing
          ? [
              TextButton(onPressed: _closeEditor, child: const Text('취소')),
              ElevatedButton(
                onPressed: () => _saveEditor(notifier, availableColumns),
                child: const Text('저장'),
              ),
            ]
          : [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
    );
  }

  // ── 목록 뷰 ──────────────────────────────────────────────────

  Widget _buildListView(
    BuildContext context,
    Map<String, CellStructure> cellStructures,
    DataEditingNotifier notifier,
    List<String> availableColumns,
  ) {
    // 구조가 있는 컬럼을 앞으로, 없는 컬럼을 뒤로 정렬
    final sorted = [
      ...availableColumns.where((c) => cellStructures.containsKey(c)),
      ...availableColumns.where((c) => !cellStructures.containsKey(c)),
    ];

    return Column(
      key: const ValueKey('list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ 툴바 ─
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _showExportChoice(context, cellStructures),
              icon: const Icon(Icons.upload_file, size: 17),
              label: const Text('내보내기'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _startImport(context, notifier, availableColumns),
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('가져오기'),
            ),
            const Spacer(),
            if (cellStructures.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '더보기',
                onSelected: (v) {
                  if (v == 'clear') _confirmClearAll(context, notifier, cellStructures);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('전체 삭제', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        const Divider(height: 16),
        // ─ 컬럼 목록 ─
        if (availableColumns.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('컬럼 정보를 불러오는 중...',
                style: TextStyle(color: Colors.grey))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final col = sorted[i];
                final structure = cellStructures[col];
                return structure != null
                    ? _buildStructuredTile(context, col, structure, notifier)
                    : _buildUnstructuredTile(context, col);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStructuredTile(
    BuildContext context,
    String col,
    CellStructure structure,
    DataEditingNotifier notifier,
  ) {
    final absorbed = structure.absorbedColumns;
    final hasDisplayName =
        structure.displayName != null && structure.displayName!.isNotEmpty;

    return InkWell(
      onTap: () => _openEditor(col, existing: structure),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 컬러 바
            Container(
              width: 3,
              height: 48,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (hasDisplayName) ...[
                        Text(structure.displayName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 6),
                        Text('← $col',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ] else
                        Text(col,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // 줄 미리보기
                  Text(
                    structure.lines
                        .map((l) =>
                            l.prefix.isEmpty ? l.columnName : '${l.prefix}{${l.columnName}}')
                        .join('  ·  '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (absorbed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '숨김: ${absorbed.join(', ')}',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // 액션 버튼
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: Colors.grey.shade600),
              tooltip: '수정',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openEditor(col, existing: structure),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: '삭제',
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmDelete(context, notifier, col),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnstructuredTile(BuildContext context, String col) {
    return InkWell(
      onTap: () => _openEditor(col),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(col,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                  Text('구조 없음 — 탭하여 추가',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ── Export 선택 ───────────────────────────────────────────────

  Future<void> _showExportChoice(
    BuildContext context,
    Map<String, CellStructure> structures,
  ) async {
    var isGlobal = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('내보내기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<bool>(
                value: false,
                groupValue: isGlobal,
                onChanged: (v) => setS(() => isGlobal = v!),
                title: const Text('현재 테이블'),
                subtitle: Text(
                    '${widget.dataEditingParams.table}  ·  '
                    '${structures.length}개 구조',
                    style: const TextStyle(fontSize: 12)),
              ),
              RadioListTile<bool>(
                value: true,
                groupValue: isGlobal,
                onChanged: (v) => setS(() => isGlobal = v!),
                title: const Text('전체 서버'),
                subtitle: const Text('모든 서버·테이블의 설정을 하나의 파일로',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    if (isGlobal) {
      await _globalExport(context);
    } else {
      await _export(context, structures);
    }
  }

  // ── Import 단일 진입점 ────────────────────────────────────────

  Future<void> _startImport(
    BuildContext context,
    DataEditingNotifier notifier,
    List<String> availableColumns,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '설정 파일 가져오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      final content =
          await File(result.files.single.path!).readAsString(encoding: utf8);
      final decoded = jsonDecode(content) as Map<String, dynamic>;

      if (!context.mounted) return;

      if (GlobalCellStructureExport.isGlobalFormat(decoded)) {
        // 전체 포맷 → 체크박스로 항목 선택
        final export = GlobalCellStructureExport.fromJson(decoded);
        if (export.entries.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일에 항목이 없습니다.')));
          return;
        }
        final chosen = await _showGlobalImportDialog(context, export);
        if (chosen == null || chosen.isEmpty) return;
        await CellStructureGlobalStore.overwriteEntries(chosen);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${chosen.length}개 항목 가져옴 (다음 열기 시 적용)'),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        // 단일 테이블 포맷 → 현재 테이블로 가져오기
        final singleExport = CellStructureExport.fromJson(
            decoded, widget.dataEditingParams.table);
        final unknownCols = <String>{};
        for (final s in singleExport.structures.values) {
          for (final line in s.lines) {
            if (!availableColumns.contains(line.columnName)) {
              unknownCols.add(line.columnName);
            }
          }
        }
        final proceed = await _showImportPreviewDialog(
            context, singleExport, unknownCols);
        if (proceed != true) return;
        notifier.importCellStructures(singleExport.structures);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${singleExport.structures.length}개 구조를 가져왔습니다.'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('가져오기 실패: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── 편집 뷰 ──────────────────────────────────────────────────

  Widget _buildEditorView(List<String> availableColumns, DataEditingNotifier notifier) {
    return SingleChildScrollView(
      key: const ValueKey('editor'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 표시 이름
          TextField(
            controller: _displayNameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '헤더 표시 이름 (선택)',
              hintText: '비워두면 컬럼명(${ _editorMainColumn ?? ''}) 그대로 사용',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.label_outline, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          // 탭
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(icon: Icon(Icons.tune, size: 16), text: '직접 구성'),
                Tab(icon: Icon(Icons.auto_fix_high, size: 16), text: '예시로 입력'),
              ],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildManualEditor(availableColumns),
                _buildStringEditor(availableColumns),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 미리보기
          _buildPreview(),
        ],
      ),
    );
  }

  // ── 미리보기 ─────────────────────────────────────────────────

  Widget _buildPreview() {
    // 현재 탭에 따른 줄 목록 수집
    List<CellStructureLine> lines;
    if (_tabController.index == 0) {
      lines = _manualLines
          .map((e) => CellStructureLine(
              prefix: e.prefixController.text, columnName: e.columnName))
          .toList();
    } else {
      lines = _stringLines
          .where((l) => l.column.isNotEmpty)
          .map((l) => CellStructureLine(
              prefix: l.prefixCtrl.text, columnName: l.column))
          .toList();
    }

    if (lines.isEmpty) return const SizedBox.shrink();

    final dn = _displayNameCtrl.text.trim();
    final headerLabel =
        dn.isNotEmpty ? dn : (_editorMainColumn ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('미리보기',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          // 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
              ),
            ),
            child: Text(
              headerLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // 셀 미리보기
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              lines.map((l) {
                if (l.isExpression) {
                  return '${l.prefix}[${l.expression}]';
                }
                return l.prefix.isEmpty ? l.columnName : '${l.prefix}${l.columnName}';
              }).join('\n'),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              maxLines: lines.length,
            ),
          ),
        ],
      ),
    );
  }

  // ── 수동 편집기 ───────────────────────────────────────────────

  Widget _buildManualEditor(List<String> availableColumns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('줄을 드래그해 순서를 바꿀 수 있습니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 6),
        // 헤더 행
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const SizedBox(width: 32), // drag handle space
              SizedBox(
                width: 100,
                child: Text('앞 텍스트',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('컬럼 / 수식',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 76), // fx 토글 + 삭제 버튼 공간
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx--;
                final item = _manualLines.removeAt(oldIdx);
                _manualLines.insert(newIdx, item);
              });
            },
            children: _manualLines.asMap().entries.map((entry) {
              final i = entry.key;
              final line = entry.value;
              return Padding(
                key: ValueKey('ml_$i'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: line.prefixController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '예) "→ "',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 수식 또는 컬럼 선택 영역
                    Expanded(
                      child: line.isExpression
                          ? TextField(
                              controller: line.expressionController,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'a + b + c',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  child: Text('fx',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                ),
                                prefixIconConstraints: const BoxConstraints(),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue:
                                  availableColumns.contains(line.columnName)
                                      ? line.columnName
                                      : (availableColumns.isNotEmpty
                                          ? availableColumns.first
                                          : null),
                              items: availableColumns
                                  .map((c) =>
                                      DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() { line.columnName = v; });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                            ),
                    ),
                    // fx 토글 버튼
                    IconButton(
                      icon: Icon(
                        Icons.functions,
                        size: 18,
                        color: line.isExpression
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade400,
                      ),
                      tooltip: line.isExpression ? '컬럼 직접 선택으로 전환' : '수식으로 전환',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        line.isExpression = !line.isExpression;
                        if (line.isExpression &&
                            line.expressionController.text.isEmpty &&
                            line.columnName.isNotEmpty) {
                          line.expressionController.text = line.columnName;
                        }
                      }),
                    ),
                    // 줄 삭제
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: _manualLines.length > 1
                          ? () => setState(() {
                                _manualLines[i].dispose();
                                _manualLines.removeAt(i);
                              })
                          : null,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _manualLines.add(_LineEntry(
              prefixController: TextEditingController(),
              columnName: availableColumns.first,
            ));
          }),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('줄 추가'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ── 문자열 편집기 ─────────────────────────────────────────────

  Widget _buildStringEditor(List<String> availableColumns) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '실제 데이터 샘플을 왼쪽에, 셀에 보이길 원하는 모양을 오른쪽에 붙여넣으면 자동으로 구조를 추론합니다.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTextArea(
                  controller: _inputCtrl,
                  label: '① 샘플 값 입력',
                  hint: 'price = 100\nqty = 40',
                  helper: '컬럼명 = 샘플값  (또는 컬럼명: 샘플값)',
                  onChanged: (_) => _runInfer(availableColumns),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward, size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ),
                Expanded(child: _buildTextArea(
                  controller: _outputCtrl,
                  label: '② 원하는 출력 형태',
                  hint: '> 100\n40',
                  helper: '셀에 보여질 형식 그대로 입력',
                  onChanged: (_) => _runInfer(availableColumns),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildInferredSection(availableColumns),
        ],
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: 5,
          onChanged: onChanged,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontFamily: 'monospace'),
            contentPadding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(height: 2),
        Text(helper, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildInferredSection(List<String> availableColumns) {
    if (_stringLines.isEmpty && _stringInferError == null) {
      return Text(
        '입력과 출력을 모두 입력하면 구조가 자동으로 추론됩니다.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_stringLines.isNotEmpty) ...[
          const Text('추론된 구조', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(36),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(4), child: Text('줄', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(4), child: Text('접두사', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(4), child: Text('컬럼', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
              ),
              ..._stringLines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value;
                final needsAttention = !line.matched || !availableColumns.contains(line.column);
                return TableRow(
                  decoration: BoxDecoration(
                    color: needsAttention ? Colors.orange.shade50 : null,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('${i + 1}',
                          style: TextStyle(fontSize: 11,
                              color: needsAttention ? Colors.orange.shade800 : Colors.grey.shade700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: TextField(
                        controller: line.prefixCtrl,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: DropdownButtonFormField<String>(
                        value: availableColumns.contains(line.column) ? line.column : null,
                        hint: Text(line.raw,
                            style: const TextStyle(fontSize: 11, color: Colors.red),
                            overflow: TextOverflow.ellipsis),
                        items: availableColumns.map((c) =>
                            DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))).toList(),
                        onChanged: (v) { if (v != null) setState(() => line.column = v); },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
        if (_stringInferError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Expanded(child: Text(_stringInferError!,
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800))),
              ],
            ),
          ),
        if (_stringLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('메인 컬럼:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: availableColumns.contains(_stringMainColumn) ? _stringMainColumn : null,
                  hint: const Text('선택'),
                  items: _stringLines
                      .where((l) => l.matched && availableColumns.contains(l.column))
                      .map((l) => l.column)
                      .toSet()
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _stringMainColumn = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('메인 컬럼 위치에 구조화된 셀이 표시되고, 나머지 컬럼은 숨겨집니다.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ],
    );
  }

  // ── Export ────────────────────────────────────────────────────

  Future<void> _export(BuildContext context, Map<String, CellStructure> structures) async {
    if (structures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 구조가 없습니다.')),
      );
      return;
    }
    final meta = await _showExportMetadataDialog(context, structures);
    if (meta == null) return;
    final export = CellStructureExport(metadata: meta, structures: structures);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '셀 구조 내보내기',
        fileName: 'cell_structures_${widget.dataEditingParams.table}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(export.toJsonString(), encoding: utf8);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장됨: $path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<CellStructureMetadata?> _showExportMetadataDialog(
    BuildContext context,
    Map<String, CellStructure> structures,
  ) async {
    final nameCtrl    = TextEditingController();
    final descCtrl    = TextEditingController();
    final versionCtrl = TextEditingController(text: '1.0');
    return showDialog<CellStructureMetadata>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(
            children: [Icon(Icons.upload_file, size: 20), SizedBox(width: 8), Text('내보내기 정보')],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: '이름 *', hintText: '예) 고객 테이블 뷰 설정', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '설명 (선택)', hintText: '용도나 특이사항을 입력하세요.', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: versionCtrl,
                  decoration: const InputDecoration(labelText: '버전', hintText: '예) 1.0, 2.1', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('포함될 구조: ${structures.length}개',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ...structures.entries.map((e) {
                        final label = e.value.effectiveDisplayName != e.key
                            ? '${e.value.effectiveDisplayName}  ←  ${e.key}'
                            : e.key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_right, size: 14, color: Colors.grey),
                              Expanded(child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { nameCtrl.dispose(); descCtrl.dispose(); versionCtrl.dispose(); Navigator.pop(ctx); },
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              onPressed: nameCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      final meta = CellStructureMetadata(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        version: versionCtrl.text.trim().isEmpty ? '1.0' : versionCtrl.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                        table: widget.dataEditingParams.table,
                      );
                      nameCtrl.dispose(); descCtrl.dispose(); versionCtrl.dispose();
                      Navigator.pop(ctx, meta);
                    },
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Import ────────────────────────────────────────────────────

  Future<bool?> _showImportPreviewDialog(
    BuildContext context,
    CellStructureExport export,
    Set<String> unknownCols,
  ) {
    final meta      = export.metadata;
    final createdAt = meta.createdAt.isNotEmpty ? _formatDate(meta.createdAt) : null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.download_outlined, size: 20), SizedBox(width: 8), Text('가져오기 미리보기')],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaRow(Icons.label_outline, '이름', meta.name.isNotEmpty ? meta.name : '(없음)'),
                      if (meta.description.isNotEmpty) ...[const SizedBox(height: 4), _metaRow(Icons.notes, '설명', meta.description)],
                      if (meta.version.isNotEmpty) ...[const SizedBox(height: 4), _metaRow(Icons.tag, '버전', meta.version)],
                      if (createdAt != null) ...[const SizedBox(height: 4), _metaRow(Icons.calendar_today_outlined, '생성일', createdAt)],
                      if (meta.table.isNotEmpty) ...[const SizedBox(height: 4), _metaRow(Icons.table_chart_outlined, '테이블', meta.table)],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('포함된 구조: ${export.structures.length}개',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...export.structures.entries.map((e) {
                  final s = e.value;
                  final hasUnknown = s.lines.any((l) => unknownCols.contains(l.columnName));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(hasUnknown ? Icons.warning_amber : Icons.check_circle_outline,
                            size: 16, color: hasUnknown ? Colors.orange : Colors.green),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                            s.effectiveDisplayName != e.key
                                ? '${s.effectiveDisplayName}  ←  ${e.key}'
                                : e.key,
                            style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }),
                if (unknownCols.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(child: Text('현재 테이블에 없는 컬럼: ${unknownCols.join(', ')}',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('가져오기'),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  // ── 전체 서버 내보내기 ─────────────────────────────────────────

  Future<void> _globalExport(BuildContext context) async {
    final allEntries = await CellStructureGlobalStore.readAll();
    if (allEntries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장된 셀 구조 설정이 없습니다.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final result = await _showGlobalExportDialog(context, allEntries);
    if (result == null) return;
    final export = GlobalCellStructureExport(
      metadata: result.metadata,
      entries: result.entries,
    );
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '전체 서버 설정 내보내기',
        fileName: 'cell_structures_all.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(export.toJsonString(), encoding: utf8);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장됨: $path (${result.entries.length}개 항목)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<_GlobalExportResult?> _showGlobalExportDialog(
    BuildContext context,
    List<GlobalCellStructureEntry> allEntries,
  ) async {
    final selected = List<bool>.filled(allEntries.length, true);
    final nameCtrl    = TextEditingController();
    final descCtrl    = TextEditingController();
    final versionCtrl = TextEditingController(text: '1.0');

    return showDialog<_GlobalExportResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.cloud_upload_outlined, size: 20),
            SizedBox(width: 8),
            Text('전체 서버 내보내기'),
          ]),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    onChanged: (_) => setS(() {}),
                    decoration: const InputDecoration(
                      labelText: '이름 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '설명 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: versionCtrl,
                    decoration: const InputDecoration(
                      labelText: '버전',
                      hintText: '1.0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('포함할 항목',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setS(() { for (int i = 0; i < selected.length; i++) selected[i] = true; }),
                        child: const Text('전체 선택'),
                      ),
                      TextButton(
                        onPressed: () => setS(() { for (int i = 0; i < selected.length; i++) selected[i] = false; }),
                        child: const Text('전체 해제'),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allEntries.length,
                      itemBuilder: (_, i) {
                        final e = allEntries[i];
                        return CheckboxListTile(
                          dense: true,
                          value: selected[i],
                          onChanged: (v) => setS(() => selected[i] = v ?? false),
                          title: Text('${e.database} / ${e.table}',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(e.server,
                              style: const TextStyle(fontSize: 11)),
                          secondary: Text('${e.structures.length}개',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameCtrl.dispose(); descCtrl.dispose(); versionCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              onPressed: nameCtrl.text.trim().isEmpty ||
                      !selected.any((v) => v)
                  ? null
                  : () {
                      final meta = CellStructureMetadata(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        version: versionCtrl.text.trim().isEmpty
                            ? '1.0'
                            : versionCtrl.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                        table: '',
                      );
                      final chosen = <GlobalCellStructureEntry>[
                        for (int i = 0; i < allEntries.length; i++)
                          if (selected[i]) allEntries[i],
                      ];
                      nameCtrl.dispose(); descCtrl.dispose(); versionCtrl.dispose();
                      Navigator.pop(ctx, _GlobalExportResult(meta, chosen));
                    },
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('내보내기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<GlobalCellStructureEntry>?> _showGlobalImportDialog(
    BuildContext context,
    GlobalCellStructureExport export,
  ) async {
    final selected = List<bool>.filled(export.entries.length, true);
    final meta = export.metadata;
    final createdAt =
        meta.createdAt.isNotEmpty ? _formatDate(meta.createdAt) : null;

    return showDialog<List<GlobalCellStructureEntry>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.cloud_download_outlined, size: 20),
            SizedBox(width: 8),
            Text('전체 서버 가져오기'),
          ]),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // metadata 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metaRow(Icons.label_outline, '이름',
                            meta.name.isNotEmpty ? meta.name : '(없음)'),
                        if (meta.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _metaRow(Icons.notes, '설명', meta.description),
                        ],
                        if (meta.version.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _metaRow(Icons.tag, '버전', meta.version),
                        ],
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          _metaRow(Icons.calendar_today_outlined, '생성일', createdAt),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('포함된 항목: ${export.entries.length}개',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setS(() {
                          for (int i = 0; i < selected.length; i++) {
                            selected[i] = true;
                          }
                        }),
                        child: const Text('전체 선택'),
                      ),
                      TextButton(
                        onPressed: () => setS(() {
                          for (int i = 0; i < selected.length; i++) {
                            selected[i] = false;
                          }
                        }),
                        child: const Text('전체 해제'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: export.entries.length,
                      itemBuilder: (_, i) {
                        final e = export.entries[i];
                        return CheckboxListTile(
                          dense: true,
                          value: selected[i],
                          onChanged: (v) =>
                              setS(() => selected[i] = v ?? false),
                          title: Text('${e.database} / ${e.table}',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(e.server,
                              style: const TextStyle(fontSize: 11)),
                          secondary: Text('${e.structures.length}개',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '기존 설정에 덮어씁니다. 다음에 해당 테이블을 열 때 적용됩니다.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              onPressed: selected.any((v) => v)
                  ? () {
                      final chosen = [
                        for (int i = 0; i < export.entries.length; i++)
                          if (selected[i]) export.entries[i],
                      ];
                      Navigator.pop(ctx, chosen);
                    }
                  : null,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: const Text('가져오기'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 삭제 확인 다이얼로그 ──────────────────────────────────────

  void _confirmDelete(BuildContext context, DataEditingNotifier notifier, String columnName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구조 삭제'),
        content: Text('"$columnName" 컬럼의 셀 구조를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); notifier.removeCellStructure(columnName); },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(
    BuildContext context,
    DataEditingNotifier notifier,
    Map<String, CellStructure> structures,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 삭제'),
        content: Text('${structures.length}개 구조를 모두 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              for (final key in structures.keys.toList()) notifier.removeCellStructure(key);
            },
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );
  }
}
