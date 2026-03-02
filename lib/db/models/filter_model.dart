import 'dart:math';

enum LogicalOperator { and, or }

class FilterModel {
  final String id;
  final String column;
  final String operator;
  final dynamic value;
  final LogicalOperator logicalOperator;
  final bool isNegated;
  final int openGroupCount;
  final int closeGroupCount;
  final int? groupIndex;

  FilterModel({
    String? id,
    required this.column,
    required this.operator,
    required this.value,
    this.logicalOperator = LogicalOperator.and,
    this.isNegated = false,
    this.openGroupCount = 0,
    this.closeGroupCount = 0,
    this.groupIndex,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000)}';

  FilterModel copyWith({
    String? id,
    String? column,
    String? operator,
    dynamic value,
    LogicalOperator? logicalOperator,
    bool? isNegated,
    int? openGroupCount,
    int? closeGroupCount,
    int? groupIndex,
  }) {
    return FilterModel(
      id: id ?? this.id,
      column: column ?? this.column,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      logicalOperator: logicalOperator ?? this.logicalOperator,
      isNegated: isNegated ?? this.isNegated,
      openGroupCount: openGroupCount ?? this.openGroupCount,
      closeGroupCount: closeGroupCount ?? this.closeGroupCount,
      groupIndex: groupIndex ?? this.groupIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'column': column,
      'operator': operator,
      'value': value,
      'logicalOperator': logicalOperator.name.toUpperCase(),
      'isNegated': isNegated,
      'openGroupCount': openGroupCount,
      'closeGroupCount': closeGroupCount,
      'groupIndex': groupIndex,
    };
  }

  factory FilterModel.fromMap(Map<String, dynamic> map) {
    return FilterModel(
      id: map['id'] as String?,
      column: map['column'] as String,
      operator: map['operator'] as String,
      value: map['value'],
      logicalOperator: (map['logicalOperator']?.toString().toLowerCase() == 'or')
          ? LogicalOperator.or
          : LogicalOperator.and,
      isNegated: map['isNegated'] as bool? ?? false,
      openGroupCount: map['openGroupCount'] as int? ?? 0,
      closeGroupCount: map['closeGroupCount'] as int? ?? 0,
      groupIndex: map['groupIndex'] as int?,
    );
  }
}
