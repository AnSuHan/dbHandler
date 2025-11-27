// lib/stateManagement/setState/riverpod.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../sqflite/models/server_model.dart';
import '../../sqflite/dao/server_dao.dart';

/// Riverpod 상태관리 클래스(StateNotifier)를 올바르게 구현하려면:
/// 1. StateNotifier<T>를 상속하며 상태 타입 T를 지정합니다.
/// 2. super() 생성자를 호출하여 초기 상태를 전달합니다.
/// 3. 상태 변경 시 내부의 state 프로퍼티를 직접 갱신해야 합니다.
/// 4. StateNotifierProvider는 상태변경을 구독하는 프로바이더로 생성합니다.

class Riverpod extends StateNotifier<AsyncValue<List<ServerModel>>> {
  final ServerDao _serverDao;

  Riverpod(this._serverDao) : super(const AsyncValue.loading()) {
    loadServers();
  }

  Future<void> loadServers() async {
    try {
      state = const AsyncValue.loading();
      final servers = await _serverDao.getAllServers();
      state = AsyncValue.data(servers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addServer({
    required String name,
    required String host,
    required String port,
    required String type,
    required bool isTest,
    required void Function(String message, {Color? color}) showSnackbar,
    required TextEditingController nameController,
    required TextEditingController hostController,
    required TextEditingController portController,
    required TextEditingController typeController,
    required Future<ServerModel?> Function(ServerModel server,
            {bool isTest, bool isInitialSetup})
        showAuthDialog,
  }) async {
    final address = '$host:$port';
    final servers = state.value ?? [];
    if (name.isEmpty || host.isEmpty || port.isEmpty) {
      showSnackbar('이름, 호스트, 포트는 필수입니다.', color: Colors.red);
      return;
    }
    if (servers.any((s) => s.address == address)) {
      showSnackbar('이미 동일한 주소의 서버가 존재합니다.', color: Colors.orange);
      return;
    }
    final newServer = ServerModel(
        name: name,
        address: address,
        type: type.isEmpty ? 'PostgreSQL' : type,
        isConnected: false);
    try {
      final newId = await _serverDao.insertServer(newServer);
      final createdServer = await _serverDao.getServerById(newId);

      nameController.clear();
      hostController.clear();
      portController.clear();
      typeController.clear();

      await loadServers();

      if (createdServer != null) {
        showSnackbar('서버가 추가되었습니다.', color: Colors.green);
        await showAuthDialog(createdServer, isTest: isTest, isInitialSetup: true);
      }
    } catch (e) {
      showSnackbar('서버 추가 실패: $e', color: Colors.red);
    }
  }

  Future<void> updateServer(
      ServerModel updatedServer, void Function(String, {Color? color}) showSnackbar) async {
    try {
      await _serverDao.updateServer(updatedServer);
      await loadServers();
      showSnackbar('서버 정보가 수정되었습니다.', color: Colors.green);
    } catch (e) {
      showSnackbar('서버 정보 수정 실패: $e', color: Colors.red);
    }
  }

  Future<void> deleteServer(
      ServerModel server, void Function(String, {Color? color}) showSnackbar) async {
    if (server.id == null) {
      showSnackbar('서버 삭제 실패: 서버 ID가 없습니다.', color: Colors.red);
      return;
    }
    try {
      await _serverDao.deleteServer(server.id!);
      await loadServers();
      showSnackbar('서버가 삭제되었습니다.', color: Colors.green);
    } catch (e) {
      showSnackbar('서버 삭제 중 오류: $e', color: Colors.red);
    }
  }
}

final serverDaoProvider = Provider<ServerDao>((ref) => ServerDao());

final serverSelectionProvider =
    StateNotifierProvider<Riverpod, AsyncValue<List<ServerModel>>>(
        (ref) => Riverpod(ref.watch(serverDaoProvider)));

final showAddFormProvider = StateProvider<bool>((ref) => false);

final isTestServerProvider = StateProvider<bool>((ref) => false);

