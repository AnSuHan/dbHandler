import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import 'package:db_handler/sqflite/models/server_model.dart';
import 'database_handler.dart';

class PostgresHandler extends DatabaseHandler {
  final ServerModel server;
  final String? databaseName;

  PostgresHandler(this.server, {this.databaseName});

  Future<Connection> _getConnection(String db) async {
    final host = server.address.split(':')[0];
    final port = int.parse(server.address.split(':')[1]);
    final username = server.username;
    final password = server.password;

    // Endpoint 생성 (새 API)
    final endpoint = Endpoint(
      host: host,
      port: port,
      database: db,
      username: username,
      password: password,
    );

    // postgres 3.5.9 방식
    final connection = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );

    return connection;
  }

  Future<T> _withConnection<T>(
      String dbName, Future<T> Function(Connection) action) async {  // 타입 변경
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
      final results = await conn.execute(
          'SELECT d.datname FROM pg_database d WHERE d.datistemplate = false AND d.datallowconn = true;'
      );
      return results.map((row) => {'name': row[0] as String}).toList();
    });
  }

  @override
  Future<void> createDatabase(String dbName) {
    return _withConnection('postgres', (conn) => conn.execute('CREATE DATABASE "$dbName"'));
  }

  @override
  Future<void> renameDatabase(String oldName, String newName) {
    return _withConnection('postgres', (conn) => conn.execute('ALTER DATABASE "$oldName" RENAME TO "$newName"'));
  }

  @override
  Future<void> deleteDatabase(String dbName) {
    return _withConnection('postgres', (conn) => conn.execute('DROP DATABASE "$dbName"'));
  }

  // ========== 테이블 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getTables(String databaseName) {
    return _withConnection(databaseName, (conn) async {
      final result = await conn.execute('''
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_type = 'BASE TABLE'
      ORDER BY table_schema, table_name;
    ''');

      debugPrint("[getTables] result: ${result.toString()}");
      return result.map((row) => row.toColumnMap()).toList();
    });
  }

  @override
  Future<void> createTable(String tableName, Map<String, String> columns) {
    return _withConnection(databaseName!, (conn) {
      final columnDefs = columns.entries
          .map((e) => '"${e.key}" ${e.value}')
          .join(', ');
      return conn.execute('CREATE TABLE "$tableName" ($columnDefs)');
    });
  }

  @override
  Future<void> renameTable(String oldName, String newName) {
    return _withConnection(databaseName!, (conn) {
      return conn.execute('ALTER TABLE "$oldName" RENAME TO "$newName"');
    });
  }

  @override
  Future<void> deleteTable(String tableName) {
    return _withConnection(databaseName!, (conn) {
      return conn.execute('DROP TABLE "$tableName"');
    });
  }

  // ========== 컬럼 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getColumns(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      // Sql.named() 사용
      final result = await conn.execute(
        Sql.named('''
          SELECT column_name, data_type
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = @table
        '''),
        parameters: {'table': tableName},
      );

      // 'name'과 'type' 키로 변환
      return result.map((row) {
        final map = row.toColumnMap();
        return {
          'name': map['column_name'] as String,
          'type': map['data_type'] as String,
        };
      }).toList();
    });
  }

  @override
  Future<String?> getPrimaryKey(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      final result = await conn.execute(
        Sql.named("""
        SELECT kcu.column_name 
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_name = @tableName
      """),
        parameters: {'tableName': tableName},
      );

      if (result.isEmpty) return null;

      return result.first.toColumnMap()['column_name'] as String?;
    });
  }

  @override
  Future<void> addColumn(String tableName, String columnName, String dataType, String constraints) {
    return _withConnection(databaseName!, (conn) {
      return conn.execute('ALTER TABLE "$tableName" ADD COLUMN "$columnName" $dataType $constraints');
    });
  }

  @override
  Future<void> modifyColumn(String tableName, String oldColumnName, String newColumnName, String newDataType, String newConstraints) {
    return _withConnection(databaseName!, (conn) async {
      if (oldColumnName != newColumnName) {
        await conn.execute('ALTER TABLE "$tableName" RENAME COLUMN "$oldColumnName" TO "$newColumnName"');
      }
      final query = 'ALTER TABLE "$tableName" ALTER COLUMN "$newColumnName" TYPE $newDataType USING "$newColumnName"::text::$newDataType';
      await conn.execute(query);
    });
  }

  @override
  Future<void> deleteColumn(String tableName, String columnName) {
    return _withConnection(databaseName!, (conn) {
      return conn.execute('ALTER TABLE "$tableName" DROP COLUMN "$columnName"');
    });
  }

  // ========== 데이터 조회/조작 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getData(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      final result = await conn.execute('SELECT * FROM "$tableName"');

      return result.map((row) => row.toColumnMap()).toList();
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
    return _withConnection(databaseName!, (conn) async {
      final substitutionValues = <String, dynamic>{};

      // GROUP BY가 있어도 SELECT *를 사용하여 모든 행 반환
      String selectClause = 'SELECT * FROM "$tableName"';
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

            final isNegated = filter['isNegated'] as bool? ?? false;
            final openGroupCount = filter['openGroupCount'] as int? ?? 0;
            final closeGroupCount = filter['closeGroupCount'] as int? ?? 0;

            // 여는 괄호 추가
            for (int p = 0; p < openGroupCount; p++) {
              whereClauses.add('(');
            }

            // NOT 접두사 추가
            if (isNegated) {
              whereClauses.add('NOT');
              whereClauses.add('(');
            }

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

            if (isNegated) {
              whereClauses.add(')');
            }

            for (int p = 0; p < closeGroupCount; p++) {
              whereClauses.add(')');
            }

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

      // ORDER BY 절 생성
      // groupByColumns가 있으면 해당 컬럼들로 먼저 정렬하고, sorts를 추가
      final orderByColumns = <String>[];

      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        // GROUP BY 컬럼들을 ORDER BY에 먼저 추가 (ASC 기본값)
        for (final col in groupByColumns) {
          orderByColumns.add('"$col" ASC');
        }
      }

      // 추가 정렬 조건 적용
      if (sorts != null && sorts.isNotEmpty) {
        for (final sort in sorts) {
          final column = sort['column'] as String;
          final ascending = sort['ascending'] as bool;
          final sortClause = '"$column" ${ascending ? 'ASC' : 'DESC'}';

          // 중복 방지: 이미 groupByColumns에 포함된 컬럼은 제외
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
          ? await conn.execute(query)
          : await conn.execute(Sql.named(query), parameters: substitutionValues);
      return results.map((row) => row.toColumnMap()).toList();
    });
  }

  @override
  Future<void> addRow(String tableName, Map<String, dynamic> data) {
    return _withConnection(databaseName!, (conn) async {
      if (data.isEmpty) {
        await conn.execute('INSERT INTO "$tableName" DEFAULT VALUES');
      } else {
        final query = 'INSERT INTO "$tableName" (${data.keys.map((k) => '"$k"').join(',')}) '
            'VALUES (${data.keys.map((k) => '@$k').join(',')})';
        await conn.execute(Sql.named(query), parameters: data);
      }
    });
  }

  @override
  Future<void> updateRow(String tableName, Map<String, dynamic> data, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (conn) async {
      final setClauses = data.keys.map((k) => '"$k" = @$k').join(',');
      final parameters = {...data, 'primaryKeyValue': pkValue};
      final query = 'UPDATE "$tableName" SET $setClauses WHERE "$pkColumn" = @primaryKeyValue';
      await conn.execute(Sql.named(query), parameters: parameters);
    });
  }

  @override
  Future<void> updateCell(String tableName, String columnName, dynamic newValue, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (conn) async {
      final query = 'UPDATE "$tableName" SET "$columnName" = @newValue WHERE "$pkColumn" = @pkValue';
      await conn.execute(
          Sql.named(query),
          parameters: {'newValue': newValue, 'pkValue': pkValue}
      );
    });
  }

  @override
  Future<void> deleteRow(String tableName, String pkColumn, dynamic pkValue) {
    return _withConnection(databaseName!, (conn) async {
      final query = 'DELETE FROM "$tableName" WHERE "$pkColumn" = @pkValue';
      await conn.execute(Sql.named(query), parameters: {'pkValue': pkValue});
    });
  }

// ========== 트랜잭션 메서드 ==========
  @override
  Future<void> runInTransaction(Future<void> Function() operation) async {
    if (databaseName == null) {
      throw Exception('Database is not initialized');
    }

    await _withConnection(databaseName!, (conn) async {
      await conn.runTx((ctx) async {
        await operation();
      });
    });
  }
}