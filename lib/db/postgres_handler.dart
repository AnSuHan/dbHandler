import 'package:postgres/postgres.dart';
import 'package:db_handler/sqflite/models/server_model.dart';
import 'database_handler.dart';

class PostgresHandler extends DatabaseHandler {
  final ServerModel server;
  final String? databaseName;

  PostgresHandler(this.server, {this.databaseName});

  Future<PostgreSQLConnection> _getConnection(String db) async {
    final host = server.address.split(':')[0];
    final port = int.parse(server.address.split(':')[1]);
    final username = server.username;
    final password = server.password;

    final connection = PostgreSQLConnection(
      host,
      port,
      db,
      username: username,
      password: password,
    );
    await connection.open();
    return connection;
  }

  Future<T> _withConnection<T>(
      String dbName, Future<T> Function(PostgreSQLConnection) action) async {
    final connection = await _getConnection(dbName);
    try {
      return await action(connection);
    } finally {
      await connection.close();
    }
  }

  // ========== 서버 관리 메서드 ==========

  @override
  Future<List<ServerModel>> getServers() async {
    // SQLite에서 서버 목록을 가져오는 로직
    // 실제 구현은 SQLite handler나 별도 로컬 DB 핸들러에서 처리
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

  // ========== 데이터베이스 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getDatabases() {
    return _withConnection('postgres', (conn) async {
      final results = await conn.query(
          'SELECT d.datname FROM pg_database d WHERE d.datistemplate = false AND d.datallowconn = true;'
      );
      return results.map((row) => {'name': row[0] as String}).toList();
    });
  }

  @override
  Future<void> createDatabase(String dbName) {
    return _withConnection('postgres', (conn) => conn.query('CREATE DATABASE "$dbName"'));
  }

  @override
  Future<void> renameDatabase(String oldName, String newName) {
    return _withConnection('postgres', (conn) => conn.query('ALTER DATABASE "$oldName" RENAME TO "$newName"'));
  }

  @override
  Future<void> deleteDatabase(String dbName) {
    return _withConnection('postgres', (conn) => conn.query('DROP DATABASE "$dbName"'));
  }

