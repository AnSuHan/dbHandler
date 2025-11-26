import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Database Manager'**
  String get appTitle;

  /// No description provided for @appSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Database Management System'**
  String get appSubTitle;

  /// Title for connected server section
  ///
  /// In en, this message translates to:
  /// **'Connected Server'**
  String get connectedServer;

  /// Title for server list screen
  ///
  /// In en, this message translates to:
  /// **'Server List'**
  String get serverList;

  /// Button to add a new server
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServer;

  /// Label for server name input
  ///
  /// In en, this message translates to:
  /// **'Server Name'**
  String get serverName;

  /// Label for host address input
  ///
  /// In en, this message translates to:
  /// **'Host Address'**
  String get hostAddress;

  /// Label for port input
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// Label for database type input
  ///
  /// In en, this message translates to:
  /// **'DB Type'**
  String get dbType;

  /// Label for test server toggle
  ///
  /// In en, this message translates to:
  /// **'Test Server'**
  String get testServer;

  /// No description provided for @addTestServer.
  ///
  /// In en, this message translates to:
  /// **'Add Test Server'**
  String get addTestServer;

  /// Title for account info dialog
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInfo;

  /// Label for username input
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Label for password input
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Label for SSH key file path
  ///
  /// In en, this message translates to:
  /// **'Key File Path'**
  String get keyFilePath;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Skip button text
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Title for edit server dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Server Information'**
  String get editServerInfo;

  /// Menu item for editing auth info
  ///
  /// In en, this message translates to:
  /// **'Edit Authentication Information'**
  String get editAuthInfo;

  /// Title for delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get deleteServer;

  /// Confirmation message for server deletion
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {serverName}?'**
  String deleteServerConfirm(String serverName);

  /// Message when server list is empty
  ///
  /// In en, this message translates to:
  /// **'No servers available. Press + button to add a server.'**
  String get noServers;

  /// Error message for empty required fields
  ///
  /// In en, this message translates to:
  /// **'Name, host, and port are required.'**
  String get requiredFields;

  /// Error message for duplicate server address
  ///
  /// In en, this message translates to:
  /// **'A server with the same address already exists.'**
  String get duplicateServer;

  /// Error message when loading servers fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load server list: {error}'**
  String serverLoadError(String error);

  /// Success message for creating a new database
  ///
  /// In en, this message translates to:
  /// **'Database {dbName} created successfully'**
  String createDatabaseSuccess(Object dbName);

  /// Error message for failed databasecreate a new database
  ///
  /// In en, this message translates to:
  /// **'Failed to create database'**
  String get createDatabaseFailure;

  /// Success message for renaming a database
  ///
  /// In en, this message translates to:
  /// **'Database {oldName} renamed to {newName}'**
  String renameDatabaseSuccess(Object newName, Object oldName);

  /// Error message for failed database rename
  ///
  /// In en, this message translates to:
  /// **'Failed to rename database'**
  String get renameDatabaseFailure;

  /// Success message for deleting a database
  ///
  /// In en, this message translates to:
  /// **'Database {dbName} deleted successfully'**
  String deleteDatabaseSuccess(Object dbName);

  /// No description provided for @deleteDatabase.
  ///
  /// In en, this message translates to:
  /// **'Delete database'**
  String get deleteDatabase;

  /// No description provided for @deleteDatabaseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the database {dbName}? This action cannot be undone.'**
  String deleteDatabaseConfirm(Object dbName);

  /// Error message for failed database deletion
  ///
  /// In en, this message translates to:
  /// **'Failed to delete database'**
  String get deleteDatabaseFailure;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @newDatabase.
  ///
  /// In en, this message translates to:
  /// **'New Database'**
  String get newDatabase;

  /// No description provided for @noDatabaseFound.
  ///
  /// In en, this message translates to:
  /// **'No databases found. Please add a new one.'**
  String get noDatabaseFound;

  /// Title for create new database dialog
  ///
  /// In en, this message translates to:
  /// **'Create New Database'**
  String get createNewDatabase;

  /// Label for database name input
  ///
  /// In en, this message translates to:
  /// **'Database Name'**
  String get databaseName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @editDatabaseName.
  ///
  /// In en, this message translates to:
  /// **'Edit Database Name'**
  String get editDatabaseName;

  /// No description provided for @newDatabaseName.
  ///
  /// In en, this message translates to:
  /// **'New Database Name'**
  String get newDatabaseName;

  /// No description provided for @failedToLoadTable.
  ///
  /// In en, this message translates to:
  /// **'Failed to Load Table List'**
  String get failedToLoadTable;

  /// No description provided for @tableCreationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success to Create table {tableName}'**
  String tableCreationSuccess(Object tableName);

  /// No description provided for @tableCreationFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to Create Table'**
  String get tableCreationFailure;

  /// No description provided for @renameTableSuccess.
  ///
  /// In en, this message translates to:
  /// **'Rename tableName Complete from {oldName} to {newName}'**
  String renameTableSuccess(Object newName, Object oldName);

  /// No description provided for @renameTableFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename TableName'**
  String get renameTableFailure;

  /// No description provided for @deleteTableSuccess.
  ///
  /// In en, this message translates to:
  /// **'Remove {tableName} Table Completed'**
  String deleteTableSuccess(Object tableName);

  /// No description provided for @deleteTableFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete Table'**
  String get deleteTableFailure;

  /// No description provided for @deleteTable.
  ///
  /// In en, this message translates to:
  /// **'Delete Table'**
  String get deleteTable;

  /// No description provided for @deleteTableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {tableName} table? This action is irreversible.'**
  String deleteTableConfirm(Object tableName);

  /// No description provided for @createNewTable.
  ///
  /// In en, this message translates to:
  /// **'Create New Table'**
  String get createNewTable;

  /// No description provided for @tableName.
  ///
  /// In en, this message translates to:
  /// **'Table Name'**
  String get tableName;

  /// No description provided for @modifyTableName.
  ///
  /// In en, this message translates to:
  /// **'Modify Table Name'**
  String get modifyTableName;

  /// No description provided for @newTableName.
  ///
  /// In en, this message translates to:
  /// **'New Table Name'**
  String get newTableName;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @selectedDatabase.
  ///
  /// In en, this message translates to:
  /// **'Selected Database'**
  String get selectedDatabase;

  /// No description provided for @newTable.
  ///
  /// In en, this message translates to:
  /// **'New Table'**
  String get newTable;

  /// No description provided for @noTableExist.
  ///
  /// In en, this message translates to:
  /// **'No Table Exist. Add New Table.'**
  String get noTableExist;

  /// No description provided for @column.
  ///
  /// In en, this message translates to:
  /// **'column'**
  String get column;

  /// No description provided for @row.
  ///
  /// In en, this message translates to:
  /// **'row'**
  String get row;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @cellCopied.
  ///
  /// In en, this message translates to:
  /// **'{cellCount} cell(s) copied to clipboard.'**
  String cellCopied(Object cellCount);

  /// No description provided for @cellPasteSuccess.
  ///
  /// In en, this message translates to:
  /// **'{cellCount} cell(s) pasted successfully.'**
  String cellPasteSuccess(Object cellCount);

  /// No description provided for @cellPasteSuccessPartial.
  ///
  /// In en, this message translates to:
  /// **'{successCount} cell(s) pasted, {failCount} failed.'**
  String cellPasteSuccessPartial(Object failCount, Object successCount);

  /// No description provided for @cannotPastePk.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot paste without a primary key.'**
  String get cannotPastePk;

  /// No description provided for @cannotPasteNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to paste from clipboard.'**
  String get cannotPasteNothing;

  /// No description provided for @transactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transaction failed: {error}'**
  String transactionFailed(Object error);

  /// No description provided for @dataEditing.
  ///
  /// In en, this message translates to:
  /// **'Data Editing'**
  String get dataEditing;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @addRow.
  ///
  /// In en, this message translates to:
  /// **'Add Row'**
  String get addRow;

  /// No description provided for @addColumn.
  ///
  /// In en, this message translates to:
  /// **'Add Column'**
  String get addColumn;

  /// No description provided for @tableHasNoColumn.
  ///
  /// In en, this message translates to:
  /// **'Table has no columns. Please add one.'**
  String get tableHasNoColumn;

  /// No description provided for @addNewColumn.
  ///
  /// In en, this message translates to:
  /// **'Add New Column'**
  String get addNewColumn;

  /// No description provided for @columnName.
  ///
  /// In en, this message translates to:
  /// **'Column Name'**
  String get columnName;

  /// No description provided for @selectDataType.
  ///
  /// In en, this message translates to:
  /// **'Select Data Type'**
  String get selectDataType;

  /// No description provided for @constraints.
  ///
  /// In en, this message translates to:
  /// **'Constraints'**
  String get constraints;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @requiredAddingNewColumn.
  ///
  /// In en, this message translates to:
  /// **'Column name and data type are required.'**
  String get requiredAddingNewColumn;

  /// No description provided for @columnAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Column added successfully.'**
  String get columnAddedSuccess;

  /// No description provided for @modifyColumn.
  ///
  /// In en, this message translates to:
  /// **'Modify Column'**
  String get modifyColumn;

  /// No description provided for @modifyColumnSuccess.
  ///
  /// In en, this message translates to:
  /// **'Column modified successfully.'**
  String get modifyColumnSuccess;

  /// No description provided for @modify.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get modify;

  /// No description provided for @addNewRow.
  ///
  /// In en, this message translates to:
  /// **'Add New Row'**
  String get addNewRow;

  /// No description provided for @editRow.
  ///
  /// In en, this message translates to:
  /// **'Edit Row'**
  String get editRow;

  /// No description provided for @addRowSuccess.
  ///
  /// In en, this message translates to:
  /// **'Row added successfully.'**
  String get addRowSuccess;

  /// No description provided for @updateRowSuccess.
  ///
  /// In en, this message translates to:
  /// **'Row updated successfully.'**
  String get updateRowSuccess;

  /// No description provided for @addRowFailurePK.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot update without a primary key'**
  String get addRowFailurePK;

  /// No description provided for @deleteFailedPk.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot delete without a primary key.'**
  String get deleteFailedPk;

  /// No description provided for @deleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete Row'**
  String get deleteRow;

  /// No description provided for @deleteRowConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this row? (Primary Key: {pkValue})'**
  String deleteRowConfirm(Object pkValue);

  /// No description provided for @deleteRowSuccess.
  ///
  /// In en, this message translates to:
  /// **'Row deleted successfully.'**
  String get deleteRowSuccess;

  /// No description provided for @copyCell.
  ///
  /// In en, this message translates to:
  /// **'Copy Cell'**
  String get copyCell;

  /// No description provided for @pasteCell.
  ///
  /// In en, this message translates to:
  /// **'Paste Cell'**
  String get pasteCell;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @cannotEditCellPK.
  ///
  /// In en, this message translates to:
  /// **'Error: Cannot edit cell without a primary key.'**
  String get cannotEditCellPK;

  /// No description provided for @editCell.
  ///
  /// In en, this message translates to:
  /// **'Edit Cell'**
  String get editCell;

  /// No description provided for @updateCellSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cell updated successfully.'**
  String get updateCellSuccess;

  /// No description provided for @filterMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter, Sort & Group'**
  String get filterMenuTitle;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @addFilter.
  ///
  /// In en, this message translates to:
  /// **'Add Filter'**
  String get addFilter;

  /// No description provided for @addParenthesis.
  ///
  /// In en, this message translates to:
  /// **'Add ( )'**
  String get addParenthesis;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @noteAddFilter.
  ///
  /// In en, this message translates to:
  /// **'Click \"{addFilter}\" button for Adding Filter'**
  String noteAddFilter(Object addFilter);

  /// No description provided for @operator.
  ///
  /// In en, this message translates to:
  /// **'Op'**
  String get operator;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @sorts.
  ///
  /// In en, this message translates to:
  /// **'Sorts'**
  String get sorts;

  /// No description provided for @addSort.
  ///
  /// In en, this message translates to:
  /// **'Add Sort'**
  String get addSort;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group By'**
  String get groupBy;

  /// No description provided for @addGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Group'**
  String get addGroup;

  /// No description provided for @currentState.
  ///
  /// In en, this message translates to:
  /// **'Current State'**
  String get currentState;

  /// No description provided for @noConditionApplied.
  ///
  /// In en, this message translates to:
  /// **'No filters, sorts, or groups applied.'**
  String get noConditionApplied;

  /// No description provided for @asc.
  ///
  /// In en, this message translates to:
  /// **'ASC'**
  String get asc;

  /// No description provided for @desc.
  ///
  /// In en, this message translates to:
  /// **'DESC'**
  String get desc;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @allColumnGrouped.
  ///
  /// In en, this message translates to:
  /// **'All columns are already in group by.'**
  String get allColumnGrouped;

  /// No description provided for @addGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Add Group By'**
  String get addGroupBy;

  /// No description provided for @filterConditionError.
  ///
  /// In en, this message translates to:
  /// **'Filter Condition is not Correct'**
  String get filterConditionError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
