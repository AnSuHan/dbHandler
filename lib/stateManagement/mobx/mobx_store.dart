// lib/stateManagement/mobx/mobx_store.dart
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:db_handler/sqflite/models/server_model.dart';
import 'package:db_handler/db/database_handler.dart';

part 'mobx_store.g.dart';

class ServerSelectionStore = _ServerSelectionStore with _$ServerSelectionStore;

abstract class _ServerSelectionStore with Store {
  late DatabaseHandler _dbHandler;

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

  _ServerSelectionStore({String? dbType}) {
    // DatabaseHandler 초기화 - 프로젝트에 맞게 수정 필요
    // 예: _dbHandler = PostgresHandler();
    // 또는 _dbHandler = DatabaseHandler.instance;
    loadServers();
  }

  @action
  Future<void> loadServers() async {
    isLoading = true;
    error = null;
    try {
      // DatabaseHandler의 실제 메서드명으로 수정 필요
      // final loadedServers = await _dbHandler.getServers();
      // 임시로 빈 리스트 반환
      await Future.delayed(const Duration(milliseconds: 500));
      servers = ObservableList<ServerModel>();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
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
    if (name.isEmpty || host.isEmpty || port.isEmpty) {
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

    ServerModel? serverToAdd = newServer;

    if (isTestServer) {
      serverToAdd = await showAuthDialog(newServer, isTest: true, isInitialSetup: true);
    }

    if (serverToAdd == null) return;

    try {
      // await _dbHandler.insertServer(serverToAdd);
      servers.add(serverToAdd); // 임시: 메모리에만 추가
      await loadServers();
      showSnackbar('서버가 추가되었습니다.', color: Colors.green);

      nameController.clear();
      hostController.clear();
      portController.clear();
      typeController.clear();
    } catch (e) {
      showSnackbar('서버 추가 실패: $e', color: Colors.red);
    }
  }

  @action
  Future<void> updateServer(
      ServerModel server,
      Function(String, {Color? color}) showSnackbar,
      ) async {
    try {
      // await _dbHandler.updateServer(server);
      final index = servers.indexWhere((s) => s.id == server.id);
      if (index != -1) {
        servers[index] = server;
      }
      await loadServers();
      showSnackbar('서버 정보가 업데이트되었습니다.', color: Colors.green);
    } catch (e) {
      showSnackbar('서버 업데이트 실패: $e', color: Colors.red);
    }
  }

  @action
  Future<void> deleteServer(
      ServerModel server,
      Function(String, {Color? color}) showSnackbar,
      ) async {
    try {
      // await _dbHandler.deleteServer(server.id);
      servers.removeWhere((s) => s.id == server.id);
      await loadServers();
      showSnackbar('서버가 삭제되었습니다.', color: Colors.green);
    } catch (e) {
      showSnackbar('서버 삭제 실패: $e', color: Colors.red);
    }
  }
}