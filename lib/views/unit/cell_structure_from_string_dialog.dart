// lib/views/unit/cell_structure_from_string_dialog.dart
import 'package:flutter/material.dart';
import '../../stateManagement/setState/cell_structure.dart';

/// 입력/출력 문자열로 셀 구조를 정의하는 다이얼로그.
///
/// - 입력 영역: "컬럼 = 샘플값" 한 줄씩
/// - 출력 영역: 원하는 표시 형식
/// - 하단: 추론된 구조 미리보기 (줄별 접두사·컬럼 수동 수정 가능) + 메인 컬럼 선택
Future<CellStructure?> showCellStructureFromStringDialog({
  required BuildContext context,
  required List<String> availableColumns,
  String? initialMainColumn,
}) {
  return showDialog<CellStructure>(
    context: context,
    builder: (ctx) => _CellStructureFromStringDialog(
      availableColumns: availableColumns,
      initialMainColumn: initialMainColumn,
    ),
  );
}

class _CellStructureFromStringDialog extends StatefulWidget {
  final List<String> availableColumns;
  final String? initialMainColumn;

  const _CellStructureFromStringDialog({
    required this.availableColumns,
    this.initialMainColumn,
  });

  @override
  State<_CellStructureFromStringDialog> createState() =>
      _CellStructureFromStringDialogState();
}

