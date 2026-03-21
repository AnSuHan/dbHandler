import 'package:flutter/cupertino.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:db_handler/sqflite/models/server_model.dart';
import 'package:db_handler/stateManagement/setState/join_definition.dart';
import 'database_handler.dart';

class MysqlHandler extends DatabaseHandler {
  final ServerModel server;
  final String? databaseName;

  // 데이터 캐싱
  static final Map<String, List<Map<String, dynamic>>> _databasesCache = {};
  static final Map<String, Map<String, List<Map<String, dynamic>>>> _tablesCache = {};

  // 커넥션 풀: 연결을 재사용하여 매 요청마다 TCP 연결/인증 오버헤드 제거
  static final Map<String, MySQLConnectionPool> _pools = {};

  MysqlHandler(this.server, {this.databaseName});

  String get _serverKey => '${server.address}_${server.username}';

  MySQLConnectionPool _getPool(String dbName) {
    final key = '${_serverKey}_$dbName';
    return _pools.putIfAbsent(key, () {
      final host = server.address.split(':')[0];
      final port = int.parse(server.address.split(':')[1]);
      return MySQLConnectionPool(
        host: host,
        port: port,
        userName: server.username ?? '',
        password: server.password ?? '',
        maxConnections: 4,
        databaseName: dbName,
      );
    });
  }

