// lib/stateManagement/mobx/mobx_store.dart
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

  // 서버 목록 조회
  @action
  Future<void> loadServers() async {
    isLoading = true;
    error = null;

    try {
      final result = await _dao.getAllServers(); // server_dao.dart의 실제 메서드명
      servers = ObservableList.of(result);
    } catch (e) {
      error = e.toString();
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

  @action
  Future<void> updateServer(ServerModel server, Function(String) showSnackbar) async {
    try {
      await _dao.updateServer(server); // ← server_dao.dart 메서드 호출
      showSnackbar('서버가 수정되었습니다.');

      // 서버 목록 새로 고침
      await loadServers();
    } catch (e) {
      showSnackbar('서버 수정 중 오류 발생: $e');
    }
  }

  // 새 서버 추가 폼을 열지 말지 여부
  @observable
  bool isAddFormOpen = false;

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

  // 서버 삭제
  @action
  Future<void> deleteServer(ServerModel server, Function(String) showSnackbar) async {
    try {
      if(server.id == null) return;
      await _dao.deleteServer(server.id!);  // server_dao.dart의 실제 삭제 메서드에 맞게 수정

      showSnackbar('서버가 삭제되었습니다.');

      // 삭제 후 서버 목록 새로고침
      await loadServers();
    } catch (e) {
      showSnackbar('서버 삭제 중 오류 발생: $e');
    }
  }

  // 테스트 서버 모드 여부
  @observable
  bool isTestServer = false;

  // 테스트 서버 모드를 설정 (true/false)
  @action
  void setIsTestServer(bool value) {
    isTestServer = value;
  }


  // 서버 추가 (삽입)
  @action
  Future<void> addServer(ServerModel server, Function(String) showSnackbar) async {
    try {
      isLoading = true;

      // 삽입 후 반환되는 ID를 받도록 DAO 수정 필요 (아래 참고)
      final int newId = await _dao.insertServer(server);  // ← 반환값이 int라고 가정

      // ID가 부여된 완전한 서버 객체 생성
      final ServerModel savedServer = server.copyWith(id: newId);

      // 서버 목록에 추가 + lastAddedServer 갱신
      servers.add(savedServer);
      lastAddedServer = savedServer;  // ← 여기서 저장!

      showSnackbar('서버가 추가되었습니다: ${server.name}');

      // 폼 닫기
      isAddFormOpen = false;
      isTestServer = false;

    } catch (e) {
      showSnackbar('서버 추가 실패: $e');
    } finally {
      isLoading = false;
    }
  }

  // DB 핸들러 초기화 (앱 시작 시 1회)
  @action
  Future<void> initializeDatabaseHandler() async {
    try {
      await _dao.initialize();  // ← server_dao.dart에 존재하는 초기화 함수명에 맞게 변경

      // 초기화 후 서버 목록 불러오기
      await loadServers();
    } catch (e) {
      error = 'DB 초기화 중 오류 발생: $e';
    }
  }
}