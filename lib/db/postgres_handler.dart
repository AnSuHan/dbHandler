import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import 'package:db_handler/sqflite/models/server_model.dart';
import 'database_handler.dart';

class PostgresHandler extends DatabaseHandler {
  final ServerModel server;
  final String? databaseName;

  // 캐싱을 위한 정적/인스턴스 변수
  static final Map<String, List<Map<String, dynamic>>> _databasesCache = {};
  static final Map<String, Map<String, List<Map<String, dynamic>>>> _tablesCache = {};

  PostgresHandler(this.server, {this.databaseName});

  String get _serverKey => '${server.address}_${server.username}';

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

    try {
      // postgres 3.5.9 방식
      final connection = await Connection.open(
        endpoint,
        settings: const ConnectionSettings(
          sslMode: SslMode.disable,
          connectTimeout: Duration(seconds: 10),
        ),
      );
      return connection;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('password authentication failed') || 
          errorStr.contains('invalid password') ||
          errorStr.contains('severity error') && errorStr.contains('password')) {
        throw Exception('로그인 실패 (아이디 또는 비밀번호를 확인해주세요)');
      }
      rethrow;
    }
  }

  Future<T> _withConnection<T>(
      String dbName, Future<T> Function(Connection) action) async {
    try {
      final connection = await _getConnection(dbName);
      try {
        return await action(connection);
      } finally {
        await connection.close();
      }
    } catch (e) {
      rethrow;
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

  @override
  void clearCache() {
    _databasesCache.remove(_serverKey);
    _tablesCache.remove(_serverKey);
  }

  @override
  Future<int> getTableCount(String databaseName) async {
    try {
      return await _withConnection(databaseName, (conn) async {
        final result = await conn.execute('''
          SELECT count(*) 
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relkind = 'r' 
            AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        ''');
        final map = result.first.toColumnMap();
        return (map['count'] is BigInt) 
            ? (map['count'] as BigInt).toInt() 
            : map['count'] as int;
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

    final dbNames = await _withConnection('postgres', (conn) async {
      // pg_database를 직접 조회하되, 템플릿이 아니고 연결 가능한 데이터베이스만 빠르게 필터링
      final results = await conn.execute(
          "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true AND datname <> 'postgres' ORDER BY datname;"
      );
      return results.map((row) => row[0] as String).toList();
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
    await _withConnection('postgres', (conn) => conn.execute('CREATE DATABASE "$dbName"'));
    _databasesCache.remove(_serverKey);
  }

  @override
  Future<void> renameDatabase(String oldName, String newName) async {
    await _withConnection('postgres', (conn) => conn.execute('ALTER DATABASE "$oldName" RENAME TO "$newName"'));
    _databasesCache.remove(_serverKey);
  }

  @override
  Future<void> deleteDatabase(String dbName) async {
    await _withConnection('postgres', (conn) => conn.execute('DROP DATABASE "$dbName"'));
    _databasesCache.remove(_serverKey);
  }

  // ========== 테이블 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getTables(String databaseName) async {
    if (_tablesCache[_serverKey]?.containsKey(databaseName) ?? false) {
      return _tablesCache[_serverKey]![databaseName]!;
    }

    final tables = await _withConnection(databaseName, (conn) async {
      // information_schema.tables 대신 pg_catalog를 직접 조회하여 성능 향상
      // reltuples를 사용하여 행 개수 근사값을 매우 빠르게 가져옴
      // 컬럼 수도 서브쿼리로 빠르게 가져옴
      final result = await conn.execute('''
      SELECT 
          n.nspname as table_schema, 
          c.relname as table_name,
          c.reltuples as row_count,
          (SELECT count(*) FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped) as column_count
      FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'r' 
        AND n.nspname NOT IN ('pg_catalog', 'information_schema')
      ORDER BY n.nspname, c.relname;
    ''');

      debugPrint("[getTables] result: ${result.toString()}");
      return result.map((row) {
        final map = row.toColumnMap();
        return {
          'table_schema': map['table_schema'],
          'name': map['table_name'],
          'row_count': (map['row_count'] is double) 
              ? (map['row_count'] as double).toInt() 
              : map['row_count'],
          'column_count': (map['column_count'] is BigInt) 
              ? (map['column_count'] as BigInt).toInt() 
              : map['column_count'],
        };
      }).toList();
    });

    _tablesCache[_serverKey] ??= {};
    _tablesCache[_serverKey]![databaseName] = tables;
    return tables;
  }

  @override
  Future<void> createTable(String tableName, Map<String, String> columns) async {
    await _withConnection(databaseName!, (conn) {
      final columnDefs = columns.entries
          .map((e) => '"${e.key}" ${e.value}')
          .join(', ');
      return conn.execute('CREATE TABLE "$tableName" ($columnDefs)');
    });
    _tablesCache[_serverKey]?.remove(databaseName);
  }

  @override
  Future<void> renameTable(String oldName, String newName) async {
    await _withConnection(databaseName!, (conn) {
      return conn.execute('ALTER TABLE "$oldName" RENAME TO "$newName"');
    });
    _tablesCache[_serverKey]?.remove(databaseName);
  }

  @override
  Future<void> deleteTable(String tableName) async {
    await _withConnection(databaseName!, (conn) {
      return conn.execute('DROP TABLE "$tableName"');
    });
    _tablesCache[_serverKey]?.remove(databaseName);
  }

  // ========== 컬럼 관리 메서드 ==========

  @override
  Future<List<Map<String, dynamic>>> getColumns(String tableName) {
    return _withConnection(databaseName!, (conn) async {
      // pg_catalog.pg_attribute를 직접 조회하여 성능 향상
      final result = await conn.execute(
        Sql.named('''
          SELECT a.attname AS name,
                 pg_catalog.format_type(a.atttypid, a.atttypmod) AS type
          FROM pg_catalog.pg_attribute a
          JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = @table
            AND a.attnum > 0
            AND NOT a.attisdropped
            AND n.nspname = 'public'
          ORDER BY a.attnum;
        '''),
        parameters: {'table': tableName},
      );

      return result.map((row) {
        final map = row.toColumnMap();
        return {
          'name': map['name'] as String,
          'type': map['type'] as String,
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
            condition = '"$column" $opUpper';
          } else if (opUpper == 'IN' || opUpper == 'NOT IN') {
            if (value is List && value.isNotEmpty) {
              final pNames = [];
              for (var v in value) {
                final pName = 'param$paramIndex';
                pNames.add('@$pName');
                substitutionValues[pName] = v;
                paramIndex++;
              }
              condition = '"$column" $opUpper (${pNames.join(', ')})';
            } else {
              condition = '"$column" ${opUpper == 'IN' ? '=' : '!='} @param$paramIndex';
              substitutionValues['param$paramIndex'] = value;
              paramIndex++;
            }
          } else if (opUpper == 'LIKE') {
            condition = '"$column" LIKE @param$paramIndex';
            substitutionValues['param$paramIndex'] = value;
            paramIndex++;
          } else {
            condition = '"$column" $operator @param$paramIndex';
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