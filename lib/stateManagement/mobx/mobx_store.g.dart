// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobx_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ServerStore on _ServerStore, Store {
  late final _$serversAtom =
      Atom(name: '_ServerStore.servers', context: context);

  @override
  ObservableList<ServerModel> get servers {
    _$serversAtom.reportRead();
    return super.servers;
  }

  @override
  set servers(ObservableList<ServerModel> value) {
    _$serversAtom.reportWrite(value, super.servers, () {
      super.servers = value;
    });
  }

  late final _$selectedServerAtom =
      Atom(name: '_ServerStore.selectedServer', context: context);

  @override
  ServerModel? get selectedServer {
    _$selectedServerAtom.reportRead();
    return super.selectedServer;
  }

  @override
  set selectedServer(ServerModel? value) {
    _$selectedServerAtom.reportWrite(value, super.selectedServer, () {
      super.selectedServer = value;
    });
  }

  late final _$lastAddedServerAtom =
      Atom(name: '_ServerStore.lastAddedServer', context: context);

  @override
  ServerModel? get lastAddedServer {
    _$lastAddedServerAtom.reportRead();
    return super.lastAddedServer;
  }

  @override
  set lastAddedServer(ServerModel? value) {
    _$lastAddedServerAtom.reportWrite(value, super.lastAddedServer, () {
      super.lastAddedServer = value;
    });
  }

  late final _$isLoadingAtom =
      Atom(name: '_ServerStore.isLoading', context: context);

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorAtom = Atom(name: '_ServerStore.error', context: context);

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$isAddFormOpenAtom =
      Atom(name: '_ServerStore.isAddFormOpen', context: context);

  @override
  bool get isAddFormOpen {
    _$isAddFormOpenAtom.reportRead();
    return super.isAddFormOpen;
  }

  @override
  set isAddFormOpen(bool value) {
    _$isAddFormOpenAtom.reportWrite(value, super.isAddFormOpen, () {
      super.isAddFormOpen = value;
    });
  }

  late final _$isTestServerAtom =
      Atom(name: '_ServerStore.isTestServer', context: context);

  @override
  bool get isTestServer {
    _$isTestServerAtom.reportRead();
    return super.isTestServer;
  }

  @override
  set isTestServer(bool value) {
    _$isTestServerAtom.reportWrite(value, super.isTestServer, () {
      super.isTestServer = value;
    });
  }

  late final _$loadServersAsyncAction =
      AsyncAction('_ServerStore.loadServers', context: context);

  @override
  Future<void> loadServers() {
    return _$loadServersAsyncAction.run(() => super.loadServers());
  }

  late final _$refreshServersAsyncAction =
      AsyncAction('_ServerStore.refreshServers', context: context);

  @override
  Future<void> refreshServers() {
    return _$refreshServersAsyncAction.run(() => super.refreshServers());
  }

  late final _$addServerAsyncAction =
      AsyncAction('_ServerStore.addServer', context: context);

  @override
  Future<bool> addServer(ServerModel server,
      dynamic Function(String, {Color? color}) showSnackbar) {
    return _$addServerAsyncAction
        .run(() => super.addServer(server, showSnackbar));
  }

  late final _$updateServerAsyncAction =
      AsyncAction('_ServerStore.updateServer', context: context);

  @override
  Future<void> updateServer(ServerModel server,
      dynamic Function(String, {Color? color}) showSnackbar) {
    return _$updateServerAsyncAction
        .run(() => super.updateServer(server, showSnackbar));
  }

  late final _$deleteServerAsyncAction =
      AsyncAction('_ServerStore.deleteServer', context: context);

  @override
  Future<void> deleteServer(ServerModel server,
      dynamic Function(String, {Color? color}) showSnackbar) {
    return _$deleteServerAsyncAction
        .run(() => super.deleteServer(server, showSnackbar));
  }

  late final _$initializeDatabaseHandlerAsyncAction =
      AsyncAction('_ServerStore.initializeDatabaseHandler', context: context);

  @override
  Future<void> initializeDatabaseHandler() {
    return _$initializeDatabaseHandlerAsyncAction
        .run(() => super.initializeDatabaseHandler());
  }

  late final _$_ServerStoreActionController =
      ActionController(name: '_ServerStore', context: context);

  @override
  void selectServer(ServerModel server) {
    final _$actionInfo = _$_ServerStoreActionController.startAction(
        name: '_ServerStore.selectServer');
    try {
      return super.selectServer(server);
    } finally {
      _$_ServerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void toggleAddForm() {
    final _$actionInfo = _$_ServerStoreActionController.startAction(
        name: '_ServerStore.toggleAddForm');
    try {
      return super.toggleAddForm();
    } finally {
      _$_ServerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void openAddForm() {
    final _$actionInfo = _$_ServerStoreActionController.startAction(
        name: '_ServerStore.openAddForm');
    try {
      return super.openAddForm();
    } finally {
      _$_ServerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void closeAddForm() {
    final _$actionInfo = _$_ServerStoreActionController.startAction(
        name: '_ServerStore.closeAddForm');
    try {
      return super.closeAddForm();
    } finally {
      _$_ServerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setIsTestServer(bool value) {
    final _$actionInfo = _$_ServerStoreActionController.startAction(
        name: '_ServerStore.setIsTestServer');
    try {
      return super.setIsTestServer(value);
    } finally {
      _$_ServerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
servers: ${servers},
selectedServer: ${selectedServer},
lastAddedServer: ${lastAddedServer},
isLoading: ${isLoading},
error: ${error},
isAddFormOpen: ${isAddFormOpen},
isTestServer: ${isTestServer}
    ''';
  }
}
