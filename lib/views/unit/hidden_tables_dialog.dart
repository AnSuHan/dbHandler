import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../stateManagement/getx/TableSelectionController.dart';

/// 테이블 숨김 설정 다이얼로그
Future<void> showHiddenTablesDialog({
  required BuildContext context,
  required TableSelectionController controller,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => _HiddenTablesDialog(controller: controller),
  );
}

class _HiddenTablesDialog extends StatelessWidget {
  final TableSelectionController controller;

  const _HiddenTablesDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() {
                      final visible = controller.visibleTableCount;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '테이블 숨김 설정',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '테이블 $visible개',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      );
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 안내 텍스트
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '체크한 항목은 목록에서 숨겨집니다. 스키마를 숨기면 해당 스키마의 모든 테이블이 숨겨집니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            // 목록
            Expanded(
              child: Obx(() {
                final realTables = controller.tables;
                final joinDefs = controller.joinDefinitions;
                final schemas = realTables
                    .map((t) => t['schema'] as String? ?? 'public')
                    .toSet()
                    .toList()
                  ..sort();

                if (realTables.isEmpty && joinDefs.isEmpty) {
                  return const Center(child: Text('테이블이 없습니다.'));
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // ── 스키마 섹션 ──────────────────────────────
                    if (schemas.length > 1 || (schemas.length == 1 && schemas.first != 'public')) ...[
                      _SectionHeader(
                        icon: Icons.schema_outlined,
                        label: '스키마',
                        count: schemas.length,
                        hiddenCount: controller.hiddenSchemas.length,
                        onHideAll: () {
                          for (final s in schemas) {
                            if (!controller.hiddenSchemas.contains(s)) {
                              controller.toggleSchemaVisibility(s);
                            }
                          }
                        },
                        onShowAll: () {
                          for (final s in schemas) {
                            if (controller.hiddenSchemas.contains(s)) {
                              controller.toggleSchemaVisibility(s);
                            }
                          }
                        },
                      ),
                      ...schemas.map((schema) {
                        final isHidden = controller.hiddenSchemas.contains(schema);
                        final tableCount = realTables
                            .where((t) => (t['schema'] as String? ?? 'public') == schema)
                            .length;
                        return _TableCheckTile(
                          name: schema,
                          subtitle: '테이블 $tableCount개',
                          isHidden: isHidden,
                          icon: Icons.schema_outlined,
                          onTap: () => controller.toggleSchemaVisibility(schema),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    // ── 실제 테이블 섹션 ─────────────────────────
                    if (realTables.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.table_chart,
                        label: '실제 테이블',
                        count: realTables.length,
                        hiddenCount: realTables
                            .where((t) =>
                                controller.hiddenRealTables.contains(t['name'] as String) ||
                                controller.hiddenSchemas.contains(t['schema'] as String? ?? 'public'))
                            .length,
                        onHideAll: () {
                          for (final t in realTables) {
                            final name = t['name'] as String;
                            if (!controller.hiddenRealTables.contains(name)) {
                              controller.toggleRealTableVisibility(name);
                            }
                          }
                        },
                        onShowAll: () {
                          for (final t in realTables) {
                            final name = t['name'] as String;
                            if (controller.hiddenRealTables.contains(name)) {
                              controller.toggleRealTableVisibility(name);
                            }
                          }
                        },
                      ),
                      ...realTables.map((t) {
                        final name = t['name'] as String;
                        final schema = t['schema'] as String? ?? 'public';
                        final isHiddenBySchema = controller.hiddenSchemas.contains(schema);
                        final isHidden = controller.hiddenRealTables.contains(name) || isHiddenBySchema;
                        return _TableCheckTile(
                          name: name,
                          subtitle: isHiddenBySchema ? '스키마($schema) 숨김' : null,
                          isHidden: isHidden,
                          dimmed: isHiddenBySchema,
                          icon: Icons.table_chart,
                          onTap: isHiddenBySchema ? null : () => controller.toggleRealTableVisibility(name),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    // ── JOIN 뷰 섹션 ─────────────────────────────
                    if (joinDefs.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.join_inner,
                        label: '가상 테이블 (JOIN 뷰)',
                        count: joinDefs.length,
                        hiddenCount: controller.hiddenJoinViews.length,
                        onHideAll: () {
                          for (final j in joinDefs) {
                            if (!controller.hiddenJoinViews.contains(j.name)) {
                              controller.toggleJoinViewVisibility(j.name);
                            }
                          }
                        },
                        onShowAll: () {
                          for (final j in joinDefs) {
                            if (controller.hiddenJoinViews.contains(j.name)) {
                              controller.toggleJoinViewVisibility(j.name);
                            }
                          }
                        },
                      ),
                      ...joinDefs.map((def) {
                        final isHidden = controller.hiddenJoinViews.contains(def.name);
                        return _TableCheckTile(
                          name: def.name,
                          subtitle: def.allTables.join(' + '),
                          isHidden: isHidden,
                          icon: Icons.join_inner,
                          onTap: () => controller.toggleJoinViewVisibility(def.name),
                        );
                      }),
                    ],
                  ],
                );
              }),
            ),
            // 하단 버튼
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('내보내기'),
                    onPressed: () => controller.exportHiddenConfig(),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('가져오기'),
                    onPressed: () => controller.importHiddenConfig(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int hiddenCount;
  final VoidCallback onHideAll;
  final VoidCallback onShowAll;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.hiddenCount,
    required this.onHideAll,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label  (${count - hiddenCount}개)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: onHideAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('모두 숨기기', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('모두 표시', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _TableCheckTile extends StatelessWidget {
  final String name;
  final String? subtitle;
  final bool isHidden;
  final bool dimmed;
  final IconData icon;
  final VoidCallback? onTap;

  const _TableCheckTile({
    required this.name,
    this.subtitle,
    required this.isHidden,
    this.dimmed = false,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isHidden ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 20, color: dimmed ? Colors.grey : null),
          title: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              decoration: isHidden ? TextDecoration.lineThrough : null,
              color: dimmed ? Colors.grey : null,
            ),
          ),
          subtitle: subtitle != null
              ? Text(subtitle!, style: TextStyle(fontSize: 12, color: dimmed ? Colors.grey : null))
              : null,
          trailing: onTap != null
              ? Checkbox(
                  value: isHidden,
                  onChanged: (_) => onTap!(),
                  activeColor: Colors.red,
                )
              : const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }
}
