import 'package:db_handler/stateManagement/riverpod/data_editing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CellItem extends ConsumerWidget {
  const CellItem({
    super.key,
    required this.args,
    required this.rowIndex,
    required this.columnIndex,
    required this.onEditRequested,
  });

  final DataEditingArgs args;
  final int rowIndex;
  final int columnIndex;
  final VoidCallback onEditRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = ref.watch(
      dataEditingProvider(args).select((state) {
        final widths = state.columnWidths;
        final targetIndex = columnIndex + 1;
        if (targetIndex < widths.length) {
          return widths[targetIndex];
        }
        return 120.0;
      }),
    );

    final value = ref.watch(
      dataEditingProvider(args).select((state) {
        if (rowIndex >= state.rows.length || columnIndex >= state.columns.length) {
          return '';
        }
        final result = state.cellValue(rowIndex, columnIndex);
        return result?.toString() ?? 'NULL';
      }),
    );

    final isRowSelected = ref.watch(
      dataEditingSelectionProvider(args).select((selection) => selection.isRowSelected(rowIndex)),
    );

    final isColumnSelected = ref.watch(
      dataEditingSelectionProvider(args).select((selection) => selection.isColumnSelected(columnIndex)),
    );

    final isCellSelected = ref.watch(
      dataEditingSelectionProvider(args).select((selection) => selection.isCellSelected(rowIndex, columnIndex)),
    );

    Color? cellColor;
    if (isCellSelected) {
      cellColor = Colors.green.withOpacity(0.4);
    } else if (isRowSelected || isColumnSelected) {
      cellColor = Colors.blue.withOpacity(0.2);
    }

    return GestureDetector(
      onTap: () => ref.read(dataEditingSelectionProvider(args).notifier).toggleCell(rowIndex, columnIndex),
      onDoubleTap: () {
        ref.read(dataEditingSelectionProvider(args).notifier).selectCell(rowIndex, columnIndex);
        onEditRequested();
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cellColor,
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Text(
          value,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
