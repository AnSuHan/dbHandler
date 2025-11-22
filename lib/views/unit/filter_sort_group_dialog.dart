import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';

/// 필터, 정렬, 그룹 다이얼로그 위젯
/// 팝업 형식으로 필터, 정렬, 그룹 기능을 제공
class FilterSortGroupDialog extends ConsumerStatefulWidget {
  final DataEditingParams dataEditingParams;
  final Map<int, TextEditingController> filterControllers;
  final VoidCallback? onDispose;
  final VoidCallback? onApply;
  final VoidCallback? onCancel;

  const FilterSortGroupDialog({
    super.key,
    required this.dataEditingParams,
    required this.filterControllers,
    this.onDispose,
    this.onApply,
    this.onCancel,
  });

  @override
  ConsumerState<FilterSortGroupDialog> createState() => _FilterSortGroupDialogState();
}

class _FilterSortGroupDialogState extends ConsumerState<FilterSortGroupDialog> {
  // 필터 조건 선택 관리
  Set<int> selectedBlockIndices = {};
  bool multiSelectMode = false;
  int? lastSelectedIndex;
  bool rangeSelectMode = false;

  // 키보드 감지용 FocusNode
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    widget.onDispose?.call();
    super.dispose();
  }

  /// 키보드 입력 처리
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // ESC 눌렀을 때 다이얼로그 닫기(정상 종료 플래그 false)
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(false); // ESC로 종료시 false 반환
      return KeyEventResult.handled;
    }

    final isCtrlPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);
    final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isCtrlPressed && !isShiftPressed) {
        multiSelectMode = true;
        rangeSelectMode = false;
      } else if (!isCtrlPressed && isShiftPressed) {
        multiSelectMode = false;
        rangeSelectMode = true;
      } else {
        multiSelectMode = false;
        rangeSelectMode = false;
      }
    });

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataEditingProvider(widget.dataEditingParams));
    final notifier = ref.read(dataEditingProvider(widget.dataEditingParams).notifier);

    return Focus(
      focusNode: focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Dialog(
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
                    icon: const Icon(Icons.save),
                    onPressed: widget.onApply ?? () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
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
              icon: const Icon(Icons.group, size: 18),
              label: const Text('Add (, )'),
              onPressed: () => notifier.addOpenParenthesis(),
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

  Widget _buildExcelStyleFilterBuilder(DataEditingState state, DataEditingNotifier notifier) {
    // 필터와 괄호, AND/OR 블럭을 하나의 리스트로 관리
    List<Map<String, dynamic>> blocks = _buildFilterBlockList(state);
    debugPrint("[_buildExcelStyleFilterBuilder] blocks.asMap().entries: ${blocks.asMap().entries}");

    if ((state.filters.isEmpty && (state.filterBlocks?.isEmpty ?? true)) || blocks.isEmpty) {
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
          debugPrint("[_buildExcelStyleFilterBuilder] index: $index, block: $block");

          return Container(
            key: ValueKey('block_$index'),
            child: _buildSelectableBlock(
              index: index,
              child: _buildDraggableBlock(
                block: block,
                blockIndex: index,
                state: state,
                notifier: notifier,
              ),
            ),
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

      // openGroupCount 만큼 여는 괄호 추가
      final openCount = filter.openGroupCount ?? 0;
      for (int j = 0; j < openCount; j++) {
        blocks.add({'type': 'openparen'});
      }

      blocks.add({'type': 'filter', 'index': i});

      // closeGroupCount 만큼 닫는 괄호 추가
      final closeCount = filter.closeGroupCount ?? 0;
      for (int j = 0; j < closeCount; j++) {
        blocks.add({'type': 'closeparen'});
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

  Widget _buildSelectableBlock({required int index, required Widget child}) {
    final isSelected = selectedBlockIndices.contains(index);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _onBlockTap(index),
      onLongPress: () => _onBlockLongPress(index),
      onDoubleTap: () => _onBlockDoubleTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.transparent,
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      ),
    );
  }

  Widget _buildDraggableBlock({
    required Map<String, dynamic> block,
    required int blockIndex,
    required DataEditingState state,
    required DataEditingNotifier notifier,
  })
  {
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
  })
  {
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
                    flex: 1,
                    // not 토글
                    child: Container(
                      decoration: BoxDecoration(
                        color: filter.isNegated ? Colors.red.shade50 : Colors.transparent,
                        border: Border.all(
                          color: filter.isNegated ? Colors.red.shade300 : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            filter.isNegated = !filter.isNegated;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                filter.isNegated ? Icons.block : Icons.check_circle_outline,
                                size: 20,
                                color: filter.isNegated ? Colors.red.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'NOT',
                                style: TextStyle(
                                  color: filter.isNegated ? Colors.red.shade700 : Colors.grey.shade400,
                                  fontWeight: filter.isNegated ? FontWeight.bold : FontWeight.w300,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: filter.columnName,
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
                      initialValue: filter.operator,
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)
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
        onAcceptWithDetails: (DragTargetDetails<int> details) {
          final draggedIndex = details.data;
          if (draggedIndex != index) {
            notifier.reorderSorts(draggedIndex, index);
          }
        },
        onWillAcceptWithDetails: (DragTargetDetails<int> details) {
          return details.data != index;
        },
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)
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
        onAcceptWithDetails: (DragTargetDetails<int> details) {
          final draggedIndex = details.data;
          if (draggedIndex != index) {
            notifier.reorderGroupBy(draggedIndex, index);
          }
        },
        onWillAcceptWithDetails: (DragTargetDetails<int> details) {
          return details.data != index;
        },
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

                    // openGroupCount 만큼 괄호 여는 텍스트 추가
                    final openParens = List.filled(filter.openGroupCount ?? 0, '(').join();

                    // NOT 표시
                    final notPrefix = filter.isNegated ? 'NOT ' : '';

                    // 닫는 괄호 텍스트
                    final closeParens = List.filled(filter.closeGroupCount ?? 0, ')').join();

                    final valueDisplay = filter.operator == 'IS NULL' || filter.operator == 'IS NOT NULL'
                        ? ''
                        : filter.operator == 'IN' || filter.operator == 'NOT IN'
                        ? ' (${(filter.value as List).join(', ')})'
                        : ' ${filter.value}';
                    final logicalOp = index < state.filters.length - 1
                        ? ' ${filter.logicalOperator ?? 'AND'}'
                        : '';

                    return Text('  $openParens$notPrefix${filter.columnName} ${filter.operator}$valueDisplay$closeParens$logicalOp');
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
    String? logicalOperator = state.filters.isEmpty ? null : 'AND';
    int openGroupCount = 0;
    int closeGroupCount = 0;
    bool isNegated = false; // 새 필터의 isNegated 상태

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateInDialog) => AlertDialog(
          title: const Text('Add Filter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // NOT 토글
                Container(
                  decoration: BoxDecoration(
                    color: isNegated ? Colors.red.shade50 : Colors.transparent,
                    border: Border.all(
                      color: isNegated ? Colors.red.shade300 : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: () {
                      setStateInDialog(() => isNegated = !isNegated);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isNegated ? Icons.block : Icons.check_circle_outline,
                            size: 20,
                            color: isNegated ? Colors.red.shade700 : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NOT',
                            style: TextStyle(
                              color: isNegated ? Colors.red.shade700 : Colors.grey.shade400,
                              fontWeight: isNegated ? FontWeight.bold : FontWeight.w300,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedColumn,
                  decoration: const InputDecoration(labelText: 'Column', border: OutlineInputBorder()),
                  items: state.columns.map((col) {
                    return DropdownMenuItem(value: col['name']!, child: Text(col['name']!));
                  }).toList(),
                  onChanged: (value) => setStateInDialog(() => selectedColumn = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedOperator,
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
                // const SizedBox(height: 16),
                // Row(
                //   children: [
                //     Expanded(
                //       child: TextField(
                //         decoration: const InputDecoration(
                //           labelText: 'Opening brackets count (optional)',
                //           border: OutlineInputBorder(),
                //           hintText: '0 or more',
                //         ),
                //         keyboardType: TextInputType.number,
                //         onChanged: (value) {
                //           setStateInDialog(() {
                //             openGroupCount = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                //           });
                //         },
                //       ),
                //     ),
                //     const SizedBox(width: 12),
                //     Expanded(
                //       child: TextField(
                //         decoration: const InputDecoration(
                //           labelText: 'Closing brackets count (optional)',
                //           border: OutlineInputBorder(),
                //           hintText: '0 or more',
                //         ),
                //         keyboardType: TextInputType.number,
                //         onChanged: (value) {
                //           setStateInDialog(() {
                //             closeGroupCount = value.isEmpty ? 0 : int.tryParse(value) ?? 0;
                //           });
                //         },
                //       ),
                //     ),
                //   ],
                // ),
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

                // 첫 번째 필터면 그대로 추가, 두 번째 이후면 이전 필터 업데이트 후 추가
                if (state.filters.isEmpty) {
                  // 첫 번째 필터 추가 (logicalOperator는 null)
                  notifier.addFilter(FilterCondition(
                    columnName: selectedColumn,
                    operator: selectedOperator,
                    value: value,
                    logicalOperator: null,
                    openGroupCount: openGroupCount,
                    closeGroupCount: closeGroupCount,
                    isNegated: isNegated,
                  ));
                } else {
                  // 두 번째 이후 필터: 이전 마지막 필터에 논리 연산자 추가
                  final lastFilter = state.filters.last;
                  notifier.updateFilter(
                    state.filters.length - 1,
                    lastFilter.copyWith(logicalOperator: logicalOperator),
                  );

                  // 새 필터 추가 (logicalOperator는 null)
                  notifier.addFilter(FilterCondition(
                    columnName: selectedColumn,
                    operator: selectedOperator,
                    value: value,
                    logicalOperator: null,
                    openGroupCount: openGroupCount,
                    closeGroupCount: closeGroupCount,
                    isNegated: isNegated,
                  ));
                }
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
                initialValue: selectedColumn,
                decoration: const InputDecoration(labelText: 'Column', border: OutlineInputBorder()),
                items: state.columns.map((col) {
                  return DropdownMenuItem(value: col['name']!, child: Text(col['name']!));
                }).toList(),
                onChanged: (value) => setStateInDialog(() => selectedColumn = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                initialValue: ascending,
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
            initialValue: selectedColumn,
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

  //============================================================================
  //============================= 블럭 선택 로직 =================================
  //============================================================================
  void _onBlockTap(int index) {
    if (multiSelectMode) {
      // 비연속 다중 선택 모드 : 클릭한 블럭만 추가 또는 제거
      setState(() {
        _toggleSelection(index);
        if (selectedBlockIndices.isEmpty) multiSelectMode = false;
        lastSelectedIndex = index;
      });
    } else if (rangeSelectMode && lastSelectedIndex != null) {
      // shift + 클릭 or 더블클릭 범위 선택 모드
      int start = lastSelectedIndex!;
      int end = index;
      if (start > end) {
        final temp = start;
        start = end;
        end = temp;
      }
      setState(() {
        selectedBlockIndices = Set.from(List.generate(end - start + 1, (i) => start + i));
      });
    } else {
      // 단일 선택 모드 - 이미 선택된 블럭 또 클릭 시 초기 상태로
      setState(() {
        if (selectedBlockIndices.length == 1 && selectedBlockIndices.contains(index)) {
          selectedBlockIndices.clear();
          lastSelectedIndex = null;
          rangeSelectMode = false;
        } else {
          selectedBlockIndices = {index};
          lastSelectedIndex = index;
          rangeSelectMode = false;
        }
      });
    }
  }

  void _onBlockLongPress(int index) {
    setState(() {
      if (multiSelectMode) {
        // 이미 multiSelectMode면 해제하고 초기 상태로
        multiSelectMode = false;
        selectedBlockIndices.clear();
        lastSelectedIndex = null;
        rangeSelectMode = false;
      } else {
        // 일반 또는 double click 상태에서 multiSelectMode로 전환
        multiSelectMode = true;
        selectedBlockIndices = {index};
        lastSelectedIndex = index;
        rangeSelectMode = false;
      }
    });
  }

  void _onBlockDoubleTap(int index) {
    setState(() {
      if (rangeSelectMode) {
        // 이미 rangeSelectMode면 해제, 초기 상태로
        rangeSelectMode = false;
        selectedBlockIndices.clear();
        lastSelectedIndex = null;
        multiSelectMode = false;
      } else {
        // 일반 또는 multiSelectMode 상태에서 rangeSelectMode로 전환
        rangeSelectMode = true;
        selectedBlockIndices = {index};
        lastSelectedIndex = index;
        multiSelectMode = false;
      }
    });
  }

  void _toggleSelection(int index) {
    if (selectedBlockIndices.contains(index)) {
      selectedBlockIndices.remove(index);
    } else {
      selectedBlockIndices.add(index);
    }
  }
}

