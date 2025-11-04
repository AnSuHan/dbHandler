import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'package:db_handler/sqflite/dao/server_dao.dart';
import 'package:db_handler/sqflite/models/server_model.dart';

const _sentinel = Object();

/// 서버 선택 화면에서 사용하는 상태를 표현합니다.
@immutable
class ServerSelectionState {
  const ServerSelectionState({
    this.servers = const [],
    this.isLoading = false,
    this.showAddForm = false,
    this.isTestServer = false,
    this.errorMessage,
  });

  final List<ServerModel> servers;
  final bool isLoading;
  final bool showAddForm;
  final bool isTestServer;
  final String? errorMessage;

  ServerSelectionState copyWith({
    List<ServerModel>? servers,
    bool? isLoading,
    bool? showAddForm,
    bool? isTestServer,
    Object? errorMessage = _sentinel,
  }) {
    return ServerSelectionState(
      servers: servers ?? this.servers,
      isLoading: isLoading ?? this.isLoading,
      showAddForm: showAddForm ?? this.showAddForm,
      isTestServer: isTestServer ?? this.isTestServer,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

/// 서버 추가/수정 시 발생하는 검증 에러를 표현합니다.
class ServerFormException implements Exception {
  ServerFormException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `ServerDao`에 대한 싱글턴 Provider입니다.
final serverDaoProvider = Provider<ServerDao>((ref) {
  return ServerDao();
});

/// 서버 선택 화면 비즈니스 로직을 담당하는 StateNotifier입니다.
class ServerSelectionController extends StateNotifier<ServerSelectionState> {
  ServerSelectionController(this._ref) : super(const ServerSelectionState());

  final Ref _ref;

  ServerDao get _dao => _ref.read(serverDaoProvider);

  Future<void> loadServers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final servers = await _dao.getAllServers();
      state = state.copyWith(servers: servers, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '서버 목록 로딩 실패: $error',
      );
    }
  }

  Future<void> refreshServers() async {
    await loadServers();
  }

  void toggleAddForm() {
    final nextShow = !state.showAddForm;
    state = state.copyWith(
      showAddForm: nextShow,
      isTestServer: nextShow ? state.isTestServer : false,
      errorMessage: null,
    );
  }

  void setAddFormVisible(bool visible) {
    state = state.copyWith(
      showAddForm: visible,
      isTestServer: visible ? state.isTestServer : false,
      errorMessage: null,
    );
  }

  void setTestServer(bool value) {
    state = state.copyWith(isTestServer: value, errorMessage: null);
  }

  Future<ServerModel> addServer({
    required String name,
    required String host,
    required String port,
    required String type,
  }) async {
    final trimmedName = name.trim();
    final trimmedHost = host.trim();
    final trimmedPort = port.trim();
    final trimmedType = type.trim().isEmpty ? 'PostgreSQL' : type.trim();

    if (trimmedName.isEmpty || trimmedHost.isEmpty || trimmedPort.isEmpty) {
      throw ServerFormException('이름, 호스트, 포트는 필수입니다.');
    }

    final address = '${trimmedHost.toLowerCase()}:$trimmedPort';
    final hasDuplicate = state.servers.any((server) => server.address.toLowerCase() == address);
    if (hasDuplicate) {
      throw ServerFormException('이미 동일한 주소의 서버가 존재합니다.');
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final server = ServerModel(
        name: trimmedName,
        address: '$trimmedHost:$trimmedPort',
        type: trimmedType,
        isConnected: false,
      );

      final newId = await _dao.insertServer(server);
      final createdServer = await _dao.getServerById(newId);
      await loadServers();

      state = state.copyWith(showAddForm: false, isTestServer: false);
      return createdServer ?? server.copyWith(id: newId);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '서버 추가 실패: $error');
      rethrow;
    }
  }

  Future<void> deleteServer(int serverId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _dao.deleteServer(serverId);
      await loadServers();
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '서버 삭제 중 오류: $error');
      rethrow;
    }
  }

  Future<void> updateServer(ServerModel server) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _dao.updateServer(server);
      await loadServers();
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: '서버 정보 수정 실패: $error');
      rethrow;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

/// 서버 선택 화면 상태를 전역으로 노출하는 Provider입니다.
final serverSelectionProvider =
    StateNotifierProvider<ServerSelectionController, ServerSelectionState>((ref) {
  return ServerSelectionController(ref);
});