  // ========== 테이블 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getTables(String databaseName) {
    return _withConnection(databaseName, (conn) async {
      final results = await conn.query('''
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
      ''');
      return results.map((row) => {'name': row[0] as String}).toList();
    });
  }

  @override
  Future<void> createTable(String tableName, Map<String, String> columns) {
    return _withConnection(databaseName!, (conn) {
      final columnDefs = columns.entries
          .map((e) => '"${e.key}" ${e.value}')
          .join(', ');
      return conn.query('CREATE TABLE "$tableName" ($columnDefs)');
    });
  }

  @override
  Future<void> renameTable(String oldName, String newName) {
    return _withConnection(databaseName!, (conn) {
      return conn.query('ALTER TABLE "$oldName" RENAME TO "$newName"');
    });
  }

  @override
  Future<void> deleteTable(String tableName) {
    return _withConnection(databaseName!, (conn) {
      return conn.query('DROP TABLE "$tableName"');
    });
  }

  // ========== 컬럼 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getColumns(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      final results = await conn.query('''
        SELECT column_name, data_type 
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = '$tableName';
      ''');
      return results.map((row) => {'name': row[0], 'type': row[1]}).toList();
    });
  }

  @override
  Future<String?> getPrimaryKey(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      final pkResult = await conn.query(
        "SELECT kcu.column_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_name = @tableName",
        substitutionValues: {'tableName': tableName},
      );
      return pkResult.isNotEmpty ? pkResult.first[0] as String : null;
    });
  }

  @override
  Future<void> addColumn(String tableName, String columnName, String dataType, String constraints) {
    return _withConnection(databaseName!, (conn) {
      return conn.query('ALTER TABLE "$tableName" ADD COLUMN "$columnName" $dataType $constraints');
    });
  }

  @override
  Future<void> modifyColumn(String tableName, String oldColumnName, String newColumnName, String newDataType, String newConstraints) {
    return _withConnection(databaseName!, (conn) async {
      if (oldColumnName != newColumnName) {
        await conn.query('ALTER TABLE "$tableName" RENAME COLUMN "$oldColumnName" TO "$newColumnName"');
      }
      final query = 'ALTER TABLE "$tableName" ALTER COLUMN "$newColumnName" TYPE $newDataType USING "$newColumnName"::text::$newDataType';
      await conn.query(query);
    });
  }

  @override
  Future<void> deleteColumn(String tableName, String columnName) {
    return _withConnection(databaseName!, (conn) {
      return conn.query('ALTER TABLE "$tableName" DROP COLUMN "$columnName"');
    });
  }

  // ========== 데이터 조회/조작 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getData(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      final results = await conn.query('SELECT * FROM "$tableName"');
      return results.map((row) => row.toColumnMap()).toList();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getDataWithFilters(
      String tableName, {
        List<Map<String, dynamic>>? filters,
        List<Map<String, dynamic>>? sorts,
        List<String>? groupByColumns,
      }) {
    return _withConnection(databaseName!, (conn) async {
      final substitutionValues = <String, dynamic>{};

      String selectClause;
      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        selectClause = 'SELECT ${groupByColumns.map((c) => '"$c"').join(', ')} FROM "$tableName"';
      } else {
        selectClause = 'SELECT * FROM "$tableName"';
      }

      var query = selectClause;

      // WHERE 절 생성
      if (filters != null && filters.isNotEmpty) {
        final whereClauses = <String>[];
        int paramIndex = 0;

        final Map<int?, List<Map<String, dynamic>>> groupedFilters = {};
        for (final filter in filters) {
          final groupIndex = filter['groupIndex'] as int?;
          groupedFilters.putIfAbsent(groupIndex, () => []).add(filter);
        }

        final sortedGroups = groupedFilters.keys.toList()
          ..sort((a, b) {
            if (a == null && b == null) return 0;
            if (a == null) return -1;
            if (b == null) return 1;
            return a.compareTo(b);
          });

        for (int groupIdx = 0; groupIdx < sortedGroups.length; groupIdx++) {
          final groupIndex = sortedGroups[groupIdx];
          final groupFilters = groupedFilters[groupIndex]!;
          final bool hasGroup = groupIndex != null;

          if (hasGroup) {
            whereClauses.add('(');
          }

          for (int i = 0; i < groupFilters.length; i++) {
            final filter = groupFilters[i];
            final column = filter['column'] as String;
            final operator = filter['operator'] as String;
            final value = filter['value'];
            final logicalOperator = filter['logicalOperator'] as String?;

            String condition;
            switch (operator.toUpperCase()) {
              case 'IS NULL':
                condition = '"$column" IS NULL';
                break;
              case 'IS NOT NULL':
                condition = '"$column" IS NOT NULL';
                break;
              case 'IN':
                if (value is List) {
                  final paramNames = <String>[];
                  for (int j = 0; j < value.length; j++) {
                    final paramName = 'param$paramIndex';
                    paramNames.add('@$paramName');
                    substitutionValues[paramName] = value[j];
                    paramIndex++;
                  }
                  condition = '"$column" IN (${paramNames.join(', ')})';
                } else {
                  condition = '"$column" = @param$paramIndex';
                  substitutionValues['param$paramIndex'] = value;
                  paramIndex++;
                }
                break;
              case 'NOT IN':
                if (value is List) {
                  final paramNames = <String>[];
                  for (int j = 0; j < value.length; j++) {
                    final paramName = 'param$paramIndex';
                    paramNames.add('@$paramName');
                    substitutionValues[paramName] = value[j];
                    paramIndex++;
                  }
                  condition = '"$column" NOT IN (${paramNames.join(', ')})';
                } else {
                  condition = '"$column" != @param$paramIndex';
                  substitutionValues['param$paramIndex'] = value;
                  paramIndex++;
                }
                break;
              case 'LIKE':
                condition = '"$column" LIKE @param$paramIndex';
                substitutionValues['param$paramIndex'] = value;
                paramIndex++;
                break;
              default:
                condition = '"$column" $operator @param$paramIndex';
                substitutionValues['param$paramIndex'] = value;
                paramIndex++;
            }

            whereClauses.add(condition);

            if (i < groupFilters.length - 1 && logicalOperator != null) {
              whereClauses.add(logicalOperator.toUpperCase());
            }
          }

          if (hasGroup) {
            whereClauses.add(')');
          }

          if (groupIdx < sortedGroups.length - 1) {
            final lastFilterInGroup = groupFilters.last;
            final logicalOp = lastFilterInGroup['logicalOperator'] as String? ?? 'AND';
            whereClauses.add(logicalOp.toUpperCase());
          }
        }

        if (whereClauses.isNotEmpty) {
          query += ' WHERE ${whereClauses.join(' ')}';
        }
      }

      // GROUP BY 절
      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        query += ' GROUP BY ${groupByColumns.map((c) => '"$c"').join(', ')}';
      }

      // ORDER BY 절
      if (sorts != null && sorts.isNotEmpty) {
        final orderByClauses = sorts.map((sort) {
          final column = sort['column'] as String;
          final ascending = sort['ascending'] as bool;
          if (groupByColumns != null && groupByColumns.isNotEmpty) {
            if (!groupByColumns.contains(column)) {
              return null;
            }
          }
          return '"$column" ${ascending ? 'ASC' : 'DESC'}';
        }).where((clause) => clause != null).join(', ');
        if (orderByClauses.isNotEmpty) {
          query += ' ORDER BY $orderByClauses';
        }
      }

      final results = await conn.query(query, substitutionValues: substitutionValues.isEmpty ? null : substitutionValues);
      return results.map((row) => row.toColumnMap()).toList();
    });
  }

  @override
  Future<void> addRow(String tableName, Map<String, dynamic> data) {
    return _withConnection(databaseName!, (conn) {
      final query = data.isEmpty
          ? 'INSERT INTO "$tableName" DEFAULT VALUES'
          : 'INSERT INTO "$tableName" (${data.keys.map((k) => '"$k"').join(',')}) VALUES (${data.keys.map((k) => '@$k').join(',')})';
      return conn.query(query, substitutionValues: data.isEmpty ? null : data);
    });
  }

  @override
  Future<void> updateRow(String tableName, Map<String, dynamic> data, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (conn) {
      final setClauses = data.keys.map((k) => '"$k" = @$k').join(',');
      final substitutionValues = {...data, 'primaryKeyValue': pkValue};
      final query = 'UPDATE "$tableName" SET $setClauses WHERE "$pkColumn" = @primaryKeyValue';
      return conn.query(query, substitutionValues: substitutionValues);
    });
  }

  @override
  Future<void> updateCell(String tableName, String columnName, dynamic newValue, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (conn) {
      final query = 'UPDATE "$tableName" SET "$columnName" = @newValue WHERE "$pkColumn" = @pkValue';
      return conn.query(query, substitutionValues: {
        'newValue': newValue,
        'pkValue': pkValue,
      });
    });
  }

  @override
  Future<void> deleteRow(String tableName, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (conn) {
      final query = 'DELETE FROM "$tableName" WHERE "$pkColumn" = @pkValue';
      return conn.query(query, substitutionValues: {'pkValue': pkValue});
    });
  }

  // ========== 트랜잭션 메서드 ==========

  @override
  Future<void> runInTransaction(Future<void> Function() operation) async {
    if (databaseName == null) {
      throw Exception('Database is not initialized');
    }
    await _withConnection(databaseName!, (conn) async {
      await conn.transaction((txn) async {
        await operation();
      });
    });
  }
}