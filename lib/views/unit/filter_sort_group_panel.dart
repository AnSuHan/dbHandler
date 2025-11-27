import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/LocalizationManager.dart';
import '../../stateManagement/setState/data_editing_riverpod.dart';
import 'filter_sort_group_dialog.dart';

/// 필터, 정렬, 그룹 패널 위젯
/// 앱바와 테이블 사이에 위치하여 필터, 정렬, 그룹 기능을 제공
/// 헤더를 클릭하면 팝업 다이얼로그가 열림
class FilterSortGroupPanel extends ConsumerStatefulWidget {
  final DataEditingParams dataEditingParams;

  const FilterSortGroupPanel({
    super.key,
    required this.dataEditingParams,
  });

  @override
  ConsumerState<FilterSortGroupPanel> createState() => _FilterSortGroupPanelState();
}

class _FilterSortGroupPanelState extends ConsumerState<FilterSortGroupPanel> {
  // 각 필터의 TextEditingController를 관리
  final Map<int, TextEditingController> _filterControllers = {};

  @override
  void dispose() {
    // 모든 TextEditingController 정리
    for (final controller in _filterControllers.values) {
      controller.dispose();
    }
    _filterControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataEditingProvider(widget.dataEditingParams));

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: InkWell(
        onTap: () => _showFilterSortGroupDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.filter_list),
              const SizedBox(width: 8),
              Text(
                intl.getString((l) => l.filterMenuTitle),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              // 현재 상태 표시
              if (state.filters.isNotEmpty || state.sorts.isNotEmpty || state.groupByColumns.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.filters.length} ${intl.getString((l) => l.filters)}, ${state.sorts.length} ${intl.getString((l) => l.sorts)}, ${state.groupByColumns.length} ${intl.getString((l) => l.group)}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSortGroupDialog(BuildContext context) {
    DataEditingState initialState = ref.read(dataEditingProvider(widget.dataEditingParams));

    showDialog(
      context: context,
      barrierDismissible: true, // 바깥 클릭으로 닫을 수 있음
      builder: (dialogContext) => FilterSortGroupDialog(
        dataEditingParams: widget.dataEditingParams,
        filterControllers: _filterControllers,
        onApply: () {
          // 적용 버튼 클릭 시 검증
          final notifier = ref.read(dataEditingProvider(widget.dataEditingParams).notifier);

          if (notifier.isValidSyntax()) {
            Navigator.of(dialogContext).pop(true); // 검증 성공 시 다이얼로그 닫기
          } else {
            // 검증 실패 시 SnackBar 표시
            final errorMessage = notifier.getValidationError() ?? intl.getString((l) => l.filterConditionError);
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onCancel: () {
          // 취소 버튼 클릭 시
          final notifier = ref.read(dataEditingProvider(widget.dataEditingParams).notifier);
          notifier.refreshData(overwriteState: initialState);
          Navigator.of(dialogContext).pop(false);
        },
        onDispose: () {
          // Dialog가 닫힐 때 Controller 정리 (실제로는 dispose에서 처리)
        },
      ),
    ).then((result) {
      // dialog가 닫힌 후 호출됨 (x버튼, 바깥 클릭 모두)
      final notifier = ref.read(dataEditingProvider(widget.dataEditingParams).notifier);
      debugPrint('[_showFilterSortGroupDialog] result: $result');
      if(result != null && result == true) {
        // 적용 버튼으로 정상 종료 (이미 검증 완료)
        notifier.refreshData();
      } else if (result ==  null || result == false) {
        // esc 종료 시: 덮어쓰기 해서 마지막 저장 상태로 덮어쓰기
        notifier.refreshData(overwriteState: initialState);
      }
    });
  }
}