class _CellStructureFromStringDialogState
    extends State<_CellStructureFromStringDialog> {
  final _inputCtrl = TextEditingController();
  final _outputCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  // 추론된 줄 목록 — 각 줄의 접두사/컬럼을 유지
  List<_LineState> _lines = [];
  List<_LineState> _pendingDisposeLines = [];
  String? _mainColumn;
  String? _inferError;

  @override
  void initState() {
    super.initState();
    _mainColumn = widget.initialMainColumn;
    _inputCtrl.addListener(_runInfer);
    _outputCtrl.addListener(_runInfer);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _outputCtrl.dispose();
    _displayNameCtrl.dispose();
    for (final l in _lines) {
      l.prefixCtrl.dispose();
    }
    for (final l in _pendingDisposeLines) {
      l.prefixCtrl.dispose();
    }
    super.dispose();
  }

  // ─── 파싱 / 추론 ──────────────────────────────────────────────

  Map<String, String> _parseInput(String text) {
    final map = <String, String>{};
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final eqIdx = line.indexOf('=');
      final clIdx = line.indexOf(':');
      int split = -1;
      if (eqIdx > 0 && (clIdx < 0 || eqIdx <= clIdx)) {
        split = eqIdx;
      } else if (clIdx > 0) {
        split = clIdx;
      }
      if (split < 0) continue;
      final key = line.substring(0, split).trim();
      final val = line.substring(split + 1).trim();
      if (key.isNotEmpty) map[key] = val;
    }
    return map;
  }

  /// 출력 한 줄에서 가장 긴 값을 먼저 매칭
  _MatchResult _matchLine(String outputLine, Map<String, String> inputMap) {
    final byLength = inputMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final e in byLength) {
      final val = e.value;
      if (val.isEmpty) continue;
      if (outputLine.endsWith(val)) {
        return _MatchResult(
          prefix: outputLine.substring(0, outputLine.length - val.length),
          column: e.key,
          matched: true,
          raw: outputLine,
        );
      }
    }
    for (final e in byLength) {
      final val = e.value;
      if (val.isEmpty) continue;
      final idx = outputLine.indexOf(val);
      if (idx >= 0) {
        return _MatchResult(
          prefix: outputLine.substring(0, idx),
          column: e.key,
          matched: true,
          raw: outputLine,
        );
      }
    }
    return _MatchResult(prefix: '', column: '', matched: false, raw: outputLine);
  }

  void _deferDisposeLines() {
    if (_lines.isNotEmpty) {
      _pendingDisposeLines.addAll(_lines);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final l in _pendingDisposeLines) {
          l.prefixCtrl.dispose();
        }
        _pendingDisposeLines = [];
      });
    }
  }

  void _runInfer() {
    final inputText = _inputCtrl.text;
    final outputText = _outputCtrl.text;

    if (inputText.trim().isEmpty || outputText.trim().isEmpty) {
      _deferDisposeLines();
      setState(() {
        _lines = [];
        _inferError = null;
      });
      return;
    }

    final inputMap = _parseInput(inputText);
    if (inputMap.isEmpty) {
      _deferDisposeLines();
      setState(() {
        _lines = [];
        _inferError = '입력 형식 오류: "컬럼 = 값" 또는 "컬럼: 값" 형식으로 입력하세요.';
      });
      return;
    }

    final outputLines =
        outputText.split('\n').where((l) => l.isNotEmpty).toList();
    if (outputLines.isEmpty) {
      _deferDisposeLines();
      setState(() {
        _lines = [];
        _inferError = null;
      });
      return;
    }

    final newLines = outputLines.map((l) {
      final _MatchResult m = _matchLine(l, inputMap);
      return _LineState(
        prefixCtrl: TextEditingController(text: m.prefix),
        column: m.column,
        matched: m.matched,
        raw: m.raw,
      );
    }).toList();

    // 메인 컬럼 초기 추론
    if (_mainColumn == null) {
      final first = newLines.firstWhere(
        (l) => l.matched && l.column.isNotEmpty,
        orElse: () => newLines.first,
      );
      _mainColumn = first.column.isNotEmpty ? first.column : null;
    }

    final unmatched = newLines.where((l) => !l.matched).length;

    _deferDisposeLines();
    setState(() {
      _lines = newLines;
      _inferError = unmatched > 0
          ? '$unmatched개 줄의 컬럼을 찾지 못했습니다. 드롭다운으로 직접 지정하세요.'
          : null;
    });
  }



  // ─── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canApply = _lines.isNotEmpty &&
        _lines.every((l) => widget.availableColumns.contains(l.column)) &&
        widget.availableColumns.contains(_mainColumn);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high),
          SizedBox(width: 8),
          Text('문자열로 구조 정의'),
        ],
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 입력 / 출력 나란히 ──────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildTextArea(
                      controller: _inputCtrl,
                      label: '입력 (컬럼 = 샘플값)',
                      hint: 'price = 100\nqty1 = 40\nqty2 = 30',
                      helper: '"컬럼 = 값" 또는 "컬럼: 값" 형식으로 한 줄씩',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextArea(
                      controller: _outputCtrl,
                      label: '출력 형식 (표시될 문자열)',
                      hint: '> 100\n40\n30',
                      helper: '셀에 표시될 형태 그대로 입력',
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // ── 추론 결과 ───────────────────────────────────────
              _buildInferredSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: canApply ? _apply : null,
          child: const Text('적용'),
        ),
      ],
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: 7,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 12, fontFamily: 'monospace'),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 4),
        Text(helper,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildInferredSection() {
    if (_lines.isEmpty && _inferError == null) {
      return Text(
        '입력과 출력을 모두 입력하면 구조가 자동으로 추론됩니다.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('추론된 구조',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),

        // 줄별 행
        if (_lines.isNotEmpty)
          Table(
            columnWidths: const {
              0: FixedColumnWidth(48),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // 헤더
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text('줄', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text('접두사', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text('컬럼', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // 데이터 행
              ..._lines.asMap().entries.map((entry) {
                final i = entry.key;
                final line = entry.value;
                final needsAttention = !line.matched ||
                    !widget.availableColumns.contains(line.column);
                return TableRow(
                  decoration: BoxDecoration(
                    color: needsAttention ? Colors.orange.shade50 : null,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: needsAttention ? Colors.orange.shade800 : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: TextField(
                        controller: line.prefixCtrl,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: DropdownButtonFormField<String>(
                        value: widget.availableColumns.contains(line.column)
                            ? line.column
                            : null,
                        hint: Text(
                          line.matched && line.column.isNotEmpty
                              ? line.column
                              : '선택 필요  "${line.raw}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: needsAttention ? Colors.red : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: widget.availableColumns
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => line.column = v);
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),

        // 경고 메시지
        if (_inferError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_inferError!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade800)),
                ),
              ],
            ),
          ),

        // 메인 컬럼 선택
        if (_lines.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('메인 컬럼:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.availableColumns.contains(_mainColumn)
                      ? _mainColumn
                      : null,
                  hint: const Text('이 구조가 표시될 컬럼'),
                  items: _lines
                      .where((l) =>
                          l.matched &&
                          widget.availableColumns.contains(l.column))
                      .map((l) => l.column)
                      .toSet()
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _mainColumn = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '메인 컬럼 위치에 구조화된 셀이 표시되고, 나머지 컬럼은 숨겨집니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('표시 이름:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _displayNameCtrl,
                  decoration: InputDecoration(
                    hintText: '비워두면 메인 컬럼명 그대로 표시 (한글·영어 모두 가능)',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '헤더에 표시될 이름입니다. 여러 컬럼 병합 시 가상 이름(A, 전체이름 등)을 입력하세요.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  void _apply() {
    final lines = _lines
        .map((l) => CellStructureLine(
              prefix: l.prefixCtrl.text,
              columnName: l.column,
            ))
        .toList();
    final dn = _displayNameCtrl.text.trim();
    Navigator.pop(
      context,
      CellStructure(
        mainColumnName: _mainColumn!,
        lines: lines,
        displayName: dn.isEmpty ? null : dn,
      ),
    );
  }
}

class _LineState {
  final TextEditingController prefixCtrl;
  String column;
  final bool matched;
  final String raw;

  _LineState({
    required this.prefixCtrl,
    required this.column,
    required this.matched,
    this.raw = '',
  });
}

class _MatchResult {
  final String prefix;
  final String column;
  final bool matched;
  final String raw;

  const _MatchResult({
    required this.prefix,
    required this.column,
    required this.matched,
    this.raw = '',
  });
}
