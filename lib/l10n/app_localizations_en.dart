// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Database Manager';

  @override
  String get appSubTitle => 'Database Management System';

  @override
  String get connectedServer => 'Connected Server';

  @override
  String get serverList => 'Server List';

  @override
  String get addServer => 'Add Server';

  @override
  String get serverName => 'Server Name';

  @override
  String get hostAddress => 'Host Address';

  @override
  String get port => 'Port';

  @override
  String get dbType => 'DB Type';

  @override
  String get testServer => 'Test Server';

  @override
  String get addTestServer => 'Add Test Server';

  @override
  String get accountInfo => 'Account Information';

  @override
  String get account => 'Account';

  @override
  String get password => 'Password';

  @override
  String get keyFilePath => 'Key File Path';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get skip => 'Skip';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get editServerInfo => 'Edit Server Information';

  @override
  String get editAuthInfo => 'Edit Authentication Information';

  @override
  String get deleteServer => 'Delete Server';

  @override
  String deleteServerConfirm(String serverName) {
    return 'Are you sure you want to delete $serverName?';
  }

  @override
  String get noServers =>
      'No servers available. Press + button to add a server.';

  @override
  String get requiredFields => 'Name, host, and port are required.';

  @override
  String get duplicateServer =>
      'A server with the same address already exists.';

  @override
  String serverLoadError(String error) {
    return 'Failed to load server list: $error';
  }

  @override
  String createDatabaseSuccess(Object dbName) {
    return 'Database $dbName created successfully';
  }

  @override
  String get createDatabaseFailure => 'Failed to create database';

  @override
  String renameDatabaseSuccess(Object newName, Object oldName) {
    return 'Database $oldName renamed to $newName';
  }

  @override
  String get renameDatabaseFailure => 'Failed to rename database';

  @override
  String deleteDatabaseSuccess(Object dbName) {
    return 'Database $dbName deleted successfully';
  }

  @override
  String get deleteDatabase => 'Delete database';

  @override
  String deleteDatabaseConfirm(Object dbName) {
    return 'Are you sure you want to delete the database $dbName? This action cannot be undone.';
  }

  @override
  String get deleteDatabaseFailure => 'Failed to delete database';

  @override
  String get goBack => 'Go Back';

  @override
  String get newDatabase => 'New Database';

  @override
  String get noDatabaseFound => 'No databases found. Please add a new one.';

  @override
  String get createNewDatabase => 'Create New Database';

  @override
  String get databaseName => 'Database Name';

  @override
  String get create => 'Create';

  @override
  String get editDatabaseName => 'Edit Database Name';

  @override
  String get newDatabaseName => 'New Database Name';

  @override
  String get failedToLoadTable => 'Failed to Load Table List';

  @override
  String tableCreationSuccess(Object tableName) {
    return 'Success to Create table $tableName';
  }

  @override
  String get tableCreationFailure => 'Failed to Create Table';

  @override
  String renameTableSuccess(Object newName, Object oldName) {
    return 'Rename tableName Complete from $oldName to $newName';
  }

  @override
  String get renameTableFailure => 'Failed to rename TableName';

  @override
  String deleteTableSuccess(Object tableName) {
    return 'Remove $tableName Table Completed';
  }

  @override
  String get deleteTableFailure => 'Failed to delete Table';

  @override
  String get deleteTable => 'Delete Table';

  @override
  String deleteTableConfirm(Object tableName) {
    return 'Are you sure you want to delete $tableName table? This action is irreversible.';
  }

  @override
  String get createNewTable => 'Create New Table';

  @override
  String get tableName => 'Table Name';

  @override
  String get modifyTableName => 'Modify Table Name';

  @override
  String get newTableName => 'New Table Name';

  @override
  String get database => 'Database';

  @override
  String get selectedDatabase => 'Selected Database';

  @override
  String get newTable => 'New Table';

  @override
  String get noTableExist => 'No Table Exist. Add New Table.';

  @override
  String get column => 'column';

  @override
  String get row => 'row';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String cellCopied(Object cellCount) {
    return '$cellCount cell(s) copied to clipboard.';
  }

  @override
  String cellPasteSuccess(Object cellCount) {
    return '$cellCount cell(s) pasted successfully.';
  }

  @override
  String cellPasteSuccessPartial(Object failCount, Object successCount) {
    return '$successCount cell(s) pasted, $failCount failed.';
  }

  @override
  String get cannotPastePk => 'Error: Cannot paste without a primary key.';

  @override
  String get cannotPasteNothing => 'Nothing to paste from clipboard.';

  @override
  String transactionFailed(Object error) {
    return 'Transaction failed: $error';
  }

  @override
  String get dataEditing => 'Data Editing';

  @override
  String get refresh => 'Refresh';

  @override
  String get addRow => 'Add Row';

  @override
  String get addColumn => 'Add Column';

  @override
  String get tableHasNoColumn => 'Table has no columns. Please add one.';

  @override
  String get addNewColumn => 'Add New Column';

  @override
  String get columnName => 'Column Name';

  @override
  String get selectDataType => 'Select Data Type';

  @override
  String get constraints => 'Constraints';

  @override
  String get add => 'Add';

  @override
  String get requiredAddingNewColumn =>
      'Column name and data type are required.';

  @override
  String get columnAddedSuccess => 'Column added successfully.';

  @override
  String get modifyColumn => 'Modify Column';

  @override
  String get modifyColumnSuccess => 'Column modified successfully.';

  @override
  String get modify => 'Modify';

  @override
  String get addNewRow => 'Add New Row';

  @override
  String get editRow => 'Edit Row';

  @override
  String get addRowSuccess => 'Row added successfully.';

  @override
  String get updateRowSuccess => 'Row updated successfully.';

  @override
  String get addRowFailurePK => 'Error: Cannot update without a primary key';

  @override
  String get deleteFailedPk => 'Error: Cannot delete without a primary key.';

  @override
  String get deleteRow => 'Delete Row';

  @override
  String deleteRowConfirm(Object pkValue) {
    return 'Are you sure you want to delete this row? (Primary Key: $pkValue)';
  }

  @override
  String get deleteRowSuccess => 'Row deleted successfully.';

  @override
  String get copyCell => 'Copy Cell';

  @override
  String get pasteCell => 'Paste Cell';

  @override
  String get actions => 'Actions';

  @override
  String get cannotEditCellPK =>
      'Error: Cannot edit cell without a primary key.';

  @override
  String get editCell => 'Edit Cell';

  @override
  String get updateCellSuccess => 'Cell updated successfully.';

  @override
  String get filterMenuTitle => 'Filter, Sort & Group';

  @override
  String get filters => 'Filters';

  @override
  String get addFilter => 'Add Filter';

  @override
  String get addParenthesis => 'Add ( )';

  @override
  String get clearAll => 'Clear All';

  @override
  String noteAddFilter(Object addFilter) {
    return 'Click \"$addFilter\" button for Adding Filter';
  }

  @override
  String get operator => 'Op';

  @override
  String get value => 'Value';

  @override
  String get sorts => 'Sorts';

  @override
  String get addSort => 'Add Sort';

  @override
  String get group => 'Group';

  @override
  String get groupBy => 'Group By';

  @override
  String get addGroup => 'Add Group';

  @override
  String get currentState => 'Current State';

  @override
  String get noConditionApplied => 'No filters, sorts, or groups applied.';

  @override
  String get asc => 'ASC';

  @override
  String get desc => 'DESC';

  @override
  String get order => 'Order';

  @override
  String get allColumnGrouped => 'All columns are already in group by.';

  @override
  String get addGroupBy => 'Add Group By';

  @override
  String get filterConditionError => 'Filter Condition is not Correct';
}
