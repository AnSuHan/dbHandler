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
        ...state.filters.asMap().entries.map((entry) {
          final index = entry.key;
          final filter = entry.value;
          return _buildFilterItem(filter, index, notifier, state);
        }),
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => notifier.removeSort(index),
                ),
              ],
            ),
          );
        }),
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
        ...state.groupByColumns.map((columnName) {
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
                const Icon(Icons.group, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(columnName, style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => notifier.removeGroupByColumn(columnName),
                ),
              ],
            ),
          );
        }),
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
    String? logicalOperator = 'AND';
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
                DropdownButtonFormField<String>(
                  value: logicalOperator,
                  decoration: const InputDecoration(labelText: 'Logical Operator', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'AND', child: Text('AND')),
                    DropdownMenuItem(value: 'OR', child: Text('OR')),
                  ],
                  onChanged: (value) => setStateInDialog(() => logicalOperator = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Group Index (optional, for parentheses)',
                    border: OutlineInputBorder(),
                    hintText: 'Leave empty or enter number',
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

