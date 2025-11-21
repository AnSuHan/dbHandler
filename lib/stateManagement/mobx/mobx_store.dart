// lib/stateManagement/mobx/mobx_store.dart
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:db_handler/sqflite/models/server_model.dart';

import '../../sqflite/dao/server_dao.dart';

part 'mobx_store.g.dart';

// Store 생성
class ServerStore = _ServerStore with _$ServerStore;

abstract class _ServerStore with Store {
  // DAO 인스턴스
  final ServerDao _dao = ServerDao();

  // 서버 목록
  @observable
  ObservableList<ServerModel> servers = ObservableList.of([]);

  // 선택된 서버
  @observable
  ServerModel? selectedServer;

  @observable
  ServerModel? lastAddedServer;

  // 로딩 여부
  @observable
  bool isLoading = false;

  // 에러 메시지
  @observable
  String? error;

  // 새 서버 추가 폼을 열지 말지 여부
  @observable
  bool isAddFormOpen = false;

  // 테스트 서버 모드 여부
  @observable
  bool isTestServer = false;

  // 서버 목록 조회
  @action
  Future<void> loadServers() async {
    isLoading = true;
    error = null;

    try {
      final result = await _dao.getAllServers();
      servers = ObservableList.of(result);
      print('✅ 서버 목록 로드 완료: ${servers.length}개');
    } catch (e) {
      error = e.toString();
      print('❌ 서버 목록 로드 실패: $e');
    } finally {
      isLoading = false;
    }
  }

  // 서버 선택
  @action
  void selectServer(ServerModel server) {
    selectedServer = server;
  }

  // 서버 목록 새로고침
  @action
  Future<void> refreshServers() async {
    await loadServers();
  }

  // 서버 추가 (수정됨: 중복 체크 개선, 반환 타입 변경)
  @action
  Future<bool> addServer(ServerModel server, Function(String, {Color? color}) showSnackbar) async {
    try {
      isLoading = true;

      // DAO에서 중복 체크 및 삽입 (예외 발생 시 catch에서 처리)
      final int newId = await _dao.insertServer(server);

      // DB에서 방금 추가된 서버 조회 (정확한 데이터 보장)
      final addedServer = await _dao.getServerById(newId);

      if (addedServer != null) {
        // MobX observable 리스트에 추가 (자동으로 UI 업데이트)
        servers.add(addedServer);
        lastAddedServer = addedServer;

        showSnackbar('서버가 추가되었습니다: ${addedServer.name}', color: Colors.green);
        print('✅ 서버 추가 성공: ${addedServer.name} (ID: $newId)');

        // 폼 닫기
        isAddFormOpen = false;
        isTestServer = false;

        return true;
      } else {
        showSnackbar('서버 추가 후 조회 실패', color: Colors.red);
        return false;
      }

    } catch (e) {
      // DAO의 insertServer에서 던진 예외 처리
      if (e.toString().contains('동일한 주소')) {
        showSnackbar('이미 동일한 IP와 Port의 서버가 존재합니다.', color: Colors.red);
      } else {
        showSnackbar('서버 추가 실패: $e', color: Colors.red);
      }
      print('❌ 서버 추가 실패: $e');
      return false;

    } finally {
      isLoading = false;
    }
  }

  // 서버 업데이트 (수정됨: 전체 새로고침 대신 해당 항목만 업데이트)
  @action
  Future<void> updateServer(ServerModel server, Function(String, {Color? color}) showSnackbar) async {
    try {
      await _dao.updateServer(server);

      // 리스트에서 해당 서버 찾아서 업데이트 (Observer가 자동 감지)
      final index = servers.indexWhere((s) => s.id == server.id);
      if (index != -1) {
        servers[index] = server;
        showSnackbar('서버가 수정되었습니다.', color: Colors.green);
        print('✅ 서버 업데이트 성공: ${server.name}');
      } else {
        // 혹시 리스트에 없으면 전체 새로고침
        await loadServers();
        showSnackbar('서버가 수정되었습니다.', color: Colors.green);
      }

    } catch (e) {
      showSnackbar('서버 수정 중 오류 발생: $e', color: Colors.red);
      print('❌ 서버 업데이트 실패: $e');
    }
  }

  // 서버 삭제 (수정됨: 전체 새로고침 대신 해당 항목만 제거)
  @action
  Future<void> deleteServer(ServerModel server, Function(String, {Color? color}) showSnackbar) async {
    try {
      if(server.id == null) return;

      await _dao.deleteServer(server.id!);

      // 리스트에서 직접 제거 (Observer가 자동 감지)
      servers.removeWhere((s) => s.id == server.id);

      showSnackbar('서버가 삭제되었습니다: ${server.name}', color: Colors.orange);
      print('✅ 서버 삭제 성공: ${server.name}');

    } catch (e) {
      showSnackbar('서버 삭제 중 오류 발생: $e', color: Colors.red);
      print('❌ 서버 삭제 실패: $e');
    }
  }

  // Add Form 토글
  @action
  void toggleAddForm() {
    isAddFormOpen = !isAddFormOpen;
  }

  // 필요하면 강제로 열기/닫기
  @action
  void openAddForm() => isAddFormOpen = true;

  @action
  void closeAddForm() => isAddFormOpen = false;

  // 테스트 서버 모드를 설정 (true/false)
  @action
  void setIsTestServer(bool value) {
    isTestServer = value;
  }

  // DB 핸들러 초기화 (앱 시작 시 1회)
  @action
  Future<void> initializeDatabaseHandler() async {
    try {
      isLoading = true;
      await _dao.initialize();
      await loadServers();
      print('✅ DatabaseHandler 초기화 완료');
    } catch (e) {
      error = 'DB 초기화 중 오류 발생: $e';
      print('❌ DB 초기화 실패: $e');
    } finally {
      isLoading = false;
    }
  }
}