// lib/stateManagement/mobx/mobx_store.dart
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:db_handler/sqflite/models/server_model.dart';
import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/db/postgres_handler.dart';

part 'mobx_store.g.dart';

class ServerSelectionStore = _ServerSelectionStore with _$ServerSelectionStore;

abstract class _ServerSelectionStore with Store {
  // DB 타입별 핸들러들을 저장하는 맵
  Map<String, DatabaseHandler> dbHandlers = {};
  List<String> supportDBType = ['postgresql'];

  @observable
  ObservableList<ServerModel> servers = ObservableList<ServerModel>();

  @observable
  bool isLoading = true;

  @observable
  String? error;

  @observable
  bool showAddForm = false;

  @observable
  bool isTestServer = false;

  _ServerSelectionStore() {
    // 각 DB 타입별 핸들러를 초기화
    for(String dbType in supportDBType) {
      switch(dbType) {
        case 'postgresql':
          dbHandlers[dbType] = PostgresHandler();
          break;
        default:
          continue;
      }
    }

    loadServers();
  }

  @action
  Future<void> loadServers() async {
    isLoading = true;
    error = null;
    try {
      print('🔍 loadServers 시작 - 모든 dbHandler 대상');
      List<ServerModel> allServers = [];

      if (dbHandlers.isEmpty) {
        print('⚠️ dbHandlers가 비어 있음 - 빈 목록 반환');
        servers = ObservableList<ServerModel>();
      } else {
        for (var entry in dbHandlers.entries) {
          final dbType = entry.key;
          final handler = entry.value;
          print('📥 $dbType 핸들러로 서버 목록 로드 시도');
          final loadedServers = await handler.getServers();
          allServers.addAll(loadedServers);
          print('✅ $dbType 서버 로드 성공: ${loadedServers.length}개');
        }
        servers = ObservableList.of(allServers);
      }
    } catch (e) {
      error = e.toString();
      print('❌ 서버 로드 오류: $e');
      servers = ObservableList<ServerModel>();
    } finally {
      isLoading = false;
      print('🏁 loadServers 완료 - 서버 개수: ${servers.length}');
    }
  }

  @action
  void toggleAddForm() {
    showAddForm = !showAddForm;
  }

  @action
  void setIsTestServer(bool value) {
    isTestServer = value;
  }

  @action
  Future<void> addServer({
    required String name,
    required String host,
    required String port,
    required String type,
    required Function(String, {Color? color}) showSnackbar,
    required TextEditingController nameController,
    required TextEditingController hostController,
    required TextEditingController portController,
    required TextEditingController typeController,
    required Future<ServerModel?> Function(ServerModel, {bool isTest, bool isInitialSetup}) showAuthDialog,
  }) async {
    print('🆕 addServer 시작 - name: $name, host: $host, port: $port, type: $type');

    if (name.isEmpty || host.isEmpty || port.isEmpty) {
      print('⚠️ 필수 필드 누락');
      showSnackbar('이름, 호스트, 포트는 필수입니다.', color: Colors.red);
      return;
    }

    final address = '$host:$port';
    final dbType = type.isEmpty ? 'PostgreSQL' : type;

    final newServer = ServerModel(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      address: address,
      type: dbType,
      isConnected: false,
    );

    print('📦 새 서버 생성: ${newServer.toMap()}');

    ServerModel? serverToAdd = newServer;

    if (isTestServer) {
      print('🧪 테스트 서버 - 인증 다이얼로그 표시');
      serverToAdd = await showAuthDialog(newServer, isTest: true, isInitialSetup: true);
    }

    if (serverToAdd == null) {
      print('⚠️ serverToAdd가 null - 추가 취소');
      return;
    }

    try {
      print('💾 서버 저장 시도 - dbHandler: ${dbHandler != null ? "존재" : "null"}');

      if (dbHandler != null) {
        print('📝 dbHandler로 서버 저장');
        await dbHandler!.insertServer(serverToAdd);
      } else {
        // dbHandler가 없으면 메모리에만 추가
        print('⚠️ dbHandler가 null - 메모리에만 추가');
        servers.add(serverToAdd);
      }

      print('🔄 서버 목록 다시 로드');
      await loadServers();
      showSnackbar('서버가 추가되었습니다.', color: Colors.green);

      nameController.clear();
      hostController.clear();
      portController.clear();
      typeController.clear();
      print('✅ 서버 추가 완료');
    } catch (e) {
      showSnackbar('서버 추가 실패: $e', color: Colors.red);
      print('❌ 서버 추가 오류: $e');
    }
  }

  @action
  Future<void> updateServer(
      ServerModel server,
      Function(String, {Color? color}) showSnackbar,
      ) async {
    try {
      if (dbHandler != null) {
        await dbHandler!.updateServer(server);
      } else {
        // dbHandler가 없으면 메모리에서 업데이트
        final index = servers.indexWhere((s) => s.id == server.id);
        if (index != -1) {
          servers[index] = server;
        }
      }

      await loadServers();
      showSnackbar('서버 정보가 업데이트되었습니다.', color: Colors.green);
    } catch (e) {
      showSnackbar('서버 업데이트 실패: $e', color: Colors.red);
      print('서버 업데이트 오류: $e');
    }
  }

  @action
  Future<void> deleteServer(
      ServerModel server,
      Function(String, {Color? color}) showSnackbar,
      ) async {
    try {
      if (dbHandler != null && server.id != null) {
        await dbHandler!.deleteServer(server.id!);
      } else {
        // dbHandler가 없으면 메모리에서 삭제
        servers.removeWhere((s) => s.id == server.id);
      }

      await loadServers();
      showSnackbar('서버가 삭제되었습니다.', color: Colors.green);
    } catch (e) {
      showSnackbar('서버 삭제 실패: $e', color: Colors.red);
      print('서버 삭제 오류: $e');
    }
  }

  /// PostgreSQL 서버에 연결하여 DatabaseHandler 초기화
  /// 이 메서드는 서버 선택 시 호출됨
  @action
  void initializeDatabaseHandler(ServerModel serverInfo, {String? databaseName}) {
    print('🔧 initializeDatabaseHandler 호출 - type: ${serverInfo.type}');
    if (serverInfo.type.toLowerCase() == 'postgresql') {
      dbHandler = PostgresHandler(serverInfo, databaseName: databaseName);
      print('✅ PostgresHandler 초기화 완료');
    } else {
      print('⚠️ PostgreSQL이 아님 - dbHandler null 유지');
    }
  }

  /// DatabaseHandler 해제
  @action
  void disposeDatabaseHandler() {
    dbHandler = null;
  }
}