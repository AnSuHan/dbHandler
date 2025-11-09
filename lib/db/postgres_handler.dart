import 'package:postgres/postgres.dart';
import 'database_handler.dart';

class PostgresHandler extends DatabaseHandler {
  final Map<String, dynamic> server;
  final String? database;

  PostgresHandler(this.server, {this.database});

  Future<PostgreSQLConnection> _getConnection(String db) async {
    final host = server['address'].split(':')[0];
    final port = int.parse(server['address'].split(':')[1]);
    final username = server['username'] as String?;
    final password = server['password'] as String?;

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

  @override
  Future<List<Map<String, dynamic>>> getDatabases() {
    return _withConnection('postgres', (conn) async {
      final results = await conn.query('SELECT d.datname FROM pg_database d WHERE d.datistemplate = false AND d.datallowconn = true;');
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

  @override
  Future<List<Map<String, dynamic>>> getColumns(String tableName) {
    return _withConnection(database!, (conn) async {
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
    return _withConnection(database!, (conn) async {
      final pkResult = await conn.query(
        "SELECT kcu.column_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_name = @tableName",
        substitutionValues: {'tableName': tableName},
      );
      return pkResult.isNotEmpty ? pkResult.first[0] as String : null;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getData(String tableName) {
    return _withConnection(database!, (conn) async {
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
    return _withConnection(database!, (conn) async {
      final substitutionValues = <String, dynamic>{};
      
      // GROUP BY가 사용되는 경우 SELECT 절을 다르게 구성
      String selectClause;
      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        // GROUP BY를 사용할 때는 GROUP BY에 포함된 컬럼만 선택
        // 다른 컬럼은 집계 함수로 감싸거나 제외해야 함
        // 여기서는 GROUP BY 컬럼만 선택 (중복 제거 목적)
        selectClause = 'SELECT ${groupByColumns.map((c) => '"$c"').join(', ')} FROM "$tableName"';
      } else {
        // GROUP BY가 없을 때는 모든 컬럼 선택
        selectClause = 'SELECT * FROM "$tableName"';
      }
      
      var query = selectClause;
      
      // WHERE 절 생성 (필터)
      if (filters != null && filters.isNotEmpty) {
        final whereClauses = <String>[];
        int paramIndex = 0;
        
        // 그룹별로 필터 분류
        final Map<int?, List<Map<String, dynamic>>> groupedFilters = {};
        for (final filter in filters) {
          final groupIndex = filter['groupIndex'] as int?;
          groupedFilters.putIfAbsent(groupIndex, () => []).add(filter);
        }
        
        // 그룹 인덱스로 정렬 (null이 먼저, 그 다음 숫자 순서)
        final sortedGroups = groupedFilters.keys.toList()
          ..sort((a, b) {
            if (a == null && b == null) return 0;
            if (a == null) return -1;
            if (b == null) return 1;
            return a.compareTo(b);
          });
        
        // 각 그룹 처리
        for (int groupIdx = 0; groupIdx < sortedGroups.length; groupIdx++) {
          final groupIndex = sortedGroups[groupIdx];
          final groupFilters = groupedFilters[groupIndex]!;
          final bool hasGroup = groupIndex != null;
          
          // 그룹 시작
          if (hasGroup) {
            whereClauses.add('(');
          }
          
          // 그룹 내 필터 처리
          for (int i = 0; i < groupFilters.length; i++) {
            final filter = groupFilters[i];
            final column = filter['column'] as String;
            final operator = filter['operator'] as String;
            final value = filter['value'];
            final logicalOperator = filter['logicalOperator'] as String?;
            
            // 조건 추가
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
            
            // 그룹 내 논리 연산자 추가 (마지막 필터가 아닌 경우)
            if (i < groupFilters.length - 1 && logicalOperator != null) {
              whereClauses.add(logicalOperator.toUpperCase());
            }
          }
          
          // 그룹 끝
          if (hasGroup) {
            whereClauses.add(')');
          }
          
          // 그룹 사이 논리 연산자 추가 (마지막 그룹이 아닌 경우)
          // 마지막 필터의 logicalOperator를 사용하거나, 기본값으로 AND 사용
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
      
      // GROUP BY 절 생성
      if (groupByColumns != null && groupByColumns.isNotEmpty) {
        query += ' GROUP BY ${groupByColumns.map((c) => '"$c"').join(', ')}';
      }
      
      // ORDER BY 절 생성 (정렬)
      // GROUP BY를 사용할 때는 ORDER BY에 GROUP BY 컬럼만 사용하거나 집계 함수 사용 가능
      if (sorts != null && sorts.isNotEmpty) {
        final orderByClauses = sorts.map((sort) {
          final column = sort['column'] as String;
          final ascending = sort['ascending'] as bool;
          // GROUP BY를 사용할 때는 ORDER BY에 GROUP BY 컬럼만 허용
          if (groupByColumns != null && groupByColumns.isNotEmpty) {
            if (!groupByColumns.contains(column)) {
              // GROUP BY에 포함되지 않은 컬럼은 ORDER BY에서 제외
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
  Future<void> addColumn(String tableName, String columnName, String dataType, String constraints) {
     return _withConnection(database!, (conn) {
      return conn.query('ALTER TABLE "$tableName" ADD COLUMN "$columnName" $dataType $constraints');
    });
  }

  @override
  Future<void> modifyColumn(String tableName, String oldColumnName, String newColumnName, String newDataType, String newConstraints) {
    return _withConnection(database!, (conn) async {
      if (oldColumnName != newColumnName) {
        await conn.query('ALTER TABLE "$tableName" RENAME COLUMN "$oldColumnName" TO "$newColumnName"');
      }
      final query = 'ALTER TABLE "$tableName" ALTER COLUMN "$newColumnName" TYPE $newDataType USING "$newColumnName"::text::$newDataType';
      await conn.query(query);
      // Constraints modification would be more complex, this is a simplified version
    });
  }

  @override
  Future<void> deleteColumn(String tableName, String columnName) {
    return _withConnection(database!, (conn) {
      return conn.query('ALTER TABLE "$tableName" DROP COLUMN "$columnName"');
    });
  }

  @override
  Future<void> deleteRow(String tableName, String pkColumn, dynamic pkValue) {
    return _withConnection(database!, (conn) {
      final query = 'DELETE FROM "$tableName" WHERE "$pkColumn" = @pkValue';
      return conn.query(query, substitutionValues: {'pkValue': pkValue});
    });
  }

  @override
  Future<void> addRow(String tableName, Map<String, dynamic> data) {
    return _withConnection(database!, (conn) {
      final query = data.isEmpty
          ? 'INSERT INTO "$tableName" DEFAULT VALUES'
          : 'INSERT INTO "$tableName" (${data.keys.map((k) => '"$k"').join(',')}) VALUES (${data.keys.map((k) => '@$k').join(',')})';
      return conn.query(query, substitutionValues: data.isEmpty ? null : data);
    });
  }

  @override
  Future<void> updateRow(String tableName, Map<String, dynamic> data, String pkColumn, dynamic pkValue) {
    return _withConnection(database!, (conn) {
      final setClauses = data.keys.map((k) => '"$k" = @$k').join(',');
      final substitutionValues = {...data, 'primaryKeyValue': pkValue};
      final query = 'UPDATE "$tableName" SET $setClauses WHERE "$pkColumn" = @primaryKeyValue';
      return conn.query(query, substitutionValues: substitutionValues);
    });
  }

  @override
  Future<void> updateCell(String tableName, String columnName, dynamic newValue, String pkColumn, dynamic pkValue) {
    return _withConnection(database!, (conn) {
      final query = 'UPDATE "$tableName" SET "$columnName" = @newValue WHERE "$pkColumn" = @pkValue';
      return conn.query(query, substitutionValues: {
        'newValue': newValue,
        'pkValue': pkValue,
      });
    });
  }
}
