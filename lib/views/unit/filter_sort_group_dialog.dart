import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';

/// 필터, 정렬, 그룹 다이얼로그 위젯
/// 팝업 형식으로 필터, 정렬, 그룹 기능을 제공
class FilterSortGroupDialog extends ConsumerStatefulWidget {
  final DataEditingParams dataEditingParams;
  final Map<int, TextEditingController> filterControllers;
  final VoidCallback onDispose;

  const FilterSortGroupDialog({
    super.key,
    required this.dataEditingParams,
    required this.filterControllers,
    required this.onDispose,
  });

  @override
  ConsumerState<FilterSortGroupDialog> createState() => _FilterSortGroupDialogState();
}

class _FilterSortGroupDialogState extends ConsumerState<FilterSortGroupDialog> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataEditingProvider(widget.dataEditingParams));
    final notifier = ref.read(dataEditingProvider(widget.dataEditingParams).notifier);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Text(
                  'Filter, Sort & Group',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            // 스크롤 가능한 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 필터 섹션
                    _buildFilterSection(state, notifier),
                    const Divider(),
                    // 정렬 섹션
                    _buildSortSection(state, notifier),
                    const Divider(),
                    // 그룹 섹션
                    _buildGroupSection(state, notifier),
                    const Divider(),
                    // 현재 상태 출력
                    _buildCurrentStateDisplay(state),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(DataEditingState state, DataEditingNotifier notifier) {
    // 필터가 삭제된 경우 해당 Controller 정리
    final currentFilterIndices = state.filters.asMap().keys.toSet();
    final controllerIndicesToRemove = widget.filterControllers.keys
        .where((idx) => !currentFilterIndices.contains(idx))
        .toList();
    for (final idx in controllerIndicesToRemove) {
      widget.filterControllers[idx]?.dispose();
      widget.filterControllers.remove(idx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Filter'),
              onPressed: () => _showAddFilterDialog(notifier, state),
            ),
            TextButton.icon(
              icon: const Icon(Icons.code, size: 18),
              label: const Text('Add ('),
              onPressed: () => notifier.addOpenParenthesis(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.code, size: 18),
              label: const Text('Add )'),
              onPressed: () => notifier.addCloseParenthesis(),
            ),
            if (state.filters.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear All'),
                onPressed: () {
                  // 모든 Controller 정리
                  for (final controller in widget.filterControllers.values) {
                    controller.dispose();
                  }
                  widget.filterControllers.clear();
                  notifier.clearFilters();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 엑셀 스타일 조건 빌더
        _buildExcelStyleFilterBuilder(state, notifier),
      ],
    );
  }

  Widget _buildFilterItem(FilterCondition filter, int index, DataEditingNotifier notifier, DataEditingState state) {
    // TextEditingController 초기화 (없으면 생성)
    if (!widget.filterControllers.containsKey(index)) {
      final initialValue = filter.value?.toString() ?? '';
      widget.filterControllers[index] = TextEditingController(text: initialValue);
    }

    final controller = widget.filterControllers[index]!;

    // 필터 값이 외부에서 변경된 경우 controller 업데이트 (예: 연산자 변경)
    final currentValue = filter.value?.toString() ?? '';
    if (controller.text != currentValue &&
        (filter.operator != 'IS NULL' && filter.operator != 'IS NOT NULL')) {
      controller.text = currentValue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 그룹 인덱스 표시
          if (filter.groupIndex != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Group ${filter.groupIndex! + 1}',
                style: const TextStyle(fontSize: 10, color: Colors.purple),
              ),
            ),
          const SizedBox(width: 8),
          // 열 선택
          SizedBox(
            width: 120,
            child: DropdownButton<String>(
              value: filter.columnName,
              isExpanded: true,
              items: state.columns.map((col) {
                return DropdownMenuItem(
                  value: col['name']!,
                  child: Text(col['name']!, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (newColumn) {
                if (newColumn != null) {
                  notifier.updateFilter(index, filter.copyWith(columnName: newColumn));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // 연산자 선택
          SizedBox(
            width: 100,
            child: DropdownButton<String>(
              value: filter.operator,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '=', child: Text('=')),
                DropdownMenuItem(value: '!=', child: Text('!=')),
                DropdownMenuItem(value: '<', child: Text('<')),
                DropdownMenuItem(value: '>', child: Text('>')),
                DropdownMenuItem(value: '<=', child: Text('<=')),
                DropdownMenuItem(value: '>=', child: Text('>=')),
                DropdownMenuItem(value: 'LIKE', child: Text('LIKE')),
                DropdownMenuItem(value: 'IN', child: Text('IN')),
                DropdownMenuItem(value: 'NOT IN', child: Text('NOT IN')),
                DropdownMenuItem(value: 'IS NULL', child: Text('IS NULL')),
                DropdownMenuItem(value: 'IS NOT NULL', child: Text('IS NOT NULL')),
              ],
              onChanged: (newOperator) {
                if (newOperator != null) {
                  // 연산자 변경 시 즉시 적용 (IS NULL, IS NOT NULL의 경우 값이 없으므로)
                  notifier.updateFilter(index, filter.copyWith(operator: newOperator));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // 값 입력 (IS NULL, IS NOT NULL 제외)
          if (filter.operator != 'IS NULL' && filter.operator != 'IS NOT NULL')
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Value',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                controller: controller,
                // 입력이 끝난 후에만 적용 (Enter 키 또는 포커스 아웃)
                onSubmitted: (value) {
                  _applyFilterValue(index, filter, notifier, value);
                },
                onEditingComplete: () {
                  _applyFilterValue(index, filter, notifier, controller.text);
                },
              ),
            ),
          const SizedBox(width: 8),
          // 논리 연산자 (마지막 필터가 아닌 경우)
          if (index < state.filters.length - 1)
            SizedBox(
              width: 80,
              child: DropdownButton<String>(
                value: filter.logicalOperator ?? 'AND',
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'AND', child: Text('AND')),
                  DropdownMenuItem(value: 'OR', child: Text('OR')),
                ],
                onChanged: (newOp) {
                  notifier.updateFilter(index, filter.copyWith(logicalOperator: newOp));
                },
              ),
            ),
          const SizedBox(width: 8),
          // 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: () {
              // Controller 정리
              widget.filterControllers[index]?.dispose();
              widget.filterControllers.remove(index);
              notifier.removeFilter(index);
            },
          ),
        ],
      ),
    );
  }

  /// 필터 값을 적용하는 헬퍼 메서드
  void _applyFilterValue(int index, FilterCondition filter, DataEditingNotifier notifier, String value) {
    dynamic parsedValue = value;
    // IN, NOT IN의 경우 콤마로 구분된 리스트로 파싱
    if (filter.operator == 'IN' || filter.operator == 'NOT IN') {
      parsedValue = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (value.trim().isEmpty) {
      parsedValue = null;
    }
    notifier.updateFilter(index, filter.copyWith(value: parsedValue));
  }

  Widget _buildExcelStyleFilterBuilder(DataEditingState state, DataEditingNotifier notifier) {
    if (state.filters.isEmpty && (state.filterBlocks?.isEmpty ?? true)) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '조건을 추가하려면 "Add Filter" 버튼을 클릭하세요',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    // 필터와 괄호, AND/OR 블럭을 하나의 리스트로 관리
    List<Map<String, dynamic>> blocks = _buildFilterBlockList(state);
    debugPrint("[_buildExcelStyleFilterBuilder] blocks.asMap().entries: ${blocks.asMap().entries}");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          notifier.reorderFilterBlock(oldIndex, newIndex);
        },
        children: blocks.asMap().entries.map((entry) {
          final index = entry.key;
          final block = entry.value;

          return _buildDraggableBlock(
            key: ValueKey('block_$index'),
            block: block,
            blockIndex: index,
            state: state,
            notifier: notifier,
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _buildFilterBlockList(DataEditingState state) {
    // state에서 블럭 정보를 가져오거나 생성
    // 예: [{'type': 'filter', 'index': 0}, {'type': 'operator', 'value': 'AND'}, {'type': 'parenthesis', 'value': '('}, ...]
    final blocks = <Map<String, dynamic>>[];
    final filters = state.filters;

    for (int i = 0; i < filters.length; i++) {
      final filter = filters[i];
      final currentGroup = filter.groupIndex;

      // 이전 조건의 그룹과 다르면 여는 괄호 추가
      if (i == 0 || filters[i - 1].groupIndex != currentGroup) {
        blocks.add({'type': 'openparen', 'groupIndex': currentGroup});
      }

      blocks.add({'type': 'filter', 'index': i});

      // 다음 조건의 그룹과 다르면 닫는 괄호 추가
      if (i == filters.length - 1 || filters[i + 1].groupIndex != currentGroup) {
        blocks.add({'type': 'closeparen', 'groupIndex': currentGroup});
      }

      if (i < filters.length - 1) {
        blocks.add({
          'type': 'operator',
          'value': filter.logicalOperator ?? 'AND',
        });
      }
    }

    return blocks;
  }

  Widget _buildDraggableBlock({
    required Key key,
    required Map<String, dynamic> block,
    required int blockIndex,
    required DataEditingState state,
    required DataEditingNotifier notifier,
  }) {
    final blockType = block['type'] as String;
    Widget content;
    switch (blockType) {
      case 'filter':
        final filter = state.filters[block['index'] as int];
        content = _buildFilterBlockContent(filter: filter, filterIndex: block['index'] as int, state: state, notifier: notifier);
        break;
      case 'operator':
        content = _buildOperatorBlockContent(operator: block['value'] as String?, blockIndex: blockIndex, notifier: notifier);
        break;
      case 'openparen':
        content = _buildParenthesisBlockContent('(', blockIndex, notifier);
        break;
      case 'closeparen':
        content = _buildParenthesisBlockContent(')', blockIndex, notifier);
        break;
      default:
        content = Container();
    }

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      constraints: const BoxConstraints(minHeight: 48), // 최소 높이 지정
      child: content,
    );
  }

  Widget _buildOperatorBlockContent({String? operator, int? blockIndex, DataEditingNotifier? notifier}) {
    if (operator == null || blockIndex == null || notifier == null) {
      return Container();
    }
    final isAnd = operator == 'AND';
    return IntrinsicWidth(
      child: InkWell(
        onTap: () => notifier.toggleFilterOperatorAtBlock(blockIndex),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isAnd ? Colors.blue.shade50 : Colors.orange.shade50,
            border: Border.all(
              color: isAnd ? Colors.blue.shade300 : Colors.orange.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                operator,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isAnd ? Colors.blue.shade700 : Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz, size: 16, color: isAnd ? Colors.blue.shade700 : Colors.orange.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParenthesisBlockContent(String paren, int blockIndex, DataEditingNotifier notifier) {
    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          border: Border.all(color: Colors.purple.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                paren,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => notifier.removeBlockAtBlockIndex(blockIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBlockContent({
    required FilterCondition filter,
    required int filterIndex,
    required DataEditingState state,
    required DataEditingNotifier notifier,
  }) {
    if (!widget.filterControllers.containsKey(filterIndex)) {
      final initialValue = filter.value?.toString() ?? '';
      widget.filterControllers[filterIndex] = TextEditingController(text: initialValue);
    }
    final controller = widget.filterControllers[filterIndex]!;

    final hasParenthesis = state.filterParenthesis?[filterIndex] ?? false;

    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.blue.shade100, blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      widget.filterControllers[filterIndex]?.dispose();
                      widget.filterControllers.remove(filterIndex);
                      notifier.removeFilter(filterIndex);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: filter.columnName,
                      decoration: InputDecoration(
                        labelText: 'Column',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        isDense: true,
                      ),
                      items: state.columns.map((col) {
                        final columnName = col['name'] ?? col['columnname'] ?? '';
                        return DropdownMenuItem<String>(
                          value: columnName,
                          child: Text(columnName, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          notifier.updateFilterColumn(filterIndex, value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: filter.operator,
                      decoration: InputDecoration(
                        labelText: 'Op',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: '=', child: Text('=')),
                        DropdownMenuItem(value: '!=', child: Text('!=')),
                        DropdownMenuItem(value: '<', child: Text('<')),
                        DropdownMenuItem(value: '<=', child: Text('<=')),
                        DropdownMenuItem(value: '>', child: Text('>')),
                        DropdownMenuItem(value: '>=', child: Text('>=')),
                        DropdownMenuItem(value: 'LIKE', child: Text('LIKE')),
                        DropdownMenuItem(value: 'IN', child: Text('IN')),
                        DropdownMenuItem(value: 'NOT IN', child: Text('NOT IN')),
                        DropdownMenuItem(value: 'IS NULL', child: Text('IS NULL')),
                        DropdownMenuItem(value: 'IS NOT NULL', child: Text('IS NOT NULL')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          notifier.updateFilterOperator(filterIndex, value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (filter.operator != 'IS NULL' && filter.operator != 'IS NOT NULL')
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Value',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          isDense: true,
                        ),
                        onChanged: (value) => notifier.updateFilterValue(filterIndex, value),
                      ),
                    ),
                  if (hasParenthesis)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        ')',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorBlock({
    required Key key,
    required String operator,
    required VoidCallback onToggle,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: operator == 'AND' ? Colors.blue.shade50 : Colors.orange.shade50,
              border: Border.all(
                color: operator == 'AND' ? Colors.blue.shade300 : Colors.orange.shade300,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  operator,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: operator == 'AND' ? Colors.blue.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: operator == 'AND' ? Colors.blue.shade700 : Colors.orange.shade700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBlock({
    required Key key,
    required dynamic filter,
    required int filterIndex,
    required DataEditingState state,
    required DataEditingNotifier notifier,
  }) {
    // Controller 초기화 (없는 경우에만)
    if (!widget.filterControllers.containsKey(filterIndex)) {
      widget.filterControllers[filterIndex] = TextEditingController(text: filter.value?.toString() ?? '');
    }

    final controller = widget.filterControllers[filterIndex]!;
    final hasParenthesis = state.filterParenthesis?[filterIndex] ?? false;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // 필터 헤더 (드래그 핸들 + 괄호 토글 + 삭제)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                // 드래그 핸들
                const Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                // 괄호 토글
                InkWell(
                  onTap: () => notifier.toggleFilterParenthesis(filterIndex),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasParenthesis ? Colors.purple.shade50 : Colors.transparent,
                      border: Border.all(
                        color: hasParenthesis ? Colors.purple.shade300 : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '( )',
                      style: TextStyle(
                        fontWeight: hasParenthesis ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                        color: hasParenthesis ? Colors.purple.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // 삭제 버튼
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.red.shade400,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    widget.filterControllers[filterIndex]?.dispose();
                    widget.filterControllers.remove(filterIndex);
                    notifier.removeFilter(filterIndex);
                  },
                ),
              ],
            ),
          ),
          // 필터 내용
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 괄호 시작
                if (hasParenthesis)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '(',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                // 컬럼 선택
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: filter.columnName,
                    decoration: InputDecoration(
                      labelText: 'Column',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    items: state.columns.map((col) {
                      // Map에서 컬럼 이름 추출 (일반적으로 'name' 또는 'column_name' 키 사용)
                      final columnName = col['name'] ?? col['column_name'] ?? '';
                      return DropdownMenuItem<String>(
                        value: columnName,
                        child: Text(columnName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        notifier.updateFilterColumn(filterIndex, value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 연산자 선택
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: filter.operator,
                    decoration: InputDecoration(
                      labelText: 'Op',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    items: const [
                      DropdownMenuItem(value: '=', child: Text('=')),
                      DropdownMenuItem(value: '!=', child: Text('!=')),
                      DropdownMenuItem(value: '>', child: Text('>')),
                      DropdownMenuItem(value: '<', child: Text('<')),
                      DropdownMenuItem(value: '>=', child: Text('>=')),
                      DropdownMenuItem(value: '<=', child: Text('<=')),
                      DropdownMenuItem(value: 'LIKE', child: Text('LIKE')),
                      DropdownMenuItem(value: 'IN', child: Text('IN')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        notifier.updateFilterOperator(filterIndex, value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 값 입력
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Value',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onChanged: (value) {
                      notifier.updateFilterValue(filterIndex, value);
                    },
                  ),
                ),
                // 괄호 끝
                if (hasParenthesis)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      ')',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection(DataEditingState state, DataEditingNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Sorts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Sort'),
              onPressed: () => _showAddSortDialog(notifier, state),
            ),
            if (state.sorts.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear All'),
                onPressed: () => notifier.clearSorts(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...state.sorts.asMap().entries.map((entry) {
          final index = entry.key;
          final sort = entry.value;
          return _buildDraggableSortItem(sort, index, state, notifier);
        }),
      ],
    );
  }

  Widget _buildDraggableSortItem(SortCondition sort, int index, DataEditingState state, DataEditingNotifier notifier) {
    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8,
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)
              ],
            ),
            child: _buildSortItemContent(sort, index, state, notifier),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildSortItemContent(sort, index, state, notifier),
        ),
      ),
      child: DragTarget<int>(
        onAccept: (draggedIndex) {
          if (draggedIndex != index) {
            notifier.reorderSorts(draggedIndex, index);
          }
        },
        onWillAccept: (data) => data != index,
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: isTarget
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildSortItemContent(sort, index, state, notifier),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortItemContent(SortCondition sort, int index, DataEditingState state, DataEditingNotifier notifier) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DropdownButton<String>(
            value: sort.columnName,
            isExpanded: true,
            items: state.columns.map((col) {
              return DropdownMenuItem(
                value: col['name']!,
                child: Text(col['name']!, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (newColumn) {
              if (newColumn != null) {
                notifier.updateSort(index, sort.copyWith(columnName: newColumn));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: DropdownButton<bool>(
            value: sort.ascending,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: true, child: Text('ASC')),
              DropdownMenuItem(value: false, child: Text('DESC')),
            ],
            onChanged: (newAscending) {
              if (newAscending != null) {
                notifier.updateSort(index, sort.copyWith(ascending: newAscending));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
          onPressed: () => notifier.removeSort(index),
        ),
      ],
    );
  }

  Widget _buildGroupSection(DataEditingState state, DataEditingNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Group By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Group'),
              onPressed: () => _showAddGroupDialog(notifier, state),
            ),
            if (state.groupByColumns.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear All'),
                onPressed: () => notifier.clearGroupBy(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...state.groupByColumns.asMap().entries.map((entry) {
          final index = entry.key;
          final columnName = entry.value;
          return _buildDraggableGroupItem(columnName, index, notifier);
        }),
      ],
    );
  }

  Widget _buildDraggableGroupItem(String columnName, int index, DataEditingNotifier notifier) {
    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8,
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)
              ],
            ),
            child: _buildGroupItemContent(columnName, notifier),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildGroupItemContent(columnName, notifier),
        ),
      ),
      child: DragTarget<int>(
        onAccept: (draggedIndex) {
          if (draggedIndex != index) {
            notifier.reorderGroupBy(draggedIndex, index);
          }
        },
        onWillAccept: (data) => data != index,
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: isTarget
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildGroupItemContent(columnName, notifier),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupItemContent(String columnName, DataEditingNotifier notifier) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        const Icon(Icons.group, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(columnName, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
          onPressed: () => notifier.removeGroupByColumn(columnName),
        ),
      ],
    );
  }

  Widget _buildCurrentStateDisplay(DataEditingState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current State',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (state.filters.isEmpty && state.sorts.isEmpty && state.groupByColumns.isEmpty)
            const Text('No filters, sorts, or groups applied.', style: TextStyle(color: Colors.grey))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.filters.isNotEmpty) ...[
                  const Text('Filters:', style: TextStyle(fontWeight: FontWeight.w500)),
                  ...state.filters.asMap().entries.map((entry) {
                    final index = entry.key;
                    final filter = entry.value;
                    final groupPrefix = filter.groupIndex != null ? '[Group ${filter.groupIndex! + 1}] ' : '';
                    final valueDisplay = filter.operator == 'IS NULL' || filter.operator == 'IS NOT NULL'
                        ? ''
                        : filter.operator == 'IN' || filter.operator == 'NOT IN'
                            ? ' (${(filter.value as List).join(', ')})'
                            : ' ${filter.value}';
                    final logicalOp = index < state.filters.length - 1
                        ? ' ${filter.logicalOperator ?? 'AND'}'
                        : '';
                    return Text('  $groupPrefix${filter.columnName} ${filter.operator}$valueDisplay$logicalOp');
                  }),
                ],
                if (state.sorts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Sorts:', style: TextStyle(fontWeight: FontWeight.w500)),
                  ...state.sorts.map((sort) {
                    return Text('  ${sort.columnName} ${sort.ascending ? 'ASC' : 'DESC'}');
                  }),
                ],
                if (state.groupByColumns.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Groups:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('  ${state.groupByColumns.join(', ')}'),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _showAddFilterDialog(DataEditingNotifier notifier, DataEditingState state) {
    if (state.columns.isEmpty) return;

    String selectedColumn = state.columns.first['name']!;
    String selectedOperator = '=';
    String? valueText = '';
    // 기본값으로 AND 사용 (마지막 필터가 있으면 그 필터의 논리 연산자 사용)
    String? logicalOperator = state.filters.isNotEmpty 
        ? state.filters.last.logicalOperator ?? 'AND'
        : 'AND';
    int? groupIndex;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateInDialog) => AlertDialog(
          title: const Text('Add Filter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedColumn,
                  decoration: const InputDecoration(labelText: 'Column', border: OutlineInputBorder()),
                  items: state.columns.map((col) {
                    return DropdownMenuItem(value: col['name']!, child: Text(col['name']!));
                  }).toList(),
                  onChanged: (value) => setStateInDialog(() => selectedColumn = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedOperator,
                  decoration: const InputDecoration(labelText: 'Operator', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '=', child: Text('=')),
                    DropdownMenuItem(value: '!=', child: Text('!=')),
                    DropdownMenuItem(value: '<', child: Text('<')),
                    DropdownMenuItem(value: '>', child: Text('>')),
                    DropdownMenuItem(value: '<=', child: Text('<=')),
                    DropdownMenuItem(value: '>=', child: Text('>=')),
                    DropdownMenuItem(value: 'LIKE', child: Text('LIKE')),
                    DropdownMenuItem(value: 'IN', child: Text('IN')),
                    DropdownMenuItem(value: 'NOT IN', child: Text('NOT IN')),
                    DropdownMenuItem(value: 'IS NULL', child: Text('IS NULL')),
                    DropdownMenuItem(value: 'IS NOT NULL', child: Text('IS NOT NULL')),
                  ],
                  onChanged: (value) => setStateInDialog(() => selectedOperator = value!),
                ),
                if (selectedOperator != 'IS NULL' && selectedOperator != 'IS NOT NULL') ...[
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: selectedOperator == 'IN' || selectedOperator == 'NOT IN'
                          ? 'Values (comma-separated)'
                          : 'Value',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setStateInDialog(() => valueText = value),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '괄호 그룹 (선택사항)',
                    border: OutlineInputBorder(),
                    hintText: '같은 숫자를 입력하면 같은 그룹으로 묶임',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setStateInDialog(() {
                      groupIndex = value.isEmpty ? null : int.tryParse(value);
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                dynamic value = valueText;
                if (selectedOperator == 'IN' || selectedOperator == 'NOT IN') {
                  value = valueText?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];
                } else if (selectedOperator == 'IS NULL' || selectedOperator == 'IS NOT NULL') {
                  value = null;
                }

                notifier.addFilter(FilterCondition(
                  columnName: selectedColumn,
                  operator: selectedOperator,
                  value: value,
                  logicalOperator: logicalOperator,
                  groupIndex: groupIndex,
                ));
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSortDialog(DataEditingNotifier notifier, DataEditingState state) {
    if (state.columns.isEmpty) return;

    String selectedColumn = state.columns.first['name']!;
    bool ascending = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateInDialog) => AlertDialog(
          title: const Text('Add Sort'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedColumn,
                decoration: const InputDecoration(labelText: 'Column', border: OutlineInputBorder()),
                items: state.columns.map((col) {
                  return DropdownMenuItem(value: col['name']!, child: Text(col['name']!));
                }).toList(),
                onChanged: (value) => setStateInDialog(() => selectedColumn = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                value: ascending,
                decoration: const InputDecoration(labelText: 'Order', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: true, child: Text('ASC')),
                  DropdownMenuItem(value: false, child: Text('DESC')),
                ],
                onChanged: (value) => setStateInDialog(() => ascending = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                notifier.addSort(SortCondition(columnName: selectedColumn, ascending: ascending));
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGroupDialog(DataEditingNotifier notifier, DataEditingState state) {
    if (state.columns.isEmpty) return;

    final availableColumns = state.columns
        .map((col) => col['name'] as String)
        .where((col) => !state.groupByColumns.contains(col))
        .toList();

    if (availableColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All columns are already in group by.')),
      );
      return;
    }

    String selectedColumn = availableColumns.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateInDialog) => AlertDialog(
          title: const Text('Add Group By'),
          content: DropdownButtonFormField<String>(
            value: selectedColumn,
            decoration: const InputDecoration(labelText: 'Column', border: OutlineInputBorder()),
            items: availableColumns.map((col) {
              return DropdownMenuItem(value: col, child: Text(col));
            }).toList(),
            onChanged: (value) => setStateInDialog(() => selectedColumn = value!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                notifier.addGroupByColumn(selectedColumn);
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 필터 그룹 정보 클래스
class _FilterGroup {
  final int startIndex;
  final int endIndex;
  final bool isGrouped;

  _FilterGroup({
    required this.startIndex,
    required this.endIndex,
    required this.isGrouped,
  });
}

/// 엑셀 스타일 조건 빌더 위젯
/// 드래그 앤 드롭으로 조건 블록을 재배치할 수 있음
class _FilterConditionBuilder extends StatefulWidget {
  final List<FilterCondition> filters;
  final List<Map<String, String>> columns;
  final DataEditingNotifier notifier;
  final Map<int, TextEditingController> filterControllers;

  const _FilterConditionBuilder({
    required this.filters,
    required this.columns,
    required this.notifier,
    required this.filterControllers,
  });

  @override
  State<_FilterConditionBuilder> createState() => _FilterConditionBuilderState();
}

class _FilterConditionBuilderState extends State<_FilterConditionBuilder> {
  int? _draggedIndex;
  int? _dragTargetIndex;

  @override
  Widget build(BuildContext context) {
    // 그룹별로 필터를 묶어서 처리
    final List<_FilterGroup> groups = _buildFilterGroups();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < groups.length; i++) ...[
          // 그룹 사이 드롭 존
          if (i > 0) _buildBetweenGroupsDropZone(groups[i - 1], groups[i]),
          if (groups[i].isGrouped) _buildDraggableGroup(groups[i]) else _buildUngroupedItems(groups[i]),
        ],
      ],
    );
  }

  List<_FilterGroup> _buildFilterGroups() {
    final List<_FilterGroup> groups = [];
    int i = 0;
    
    while (i < widget.filters.length) {
      final currentGroupIndex = widget.filters[i].groupIndex;
      
      if (currentGroupIndex != null) {
        // 그룹화된 필터들 찾기
        final startIndex = i;
        while (i < widget.filters.length && widget.filters[i].groupIndex == currentGroupIndex) {
          i++;
        }
        groups.add(_FilterGroup(
          startIndex: startIndex,
          endIndex: i - 1,
          isGrouped: true,
        ));
      } else {
        // 그룹화되지 않은 단일 필터
        groups.add(_FilterGroup(
          startIndex: i,
          endIndex: i,
          isGrouped: false,
        ));
        i++;
      }
    }
    
    return groups;
  }

  Widget _buildDraggableGroup(_FilterGroup group) {
    final groupIndex = widget.filters[group.startIndex].groupIndex!;
    
    return Draggable<_FilterGroup>(
      data: group,
      feedback: Material(
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)
            ],
          ),
          child: _buildGroupContent(group, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildGroupContent(group),
        ),
      ),
      onDragStarted: () {
        setState(() => _draggedIndex = group.startIndex);
      },
      onDragEnd: (_) {
        setState(() {
          _draggedIndex = null;
          _dragTargetIndex = null;
        });
      },
      child: DragTarget<_FilterGroup>(
        onAccept: (draggedGroup) {
          if (draggedGroup.startIndex != group.startIndex) {
            _reorderGroup(draggedGroup, group);
          }
        },
        onWillAccept: (data) {
          setState(() => _dragTargetIndex = group.startIndex);
          return data?.startIndex != group.startIndex;
        },
        onLeave: (_) {
          setState(() => _dragTargetIndex = null);
        },
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty && _dragTargetIndex == group.startIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: isTarget
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildGroupContent(group),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUngroupedItems(_FilterGroup group) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 괄호 밖으로 드래그할 수 있는 드롭 존 (그룹화되지 않은 항목 앞)
        if (group.startIndex > 0) _buildOutsideGroupDropZone(group.startIndex),
        for (int i = group.startIndex; i <= group.endIndex; i++) ...[
          _buildConditionBlock(widget.filters[i], i),
          if (i < group.endIndex) _buildLogicalOperator(i),
        ],
        // 괄호 밖으로 드래그할 수 있는 드롭 존 (그룹화되지 않은 항목 뒤)
        if (group.endIndex < widget.filters.length - 1) _buildOutsideGroupDropZone(group.endIndex + 1),
      ],
    );
  }

  Widget _buildGroupContent(_FilterGroup group, {bool isDragging = false}) {
    final groupIndex = widget.filters[group.startIndex].groupIndex!;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 드래그 핸들
        Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        // 시작 괄호 (드래그 타겟 + 클릭하면 그룹 제거)
        _buildGroupStartBracket(group, groupIndex),
        const SizedBox(width: 4),
        // 조건들
        for (int i = group.startIndex; i <= group.endIndex; i++) ...[
          _buildConditionBlock(widget.filters[i], i),
          if (i < group.endIndex) _buildLogicalOperator(i),
        ],
        const SizedBox(width: 4),
        // 끝 괄호 (드래그 타겟)
        _buildGroupEndBracket(group, groupIndex),
      ],
    );
  }

  Widget _buildGroupStartBracket(_FilterGroup group, int groupIndex) {
    return DragTarget<int>(
      onAccept: (draggedIndex) {
        _moveFilterIntoGroup(draggedIndex, group.startIndex, groupIndex);
      },
      onWillAccept: (data) {
        if (data == null) return false;
        final draggedFilter = widget.filters[data];
        // 이미 같은 그룹에 있으면 거부
        return draggedFilter.groupIndex != groupIndex;
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () => _removeGroup(group.startIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isTarget ? Colors.green.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isTarget ? Colors.green.shade300 : Colors.blue.shade300,
                width: isTarget ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('(', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.close, size: 14, color: Colors.blue.shade700),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupEndBracket(_FilterGroup group, int groupIndex) {
    return DragTarget<int>(
      onAccept: (draggedIndex) {
        _moveFilterIntoGroup(draggedIndex, group.endIndex + 1, groupIndex);
      },
      onWillAccept: (data) {
        if (data == null) return false;
        final draggedFilter = widget.filters[data];
        // 이미 같은 그룹에 있으면 거부
        return draggedFilter.groupIndex != groupIndex;
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isTarget ? Colors.green.shade100 : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isTarget ? Colors.green.shade300 : Colors.blue.shade300,
              width: isTarget ? 2 : 1,
            ),
          ),
          child: const Text(')', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildOutsideGroupDropZone(int targetIndex) {
    return DragTarget<int>(
      onAccept: (draggedIndex) {
        _moveFilterOutOfGroup(draggedIndex);
      },
      onWillAccept: (data) {
        if (data == null) return false;
        final draggedFilter = widget.filters[data];
        // 이미 그룹에 있으면 허용
        return draggedFilter.groupIndex != null;
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isTarget ? 20 : 8,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isTarget ? Colors.orange.shade100 : Colors.transparent,
            border: isTarget
                ? Border.all(color: Colors.orange.shade300, width: 2, style: BorderStyle.solid)
                : Border.all(color: Colors.grey.shade300.withOpacity(0.5), width: 1, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isTarget
              ? const Center(
                  child: Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBetweenGroupsDropZone(_FilterGroup prevGroup, _FilterGroup nextGroup) {
    return DragTarget<int>(
      onAccept: (draggedIndex) {
        final draggedFilter = widget.filters[draggedIndex];
        // 그룹에 있으면 그룹에서 제거
        if (draggedFilter.groupIndex != null) {
          _moveFilterOutOfGroup(draggedIndex);
        }
      },
      onWillAccept: (data) {
        if (data == null) return false;
        final draggedFilter = widget.filters[data];
        // 그룹에 있으면 허용
        return draggedFilter.groupIndex != null;
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isTarget ? 20 : 8,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isTarget ? Colors.orange.shade100 : Colors.transparent,
            border: isTarget
                ? Border.all(color: Colors.orange.shade300, width: 2, style: BorderStyle.solid)
                : Border.all(color: Colors.grey.shade300.withOpacity(0.5), width: 1, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isTarget
              ? const Center(
                  child: Icon(Icons.remove_circle_outline, size: 16, color: Colors.orange),
                )
              : null,
        );
      },
    );
  }

  void _moveFilterIntoGroup(int filterIndex, int targetIndex, int groupIndex) {
    final newFilters = List<FilterCondition>.from(widget.filters);
    final filter = newFilters[filterIndex];
    
    // 필터를 제거하고 타겟 위치에 삽입
    newFilters.removeAt(filterIndex);
    
    // 인덱스 조정
    final adjustedTargetIndex = filterIndex < targetIndex ? targetIndex - 1 : targetIndex;
    newFilters.insert(adjustedTargetIndex, filter.copyWith(groupIndex: groupIndex));
    
    // 필터 재정렬
    widget.notifier.clearFilters();
    for (final f in newFilters) {
      widget.notifier.addFilter(f);
    }
  }

  void _moveFilterOutOfGroup(int filterIndex) {
    final newFilters = List<FilterCondition>.from(widget.filters);
    final filter = newFilters[filterIndex];
    
    // 그룹에서 제거
    newFilters[filterIndex] = filter.copyWith(groupIndex: null);
    
    // 필터 업데이트
    widget.notifier.clearFilters();
    for (final f in newFilters) {
      widget.notifier.addFilter(f);
    }
  }

  void _reorderGroup(_FilterGroup draggedGroup, _FilterGroup targetGroup) {
    // 그룹 전체를 이동
    final newFilters = List<FilterCondition>.from(widget.filters);
    
    // 드래그된 그룹의 필터들 추출
    final draggedFilters = <FilterCondition>[];
    for (int i = draggedGroup.startIndex; i <= draggedGroup.endIndex; i++) {
      draggedFilters.add(newFilters[draggedGroup.startIndex]);
      newFilters.removeAt(draggedGroup.startIndex);
    }
    
    // 타겟 위치 계산
    int insertIndex;
    if (draggedGroup.startIndex < targetGroup.startIndex) {
      // 아래로 드래그한 경우: 타겟 그룹의 시작 위치에 삽입
      insertIndex = targetGroup.startIndex - (draggedGroup.endIndex - draggedGroup.startIndex + 1);
    } else {
      // 위로 드래그한 경우: 타겟 그룹의 시작 위치에 삽입
      insertIndex = targetGroup.startIndex;
    }
    
    // 타겟 위치에 삽입
    for (int i = 0; i < draggedFilters.length; i++) {
      newFilters.insert(insertIndex + i, draggedFilters[i]);
    }
    
    // 필터 재정렬
    widget.notifier.clearFilters();
    for (final filter in newFilters) {
      widget.notifier.addFilter(filter);
    }
  }

  void _removeGroup(int index) {
    final groupIndex = widget.filters[index].groupIndex;
    if (groupIndex == null) return;
    
    // 같은 그룹의 모든 필터에서 그룹 제거
    for (int i = 0; i < widget.filters.length; i++) {
      if (widget.filters[i].groupIndex == groupIndex) {
        widget.notifier.updateFilter(i, widget.filters[i].copyWith(groupIndex: null));
      }
    }
  }

  Widget _buildConditionBlock(FilterCondition filter, int index) {
    // TextEditingController 초기화
    if (!widget.filterControllers.containsKey(index)) {
      final initialValue = filter.value?.toString() ?? '';
      widget.filterControllers[index] = TextEditingController(text: initialValue);
    }

    final controller = widget.filterControllers[index]!;
    final currentValue = filter.value?.toString() ?? '';
    if (controller.text != currentValue &&
        (filter.operator != 'IS NULL' && filter.operator != 'IS NOT NULL')) {
      controller.text = currentValue;
    }

    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8,
        child: _buildConditionCard(filter, index, controller, isDragging: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildConditionCard(filter, index, controller),
      ),
      onDragStarted: () {
        setState(() => _draggedIndex = index);
      },
      onDragEnd: (_) {
        setState(() {
          _draggedIndex = null;
          _dragTargetIndex = null;
        });
      },
      child: DragTarget<int>(
        onAccept: (draggedIndex) {
          if (draggedIndex != index) {
            widget.notifier.reorderFilters(draggedIndex, index);
          }
        },
        onWillAccept: (data) {
          setState(() => _dragTargetIndex = index);
          return data != index;
        },
        onLeave: (_) {
          setState(() => _dragTargetIndex = null);
        },
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty && _dragTargetIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: isTarget
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: _buildConditionCard(filter, index, controller),
          );
        },
      ),
    );
  }

  Widget _buildConditionCard(FilterCondition filter, int index, TextEditingController controller, {bool isDragging = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDragging ? Colors.white : Colors.white,
        border: Border.all(
          color: filter.groupIndex != null ? Colors.blue.shade300 : Colors.grey.shade300,
          width: filter.groupIndex != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isDragging
            ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          
          // 열 선택
          SizedBox(
            width: 120,
            child: DropdownButton<String>(
              value: filter.columnName,
              isExpanded: true,
              items: widget.columns.map((col) {
                return DropdownMenuItem(
                  value: col['name']!,
                  child: Text(col['name']!, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (newColumn) {
                if (newColumn != null) {
                  widget.notifier.updateFilter(index, filter.copyWith(columnName: newColumn));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          
          // 연산자 선택
          SizedBox(
            width: 100,
            child: DropdownButton<String>(
              value: filter.operator,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '=', child: Text('=')),
                DropdownMenuItem(value: '!=', child: Text('!=')),
                DropdownMenuItem(value: '<', child: Text('<')),
                DropdownMenuItem(value: '>', child: Text('>')),
                DropdownMenuItem(value: '<=', child: Text('<=')),
                DropdownMenuItem(value: '>=', child: Text('>=')),
                DropdownMenuItem(value: 'LIKE', child: Text('LIKE')),
                DropdownMenuItem(value: 'IN', child: Text('IN')),
                DropdownMenuItem(value: 'NOT IN', child: Text('NOT IN')),
                DropdownMenuItem(value: 'IS NULL', child: Text('IS NULL')),
                DropdownMenuItem(value: 'IS NOT NULL', child: Text('IS NOT NULL')),
              ],
              onChanged: (newOperator) {
                if (newOperator != null) {
                  widget.notifier.updateFilter(index, filter.copyWith(operator: newOperator));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          
          // 값 입력
          if (filter.operator != 'IS NULL' && filter.operator != 'IS NOT NULL')
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Value',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (value) {
                  _applyFilterValue(index, filter, value);
                },
                onEditingComplete: () {
                  _applyFilterValue(index, filter, controller.text);
                },
              ),
            ),
          
          const SizedBox(width: 8),
          
          // 그룹 추가/제거 버튼
          IconButton(
            icon: Icon(
              filter.groupIndex != null ? Icons.group : Icons.group_outlined,
              size: 18,
              color: filter.groupIndex != null ? Colors.blue : Colors.grey,
            ),
            tooltip: filter.groupIndex != null ? '그룹 제거' : '그룹 추가',
            onPressed: () {
              if (filter.groupIndex != null) {
                widget.notifier.updateFilter(index, filter.copyWith(groupIndex: null));
              } else {
                // 새로운 그룹 인덱스 생성
                final maxGroupIndex = widget.filters
                    .where((f) => f.groupIndex != null)
                    .map((f) => f.groupIndex!)
                    .fold<int>(-1, (max, idx) => idx > max ? idx : max);
                widget.notifier.updateFilter(index, filter.copyWith(groupIndex: maxGroupIndex + 1));
              }
            },
          ),
          
          // 수정 버튼
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
            tooltip: '수정',
            onPressed: () => _showEditFilterDialog(index, filter),
          ),
          
          // 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            tooltip: '삭제',
            onPressed: () {
              widget.filterControllers[index]?.dispose();
              widget.filterControllers.remove(index);
              widget.notifier.removeFilter(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogicalOperator(int index) {
    final filter = widget.filters[index];
    final isAnd = (filter.logicalOperator ?? 'AND') == 'AND';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ToggleButtons(
        isSelected: [isAnd, !isAnd],
        onPressed: (selectedIndex) {
          final newOp = (selectedIndex == 0) ? 'AND' : 'OR';
          widget.notifier.updateFilter(index, filter.copyWith(logicalOperator: newOp));
        },
        borderRadius: BorderRadius.circular(4),
        constraints: const BoxConstraints(minHeight: 32, minWidth: 50),
        selectedColor: Colors.white,
        fillColor: Colors.blue.shade600,
        color: Colors.grey.shade700,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('AND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _applyFilterValue(int index, FilterCondition filter, String value) {
    dynamic parsedValue = value;
    if (filter.operator == 'IN' || filter.operator == 'NOT IN') {
      parsedValue = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (value.trim().isEmpty) {
      parsedValue = null;
    }
    widget.notifier.updateFilter(index, filter.copyWith(value: parsedValue));
  }

  void _showEditFilterDialog(int index, FilterCondition filter) {
    String selectedColumn = filter.columnName;
    String selectedOperator = filter.operator;
    String? valueText = filter.value?.toString() ?? '';
    String? logicalOperator = filter.logicalOperator ?? 'AND';
    int? groupIndex = filter.groupIndex;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateInDialog) => AlertDialog(
          title: const Text('조건 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedColumn,
                  decoration: const InputDecoration(labelText: '열', border: OutlineInputBorder()),
                  items: widget.columns.map((col) {
                    return DropdownMenuItem(value: col['name']!, child: Text(col['name']!));
                  }).toList(),
                  onChanged: (value) => setStateInDialog(() => selectedColumn = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedOperator,
                  decoration: const InputDecoration(labelText: '연산자', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '=', child: Text('=')),
                    DropdownMenuItem(value: '!=', child: Text('!=')),
                    DropdownMenuItem(value: '<', child: Text('<')),
                    DropdownMenuItem(value: '>', child: Text('>')),
                    DropdownMenuItem(value: '<=', child: Text('<=')),
                    DropdownMenuItem(value: '>=', child: Text('>=')),
                    DropdownMenuItem(value: 'LIKE', child: Text('LIKE')),
                    DropdownMenuItem(value: 'IN', child: Text('IN')),
                    DropdownMenuItem(value: 'NOT IN', child: Text('NOT IN')),
                    DropdownMenuItem(value: 'IS NULL', child: Text('IS NULL')),
                    DropdownMenuItem(value: 'IS NOT NULL', child: Text('IS NOT NULL')),
                  ],
                  onChanged: (value) => setStateInDialog(() => selectedOperator = value!),
                ),
                if (selectedOperator != 'IS NULL' && selectedOperator != 'IS NOT NULL') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: valueText),
                    decoration: InputDecoration(
                      labelText: selectedOperator == 'IN' || selectedOperator == 'NOT IN'
                          ? '값 (쉼표로 구분)'
                          : '값',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setStateInDialog(() => valueText = value),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: logicalOperator,
                  decoration: const InputDecoration(labelText: '논리 연산자', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'AND', child: Text('AND')),
                    DropdownMenuItem(value: 'OR', child: Text('OR')),
                  ],
                  onChanged: (value) => setStateInDialog(() => logicalOperator = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: groupIndex?.toString() ?? ''),
                  decoration: const InputDecoration(
                    labelText: '괄호 그룹 (선택사항)',
                    border: OutlineInputBorder(),
                    hintText: '같은 숫자를 입력하면 같은 그룹으로 묶임',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setStateInDialog(() {
                      groupIndex = value.isEmpty ? null : int.tryParse(value);
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                dynamic value = valueText;
                if (selectedOperator == 'IN' || selectedOperator == 'NOT IN') {
                  value = valueText?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];
                } else if (selectedOperator == 'IS NULL' || selectedOperator == 'IS NOT NULL') {
                  value = null;
                }

                widget.notifier.updateFilter(index, FilterCondition(
                  columnName: selectedColumn,
                  operator: selectedOperator,
                  value: value,
                  logicalOperator: logicalOperator,
                  groupIndex: groupIndex,
                ));
                Navigator.pop(dialogContext);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

