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
