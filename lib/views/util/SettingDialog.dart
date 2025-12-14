import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../stateManagement/bloc/setting_bloc.dart';
import '../../l10n/LocalizationManager.dart';
import '../../gen/app_localizations.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context, listen: false);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    intl.getString((l) => l.settings),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 언어 설정
                    _SectionTitle(title: intl.getString((l) => l.language)),
                    const SizedBox(height: 8),
                    StreamBuilder<Locale>(
                      stream: settingsBloc.localeStream,
                      initialData: settingsBloc.currentLocale,
                      builder: (context, snapshot) {
                        final currentLocale = snapshot.data ?? const Locale('en');
                        return _LanguageSelector(
                          currentLocale: currentLocale,
                          onChanged: (locale) async {
                            await settingsBloc.setLocale(locale);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 테마 설정
                    _SectionTitle(title: intl.getString((l) => l.theme)),
                    const SizedBox(height: 8),
                    StreamBuilder<ThemeMode>(
                      stream: settingsBloc.themeModeStream,
                      initialData: settingsBloc.currentThemeMode,
                      builder: (context, snapshot) {
                        final currentThemeMode = snapshot.data ?? ThemeMode.system;
                        return _ThemeSelector(
                          currentThemeMode: currentThemeMode,
                          onChanged: (themeMode) async {
                            await settingsBloc.setThemeMode(themeMode);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 즐겨찾기 관리
                    _SectionTitle(title: intl.getString((l) => l.favorites)),
                    const SizedBox(height: 8),
                    _FavoritesSection(settingsBloc: settingsBloc),
                    const SizedBox(height: 24),

                    // 백업 및 복구
                    _SectionTitle(title: intl.getString((l) => l.backupAndRestore)),
                    const SizedBox(height: 8),
                    _BackupRestoreSection(settingsBloc: settingsBloc),
                    const SizedBox(height: 24),

                    // 위험 영역
                    _SectionTitle(
                      title: intl.getString((l) => l.dangerZone),
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    _DangerZoneSection(settingsBloc: settingsBloc),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionTitle({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: color ?? Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final Locale currentLocale;
  final Function(Locale) onChanged;

  const _LanguageSelector({
    required this.currentLocale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final languages = LocalizationManager().languageWithFlag;

    return Card(
      child: Column(
        children: languages.map((lang) {
          final isSelected = currentLocale.languageCode == lang['code'];
          return ListTile(
            leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
            title: Text(lang['name']!),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            selected: isSelected,
            onTap: () => onChanged(Locale(lang['code']!)),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onChanged;

  const _ThemeSelector({
    required this.currentThemeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themes = [
      {
        'mode': ThemeMode.system,
        'name': intl.getString((l) => l.systemTheme),
        'icon': Icons.settings_suggest
      },
      {
        'mode': ThemeMode.light,
        'name': intl.getString((l) => l.lightTheme),
        'icon': Icons.light_mode
      },
      {
        'mode': ThemeMode.dark,
        'name': intl.getString((l) => l.darkTheme),
        'icon': Icons.dark_mode
      },
    ];

    return Card(
      child: Column(
        children: themes.map((theme) {
          final mode = theme['mode'] as ThemeMode;
          final isSelected = currentThemeMode == mode;
          return ListTile(
            leading: Icon(theme['icon'] as IconData),
            title: Text(theme['name'] as String),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            selected: isSelected,
            onTap: () => onChanged(mode),
          );
        }).toList(),
      ),
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final SettingsBloc settingsBloc;

  const _FavoritesSection({required this.settingsBloc});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          StreamBuilder<List<String>>(
            stream: settingsBloc.favoriteServersStream,
            initialData: settingsBloc.favoriteServers,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(intl.getString((l) => l.favoriteServers)),
                trailing: Text('$count', style: const TextStyle(fontSize: 16)),
              );
            },
          ),
          const Divider(height: 1),
          StreamBuilder<Map<String, List<String>>>(
            stream: settingsBloc.favoriteDatabasesStream,
            initialData: settingsBloc.favoriteDatabases,
            builder: (context, snapshot) {
              final count = snapshot.data?.values
                  .fold<int>(0, (sum, list) => sum + list.length) ?? 0;
              return ListTile(
                leading: const Icon(Icons.folder_special, color: Colors.blue),
                title: Text(intl.getString((l) => l.favoriteDatabases)),
                trailing: Text('$count', style: const TextStyle(fontSize: 16)),
              );
            },
          ),
          const Divider(height: 1),
          StreamBuilder<Map<String, List<String>>>(
            stream: settingsBloc.favoriteTablesStream,
            initialData: settingsBloc.favoriteTables,
            builder: (context, snapshot) {
              final count = snapshot.data?.values
                  .fold<int>(0, (sum, list) => sum + list.length) ?? 0;
              return ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: Text(intl.getString((l) => l.favoriteTables)),
                trailing: Text('$count', style: const TextStyle(fontSize: 16)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BackupRestoreSection extends StatelessWidget {
  final SettingsBloc settingsBloc;

  const _BackupRestoreSection({required this.settingsBloc});

  @override
  Widget build(BuildContext context) {
    // 메시지 표시를 위한 ScaffoldMessenger 참조
    final messenger = ScaffoldMessenger.of(context);

    // BLoC의 비동기 호출을 처리하고 사용자에게 결과를 알려주는 래퍼 함수
    // import 로직을 위한 헬퍼 함수 (이전 답변과 동일)
    Future<void> _handleImportAction() async {
      messenger.showSnackBar(
        SnackBar(
          content: Text(intl.getString((l) => l.processing)),
          duration: const Duration(seconds: 1),
        ),
      );
      try {
        await settingsBloc.importSettingsFromFile();
        messenger.showSnackBar(
          SnackBar(
            content: Text(intl.getString((l) => l.settingsImportedSuccess)),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(intl.getString((l) => l.settingsImportedFail)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return Card(
      child: Column(
        children: [
          // 설정 내보내기 (Export)
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: Text(intl.getString((l) => l.exportSettings)),
            subtitle: Text(intl.getString((l) => l.exportSettingsDescription)),
            onTap: () async {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(intl.getString((l) => l.processing)),
                  duration: const Duration(seconds: 1),
                ),
              );
              try {
                // BLoC에서 파일 경로를 받아옵니다.
                final filePath = await settingsBloc.exportSettingsToFile();
                messenger.hideCurrentSnackBar(); // "처리 중" 스낵바 숨김

                if (context.mounted) {
                  // 성공 다이얼로그에 파일 경로를 전달
                  _showExportSuccessDialog(context, filePath);
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(intl.getString((l) => l.settingsExportedFail)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          // 설정 불러오기 (Import/Restore) - 기존 로직 유지
          ListTile(
            leading: const Icon(Icons.upload, color: Colors.orange),
            title: Text(intl.getString((l) => l.importSettings)),
            subtitle: Text(intl.getString((l) => l.importSettingsDescription)),
            onTap: _handleImportAction,
          ),
        ],
      ),
    );
  }

  /// 성공 시 파일 경로를 표시하는 다이얼로그 함수
  void _showExportSuccessDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.exportSuccessTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intl.getString((l) => l.settingsExportedSuccess)),
            const SizedBox(height: 10),

            // 저장된 파일 경로 헤더 및 복사 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  intl.getString((l) => l.exportedFilePath),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // --- 복사 버튼 추가 ---
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: intl.getString((l) => l.copyPath), // '경로 복사' 툴팁 필요
                  onPressed: () {
                    // 클립보드에 경로 복사
                    Clipboard.setData(ClipboardData(text: filePath));

                    // 복사 성공 스낵바 표시 (다이얼로그 위에 표시)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(intl.getString((l) => l.copySuccess)), // '복사 완료' 메시지 필요
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                // ---------------------
              ],
            ),

            const SizedBox(height: 5),
            // 경로를 표시하는 부분
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity, // 가로 전체 너비 사용
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText( // 사용자가 경로를 복사할 수 있도록 SelectableText 사용
                filePath,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.ok)),
          ),
        ],
      ),
    );
  }
}

class _DangerZoneSection extends StatelessWidget {
  final SettingsBloc settingsBloc;

  const _DangerZoneSection({required this.settingsBloc});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: Text(
          intl.getString((l) => l.clearAllSettings),
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        onTap: () => _showClearConfirmDialog(context),
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(intl.getString((l) => l.warning)),
        content: Text(intl.getString((l) => l.clearAllSettingsConfirm)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(intl.getString((l) => l.cancel)),
          ),
          ElevatedButton(
            onPressed: () async {
              await settingsBloc.clearAllSettings();
              if (context.mounted) {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(intl.getString((l) => l.settingsCleared)),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(intl.getString((l) => l.clear)),
          ),
        ],
      ),
    );
  }
}