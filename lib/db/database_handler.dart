abstract class DatabaseHandler {
  Future<List<Map<String, dynamic>>> getDatabases();
  Future<void> createDatabase(String dbName);
  Future<void> renameDatabase(String oldName, String newName);
  Future<void> deleteDatabase(String dbName);

  Future<List<Map<String, dynamic>>> getColumns(String tableName);
  Future<String?> getPrimaryKey(String tableName);
  Future<List<Map<String, dynamic>>> getData(String tableName);
  Future<void> addColumn(String tableName, String columnName, String dataType, String constraints);
  Future<void> modifyColumn(String tableName, String oldColumnName, String newColumnName, String newDataType, String newConstraints);
  Future<void> deleteColumn(String tableName, String columnName);
  Future<void> deleteRow(String tableName, String pkColumn, dynamic pkValue);
  Future<void> addRow(String tableName, Map<String, dynamic> data);
  Future<void> updateRow(String tableName, Map<String, dynamic> data, String pkColumn, dynamic pkValue);
  Future<void> updateCell(String tableName, String columnName, dynamic newValue, String pkColumn, dynamic pkValue);
}