  Future<T> _withConnection<T>(
      String dbName, Future<T> Function(MySQLConnectionPool) action) async {
    try {
      return await action(_getPool(dbName));
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('access denied') ||
          errorStr.contains('authentication')) {
        throw Exception('로그인 실패 (아이디 또는 비밀번호를 확인해주세요)');
      }
      rethrow;
    }
  }

  /// row.assoc()가 Map<String, String?>을 반환하므로 적절한 타입으로 변환
  int _parseInt(String? value) => value == null ? 0 : int.tryParse(value) ?? 0;

  // ========== 서버 관리 메서드 ==========

  @override
  Future<List<ServerModel>> getServers() async {
    throw UnimplementedError('서버 관리는 로컬 SQLite에서 처리됩니다.');
  }

  @override
  Future<void> insertServer(ServerModel server) async {
    throw UnimplementedError('서버 관리는 로컬 SQLite에서 처리됩니다.');
  }

  @override
  Future<void> updateServer(ServerModel server) async {
    throw UnimplementedError('서버 관리는 로컬 SQLite에서 처리됩니다.');
  }

  @override
  Future<void> deleteServer(int serverId) async {
    throw UnimplementedError('서버 관리는 로컬 SQLite에서 처리됩니다.');
  }

  @override
  void clearCache() {
    _databasesCache.remove(_serverKey);
    _tablesCache.remove(_serverKey);
  }

  @override
  Future<int> getTableCount(String databaseName) async {
    try {
      return await _withConnection('information_schema', (pool) async {
        final result = await pool.execute(
          "SELECT COUNT(*) AS cnt FROM information_schema.TABLES "
          "WHERE TABLE_SCHEMA = :db AND TABLE_TYPE = 'BASE TABLE'",
          {"db": databaseName},
        );
        if (result.rows.isEmpty) return 0;
        return _parseInt(result.rows.first.colAt(0));
      });
    } catch (e) {
      debugPrint("[getTableCount] error for $databaseName: $e");
      return 0;
    }
  }

  // ========== 데이터베이스 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getDatabases() async {
    if (_databasesCache.containsKey(_serverKey)) {
      return _databasesCache[_serverKey]!;
    }

    final dbNames = await _withConnection('information_schema', (pool) async {
      final results = await pool.execute(
        "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA "
        "WHERE SCHEMA_NAME NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys') "
        "ORDER BY SCHEMA_NAME",
      );
      return results.rows.map((row) => row.colAt(0) as String).toList();
    });

    // 병렬로 테이블 개수 조회 (성능 최적화)
    final databases = await Future.wait(dbNames.map((name) async {
      final count = await getTableCount(name);
      return {
        'name': name,
        'table_count': count,
      };
    }));

    _databasesCache[_serverKey] = databases;
    return databases;
  }

  @override
  Future<void> createDatabase(String dbName) async {
    await _withConnection('information_schema', (pool) =>
        pool.execute('CREATE DATABASE `$dbName`'));
    _databasesCache.remove(_serverKey);
  }

  @override
  Future<void> renameDatabase(String oldName, String newName) async {
    await _withConnection('information_schema', (pool) async {
      // MySQL은 RENAME DATABASE를 지원하지 않으므로 새 DB 생성 → 테이블 이동 → 구 DB 삭제
      await pool.execute('CREATE DATABASE `$newName`');

      // 기존 DB의 모든 테이블 목록 가져오기
      final tablesResult = await pool.execute(
        "SELECT TABLE_NAME FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = :db AND TABLE_TYPE = 'BASE TABLE'",
        {"db": oldName},
      );

      // 각 테이블을 새 DB로 이동
      for (final row in tablesResult.rows) {
        final tableName = row.colAt(0) as String;
        await pool.execute('RENAME TABLE `$oldName`.`$tableName` TO `$newName`.`$tableName`');
      }

      await pool.execute('DROP DATABASE `$oldName`');
    });

    // 해당 DB의 커넥션 풀 제거
    final poolKey = '${_serverKey}_$oldName';
    _pools.remove(poolKey);
    _databasesCache.remove(_serverKey);
  }

  @override
  Future<void> deleteDatabase(String dbName) async {
    await _withConnection('information_schema', (pool) async {
      // 해당 DB에 접속 중인 모든 연결 강제 종료
      final processResult = await pool.execute(
        "SELECT ID FROM information_schema.PROCESSLIST WHERE DB = :db",
        {"db": dbName},
      );
      for (final row in processResult.rows) {
        final id = row.colAt(0);
        if (id != null) {
          try {
            await pool.execute('KILL $id');
          } catch (_) {
            // 이미 종료된 연결일 수 있음
          }
        }
      }
      await pool.execute('DROP DATABASE `$dbName`');
    });
    // 해당 DB의 커넥션 풀 제거
    final poolKey = '${_serverKey}_$dbName';
    _pools.remove(poolKey);
    _databasesCache.remove(_serverKey);
  }

  // ========== 테이블 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getTables(String databaseName) async {
    if (_tablesCache[_serverKey]?.containsKey(databaseName) ?? false) {
      return _tablesCache[_serverKey]![databaseName]!;
    }

    final tables = await _withConnection(databaseName, (pool) async {
      final result = await pool.execute(
        "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS, "
        "(SELECT COUNT(*) FROM information_schema.COLUMNS c "
        " WHERE c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME) AS COLUMN_COUNT "
        "FROM information_schema.TABLES t "
        "WHERE TABLE_SCHEMA = :db AND TABLE_TYPE = 'BASE TABLE' "
        "ORDER BY TABLE_NAME",
        {"db": databaseName},
      );

      return result.rows.map((row) {
        final map = row.assoc();
        return {
          'table_schema': map['TABLE_SCHEMA'] ?? databaseName,
          'name': map['TABLE_NAME'] as String,
          'row_count': _parseInt(map['TABLE_ROWS']),
          'column_count': _parseInt(map['COLUMN_COUNT']),
        };
      }).toList();
    });

    _tablesCache[_serverKey] ??= {};
    _tablesCache[_serverKey]![databaseName] = tables;
    return tables;
  }

  @override
  Future<void> createTable(String tableName, Map<String, String> columns) async {
    await _withConnection(databaseName!, (pool) {
      final columnDefs = columns.entries
          .map((e) => '`${e.key}` ${e.value}')
          .join(', ');
      return pool.execute('CREATE TABLE `$tableName` ($columnDefs)');
    });
    _tablesCache[_serverKey]?.remove(databaseName);
  }

  @override
  Future<void> renameTable(String oldName, String newName, {String schema = 'public'}) async {
    await _withConnection(databaseName!, (pool) {
      return pool.execute('RENAME TABLE `$oldName` TO `$newName`');
    });
    _tablesCache[_serverKey]?.remove(databaseName);
  }

  @override
  Future<void> deleteTable(String tableName, {String schema = 'public'}) async {
    await _withConnection(databaseName!, (pool) {
      return pool.execute('DROP TABLE `$tableName`');
    });
    _tablesCache[_serverKey]?.remove(databaseName);
  }

  // ========== 컬럼 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getColumns(String tableName) {
    return _withConnection(databaseName!, (pool) async {
      final result = await pool.execute(
        "SELECT COLUMN_NAME, COLUMN_TYPE "
        "FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA = :db AND TABLE_NAME = :table "
        "ORDER BY ORDINAL_POSITION",
        {"db": databaseName!, "table": tableName},
      );

      return result.rows.map((row) {
        final map = row.assoc();
        return {
          'name': map['COLUMN_NAME'] as String,
          'type': map['COLUMN_TYPE'] as String,
        };
      }).toList();
    });
  }

  @override
  Future<String?> getPrimaryKey(String tableName) {
    return _withConnection(databaseName!, (pool) async {
      final result = await pool.execute(
        "SELECT COLUMN_NAME "
        "FROM information_schema.KEY_COLUMN_USAGE "
        "WHERE TABLE_SCHEMA = :db AND TABLE_NAME = :table AND CONSTRAINT_NAME = 'PRIMARY'",
        {"db": databaseName!, "table": tableName},
      );

      if (result.rows.isEmpty) return null;
      return result.rows.first.colAt(0);
    });
  }

  @override
  Future<void> addColumn(String tableName, String columnName, String dataType, String constraints) {
    return _withConnection(databaseName!, (pool) {
      return pool.execute('ALTER TABLE `$tableName` ADD COLUMN `$columnName` $dataType $constraints');
    });
  }

  @override
  Future<void> modifyColumn(String tableName, String oldColumnName, String newColumnName, String newDataType, String newConstraints) {
    return _withConnection(databaseName!, (pool) async {
      if (oldColumnName != newColumnName) {
        // MySQL의 CHANGE COLUMN은 이름 변경과 타입 변경을 동시에 처리
        await pool.execute(
            'ALTER TABLE `$tableName` CHANGE COLUMN `$oldColumnName` `$newColumnName` $newDataType $newConstraints');
      } else {
        await pool.execute(
            'ALTER TABLE `$tableName` MODIFY COLUMN `$newColumnName` $newDataType $newConstraints');
      }
    });
  }

  @override
  Future<void> deleteColumn(String tableName, String columnName) {
    return _withConnection(databaseName!, (pool) {
      return pool.execute('ALTER TABLE `$tableName` DROP COLUMN `$columnName`');
    });
  }

  // ========== 데이터 조회/조작 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getData(String tableName) {
    return _withConnection(databaseName!, (pool) async {
      final result = await pool.execute('SELECT * FROM `$tableName`');
      return result.rows.map((row) => row.assoc()).toList().cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getDataWithFilters(
    String tableName, {
      List<Map<String, dynamic>>? filters,
      List<Map<String, dynamic>>? sorts,
      List<String>? groupByColumns,
    })
  {
    return _withConnection(databaseName!, (pool) async {
      final substitutionValues = <String, dynamic>{};

      // GROUP BY가 있어도 SELECT *를 사용하여 모든 행 반환
      String selectClause = 'SELECT * FROM `$tableName`';
      var query = selectClause;

      // WHERE 절 생성
      if (filters != null && filters.isNotEmpty) {
        final whereClauses = <String>[];
        int paramIndex = 0;

        for (int i = 0; i < filters.length; i++) {
          final filter = filters[i];
          final column = filter['column'] as String;
          final operator = filter['operator'] as String;
          final value = filter['value'];
          final logicalOperator = filter['logicalOperator'] as String?;

          final isNegated = filter['isNegated'] as bool? ?? false;
          final openGroupCount = filter['openGroupCount'] as int? ?? 0;
          final closeGroupCount = filter['closeGroupCount'] as int? ?? 0;

          // 1. 여는 괄호
          for (int p = 0; p < openGroupCount; p++) whereClauses.add('(');

          // 2. NOT
          if (isNegated) {
            whereClauses.add('NOT');
            whereClauses.add('(');
          }

          // 3. 조건 본체
          String condition;
          final opUpper = operator.toUpperCase();
          if (opUpper == 'IS NULL' || opUpper == 'IS NOT NULL') {
            condition = '`$column` $opUpper';
          } else if (opUpper == 'IN' || opUpper == 'NOT IN') {
            if (value is List && value.isNotEmpty) {
              final pNames = [];
              for (var v in value) {
                final pName = 'param$paramIndex';
                pNames.add(':$pName');
                substitutionValues[pName] = v;
                paramIndex++;
              }
              condition = '`$column` $opUpper (${pNames.join(', ')})';
            } else {
              condition = '`$column` ${opUpper == 'IN' ? '=' : '!='} :param$paramIndex';
              substitutionValues['param$paramIndex'] = value;
              paramIndex++;
            }
          } else if (opUpper == 'LIKE') {
            condition = '`$column` LIKE :param$paramIndex';
            substitutionValues['param$paramIndex'] = value;
            paramIndex++;
          } else {
            condition = '`$column` $operator :param$paramIndex';
            substitutionValues['param$paramIndex'] = value;
            paramIndex++;
          }
          whereClauses.add(condition);

          // 4. NOT 닫기
          if (isNegated) whereClauses.add(')');

          // 5. 닫는 괄호
          for (int p = 0; p < closeGroupCount; p++) whereClauses.add(')');

          // 6. 논리 연산자 (다음 필터가 있을 때만 추가)
          if (i < filters.length - 1) {
            whereClauses.add((logicalOperator ?? 'AND').toUpperCase());
          }
        }

        if (whereClauses.isNotEmpty) {
          query += ' WHERE ${whereClauses.join(' ')}';
        }
      }

      // ORDER BY 절 생성
      final orderByColumns = <String>[];

      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        for (final col in groupByColumns) {
          orderByColumns.add('`$col` ASC');
        }
      }

      if (sorts != null && sorts.isNotEmpty) {
        for (final sort in sorts) {
          final column = sort['column'] as String;
          final ascending = sort['ascending'] as bool;
          final sortClause = '`$column` ${ascending ? 'ASC' : 'DESC'}';

          if (groupByColumns != null && groupByColumns.contains(column)) {
            continue;
          }
          orderByColumns.add(sortClause);
        }
      }

      if (orderByColumns.isNotEmpty) {
        query += ' ORDER BY ${orderByColumns.join(', ')}';
      }

      final results = substitutionValues.isEmpty
          ? await pool.execute(query)
          : await pool.execute(query, substitutionValues);
      return results.rows.map((row) => row.assoc()).toList().cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<void> addRow(String tableName, Map<String, dynamic> data) {
    return _withConnection(databaseName!, (pool) async {
      if (data.isEmpty) {
        await pool.execute('INSERT INTO `$tableName` () VALUES ()');
      } else {
        final columns = data.keys.map((k) => '`$k`').join(',');
        final params = data.keys.map((k) => ':$k').join(',');
        await pool.execute(
          'INSERT INTO `$tableName` ($columns) VALUES ($params)',
          data.map((k, v) => MapEntry(k, v)),
        );
      }
    });
  }

  @override
  Future<void> updateRow(String tableName, Map<String, dynamic> data, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (pool) async {
      final setClauses = data.keys.map((k) => '`$k` = :$k').join(',');
      final parameters = {...data, 'primaryKeyValue': pkValue};
      final query = 'UPDATE `$tableName` SET $setClauses WHERE `$pkColumn` = :primaryKeyValue';
      await pool.execute(query, parameters);
    });
  }

  @override
  Future<void> updateCell(String tableName, String columnName, dynamic newValue, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (pool) async {
      final query = 'UPDATE `$tableName` SET `$columnName` = :newValue WHERE `$pkColumn` = :pkValue';
      await pool.execute(query, {'newValue': newValue, 'pkValue': pkValue});
    });
  }

  @override
  Future<void> deleteRow(String tableName, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (pool) async {
      final query = 'DELETE FROM `$tableName` WHERE `$pkColumn` = :pkValue';
      await pool.execute(query, {'pkValue': pkValue});
    });
  }

  // ========== JOIN 뷰 메서드 ==========

  Map<String, String> _buildAliases(JoinDefinition joinDef) {
    final aliases = <String, String>{};
    aliases[joinDef.mainTable] = 't0';
    for (int i = 0; i < joinDef.joins.length; i++) {
      final t = joinDef.joins[i].targetTable;
      if (!aliases.containsKey(t)) {
        aliases[t] = 't${aliases.length}';
      }
    }
    return aliases;
  }

  String _buildJoinClause(JoinDefinition joinDef, Map<String, String> aliases) {
    final sb = StringBuffer();
    sb.write('`${joinDef.mainTable}` ${aliases[joinDef.mainTable]}');
    for (final j in joinDef.joins) {
      final leftAlias = aliases[j.leftTable]!;
      final rightAlias = aliases[j.targetTable]!;
      sb.write(' ${j.joinType.sql} `${j.targetTable}` $rightAlias');
      sb.write(' ON $leftAlias.`${j.leftColumn}` = $rightAlias.`${j.rightColumn}`');
    }
    return sb.toString();
  }

  @override
  Future<List<Map<String, dynamic>>> getJoinedColumns(JoinDefinition joinDef) {
    return _withConnection(databaseName!, (pool) async {
      final columns = <Map<String, dynamic>>[];
      final seenNames = <String>{};
      final aliases = _buildAliases(joinDef);

      for (final tableName in joinDef.allTables) {
        final result = await pool.execute(
          "SELECT COLUMN_NAME, COLUMN_TYPE "
          "FROM information_schema.COLUMNS "
          "WHERE TABLE_SCHEMA = :db AND TABLE_NAME = :table "
          "ORDER BY ORDINAL_POSITION",
          {"db": databaseName!, "table": tableName},
        );

        final alias = aliases[tableName]!;
        for (final row in result.rows) {
          final map = row.assoc();
          final colName = map['COLUMN_NAME'] as String;
          final displayName = seenNames.contains(colName)
              ? '$tableName.$colName'
              : colName;
          seenNames.add(colName);
          columns.add({
            'name': displayName,
            'type': map['COLUMN_TYPE'] as String,
            'sourceTable': tableName,
            'sourceColumn': colName,
            'alias': alias,
          });
        }
      }
      return columns;
    });
  }

  Future<String> _buildMysqlSelectClause(JoinDefinition joinDef, Map<String, String> aliases, MySQLConnectionPool pool) async {
    final selectParts = <String>[];
    final seenNames = <String>{};

    for (final tableName in joinDef.allTables) {
      final result = await pool.execute(
        "SELECT COLUMN_NAME "
        "FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA = :db AND TABLE_NAME = :table "
        "ORDER BY ORDINAL_POSITION",
        {"db": databaseName!, "table": tableName},
      );

      final alias = aliases[tableName]!;
      for (final row in result.rows) {
        final colName = row.colAt(0) as String;
        final displayName = seenNames.contains(colName)
            ? '$tableName.$colName'
            : colName;
        seenNames.add(colName);
        selectParts.add('$alias.`$colName` AS `$displayName`');
      }
    }
    return selectParts.join(', ');
  }

  @override
  Future<List<Map<String, dynamic>>> getJoinedData(JoinDefinition joinDef) {
    return _withConnection(databaseName!, (pool) async {
      final aliases = _buildAliases(joinDef);
      final selectClause = await _buildMysqlSelectClause(joinDef, aliases, pool);
      final joinClause = _buildJoinClause(joinDef, aliases);
      final query = 'SELECT $selectClause FROM $joinClause';
      final result = await pool.execute(query);
      return result.rows.map((row) => row.assoc()).toList().cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getJoinedDataWithFilters(
      JoinDefinition joinDef, {
        List<Map<String, dynamic>>? filters,
        List<Map<String, dynamic>>? sorts,
        List<String>? groupByColumns,
      }) {
    return _withConnection(databaseName!, (pool) async {
      final aliases = _buildAliases(joinDef);
      final selectClause = await _buildMysqlSelectClause(joinDef, aliases, pool);
      final joinClause = _buildJoinClause(joinDef, aliases);
      final substitutionValues = <String, dynamic>{};

      var query = 'SELECT $selectClause FROM $joinClause';

      // WHERE 절 생성
      if (filters != null && filters.isNotEmpty) {
        final whereClauses = <String>[];
        int paramIndex = 0;

        for (int i = 0; i < filters.length; i++) {
          final filter = filters[i];
          final column = filter['column'] as String;
          final operator = filter['operator'] as String;
          final value = filter['value'];
          final logicalOperator = filter['logicalOperator'] as String?;
          final isNegated = filter['isNegated'] as bool? ?? false;
          final openGroupCount = filter['openGroupCount'] as int? ?? 0;
          final closeGroupCount = filter['closeGroupCount'] as int? ?? 0;

          for (int p = 0; p < openGroupCount; p++) whereClauses.add('(');
          if (isNegated) { whereClauses.add('NOT'); whereClauses.add('('); }

          String condition;
          final opUpper = operator.toUpperCase();
          final quotedColumn = '`$column`';

          if (opUpper == 'IS NULL' || opUpper == 'IS NOT NULL') {
            condition = '$quotedColumn $opUpper';
          } else if (opUpper == 'IN' || opUpper == 'NOT IN') {
            if (value is List && value.isNotEmpty) {
              final pNames = [];
              for (var v in value) {
                final pName = 'param$paramIndex';
                pNames.add(':$pName');
                substitutionValues[pName] = v;
                paramIndex++;
              }
              condition = '$quotedColumn $opUpper (${pNames.join(', ')})';
            } else {
              condition = '$quotedColumn ${opUpper == 'IN' ? '=' : '!='} :param$paramIndex';
              substitutionValues['param$paramIndex'] = value;
              paramIndex++;
            }
          } else if (opUpper == 'LIKE') {
            condition = '$quotedColumn LIKE :param$paramIndex';
            substitutionValues['param$paramIndex'] = value;
            paramIndex++;
          } else {
            condition = '$quotedColumn $operator :param$paramIndex';
            substitutionValues['param$paramIndex'] = value;
            paramIndex++;
          }
          whereClauses.add(condition);

          if (isNegated) whereClauses.add(')');
          for (int p = 0; p < closeGroupCount; p++) whereClauses.add(')');
          if (i < filters.length - 1) {
            whereClauses.add((logicalOperator ?? 'AND').toUpperCase());
          }
        }

        if (whereClauses.isNotEmpty) {
          query += ' WHERE ${whereClauses.join(' ')}';
        }
      }

      // ORDER BY 절 생성
      final orderByColumns = <String>[];
      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        for (final col in groupByColumns) {
          orderByColumns.add('`$col` ASC');
        }
      }
      if (sorts != null && sorts.isNotEmpty) {
        for (final sort in sorts) {
          final column = sort['column'] as String;
          final ascending = sort['ascending'] as bool;
          final sortClause = '`$column` ${ascending ? 'ASC' : 'DESC'}';
          if (groupByColumns != null && groupByColumns.contains(column)) continue;
          orderByColumns.add(sortClause);
        }
      }
      if (orderByColumns.isNotEmpty) {
        query += ' ORDER BY ${orderByColumns.join(', ')}';
      }

      final results = substitutionValues.isEmpty
          ? await pool.execute(query)
          : await pool.execute(query, substitutionValues);
      return results.rows.map((row) => row.assoc()).toList().cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<void> updateJoinedCell(
      String sourceTable, String sourceColumn, dynamic newValue,
      String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (pool) async {
      final query = 'UPDATE `$sourceTable` SET `$sourceColumn` = :newValue WHERE `$pkColumn` = :pkValue';
      await pool.execute(query, {'newValue': newValue, 'pkValue': pkValue});
    });
  }

  // ========== 트랜잭션 메서드 ==========
  @override
  Future<void> runInTransaction(Future<void> Function() operation) async {
    if (databaseName == null) {
      throw Exception('Database is not initialized');
    }

    try {
      await _getPool(databaseName!).transactional((conn) async {
        await operation();
      });
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('access denied') ||
          errorStr.contains('authentication')) {
        throw Exception('로그인 실패 (아이디 또는 비밀번호를 확인해주세요)');
      }
      rethrow;
    }
  }
}
