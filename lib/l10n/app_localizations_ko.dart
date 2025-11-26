// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '데이터베이스 관리자';

  @override
  String get appSubTitle => '데이터베이스 관리 시스템';

  @override
  String get connectedServer => '접속 서버';

  @override
  String get serverList => '서버 목록';

  @override
  String get addServer => '서버 추가';

  @override
  String get serverName => '서버 이름';

  @override
  String get hostAddress => '호스트 주소';

  @override
  String get port => '포트';

  @override
  String get dbType => 'DB 타입';

  @override
  String get testServer => '테스트 서버';

  @override
  String get addTestServer => '테스트 서버 추가';

  @override
  String get accountInfo => '계정 정보 입력';

  @override
  String get account => '계정';

  @override
  String get password => '비밀번호';

  @override
  String get keyFilePath => '키 파일 경로';

  @override
  String get save => '저장';

  @override
  String get cancel => '취소';

  @override
  String get skip => '건너뛰기';

  @override
  String get delete => '삭제';

  @override
  String get edit => '수정';

  @override
  String get editServerInfo => '서버 정보 수정';

  @override
  String get editAuthInfo => '인증 정보 수정';

  @override
  String get deleteServer => '서버 삭제';

  @override
  String deleteServerConfirm(String serverName) {
    return '$serverName 서버를 삭제하시겠습니까?';
  }

  @override
  String get noServers => '서버가 없습니다. + 버튼을 눌러 서버를 추가해주세요.';

  @override
  String get requiredFields => '이름, 호스트, 포트는 필수입니다.';

  @override
  String get duplicateServer => '동일한 주소의 서버가 이미 존재합니다.';

  @override
  String serverLoadError(String error) {
    return '서버 목록 로딩 실패: $error';
  }

  @override
  String createDatabaseSuccess(Object dbName) {
    return '$dbName 데이터베이스 생성 성공';
  }

  @override
  String get createDatabaseFailure => '데이터베이스 생성 실패';

  @override
  String renameDatabaseSuccess(Object newName, Object oldName) {
    return '데이터베이스 이름 $oldName(이)가 $newName로 변경되었습니다.';
  }

  @override
  String get renameDatabaseFailure => '데이터베이스 이름 변경에 실패하였습니다.';

  @override
  String deleteDatabaseSuccess(Object dbName) {
    return '데이터베이스 $dbName 삭제에 성공하였습니다.';
  }

  @override
  String get deleteDatabase => '데이터베이스 삭제';

  @override
  String deleteDatabaseConfirm(Object dbName) {
    return '데이터베이스 $dbName를 정말로 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get deleteDatabaseFailure => '데이터베이스 삭제에 실패하였습니다.';

  @override
  String get goBack => '뒤로 가기';

  @override
  String get newDatabase => '새로운 데이터베이스';

  @override
  String get noDatabaseFound => '데이터베이스가 존재하지 않습니다. 새로 생성해주세요.';

  @override
  String get createNewDatabase => '새로운 데이터베이스 생성';

  @override
  String get databaseName => '데이터베이스 이름';

  @override
  String get create => '생성하기';

  @override
  String get editDatabaseName => '데이터베이스 이름 수정하기';

  @override
  String get newDatabaseName => '새로운 데이터베이스 이름';

  @override
  String get failedToLoadTable => '테이블 목록을 불러오는데 실패했습니다';

  @override
  String tableCreationSuccess(Object tableName) {
    return '테이블 $tableName 생성 완료';
  }

  @override
  String get tableCreationFailure => '테이블 생성 실패';

  @override
  String renameTableSuccess(Object newName, Object oldName) {
    return '테이블 이름이 $oldName에서 $newName (으)로 변경되었습니다.';
  }

  @override
  String get renameTableFailure => '테이블 이름 변경에 실패하였습니다.';

  @override
  String deleteTableSuccess(Object tableName) {
    return '$tableName 테이블이 삭제되었습니다.';
  }

  @override
  String get deleteTableFailure => '테이블 삭제 실패';

  @override
  String get deleteTable => '테이블 삭제';

  @override
  String deleteTableConfirm(Object tableName) {
    return '$tableName 테이블을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get createNewTable => '새 테이블 생성';

  @override
  String get tableName => '테이블 이름';

  @override
  String get modifyTableName => '테이블 이름 수정';

  @override
  String get newTableName => '새 테이블 이름';

  @override
  String get database => '데이터베이스';

  @override
  String get selectedDatabase => '선택된 데이터베이스';

  @override
  String get newTable => '새 테이블';

  @override
  String get noTableExist => '테이블이 없습니다. 새 테이블을 추가해주세요.';

  @override
  String get column => '컬럼';

  @override
  String get row => '행';

  @override
  String get operationFailed => '작업 실패';

  @override
  String cellCopied(Object cellCount) {
    return '$cellCount 셀이 클립보드에 복사되었습니다.';
  }

  @override
  String cellPasteSuccess(Object cellCount) {
    return '$cellCount 셀에 붙여넣기가 성공했습니다.';
  }

  @override
  String cellPasteSuccessPartial(Object failCount, Object successCount) {
    return '$successCount cell(s) pasted, $failCount failed.';
  }

  @override
  String get cannotPastePk => '오류: 기본 키 없이는 붙여넣을 수 없습니다.';

  @override
  String get cannotPasteNothing => '클립보드에서 붙여넣을 내용이 없습니다.';

  @override
  String transactionFailed(Object error) {
    return '트랜잭션 실패: $error';
  }

  @override
  String get dataEditing => '데이터 수정';

  @override
  String get refresh => '다시 불러오기';

  @override
  String get addRow => '행 추가';

  @override
  String get addColumn => '열 추가';

  @override
  String get tableHasNoColumn => '테이블에 컬럼이 없습니다. 컬럼을 추가해주세요.';

  @override
  String get addNewColumn => '새로운 열 추가';

  @override
  String get columnName => '컬럼명';

  @override
  String get selectDataType => '데이터 타입 선택';

  @override
  String get constraints => '제약조건';

  @override
  String get add => '추가';

  @override
  String get requiredAddingNewColumn => '컬럼명과 데이터 타입이 필요합니다.';

  @override
  String get columnAddedSuccess => '컬럼 추가에 성공했습니다.';

  @override
  String get modifyColumn => '열 수정';

  @override
  String get modifyColumnSuccess => '열 수정에 섲공했습니다.';

  @override
  String get modify => '수정';

  @override
  String get addNewRow => '새로운 행 추가';

  @override
  String get editRow => '행 수정';

  @override
  String get addRowSuccess => '행 추가에 성공했습니다.';

  @override
  String get updateRowSuccess => '행 업데이트에 성공했습니다.';

  @override
  String get addRowFailurePK => '오류: PK 없이 추가할 수 없습니다.';

  @override
  String get deleteFailedPk => '오류: PK 없이 삭제할 수 없습니다.';

  @override
  String get deleteRow => '행 삭제';

  @override
  String deleteRowConfirm(Object pkValue) {
    return '이 행을 정말로 삭제하시겠습니까? (Primary Key: $pkValue)';
  }

  @override
  String get deleteRowSuccess => '행이 성공적으로 삭제되었습니다.';

  @override
  String get copyCell => '셀 복사';

  @override
  String get pasteCell => '셀 붙여넣기';

  @override
  String get actions => '작업';

  @override
  String get cannotEditCellPK => '오류: PK 없이 셀을 수정할 수 없습니다.';

  @override
  String get editCell => '셀 수정';

  @override
  String get updateCellSuccess => '셀 업데이트에 성공하였습니다.';

  @override
  String get filterMenuTitle => '필터, 정렬 & 그룹';

  @override
  String get filters => '필터';

  @override
  String get addFilter => '필터 추가';

  @override
  String get addParenthesis => '추가 ( )';

  @override
  String get clearAll => '전체 삭제';

  @override
  String noteAddFilter(Object addFilter) {
    return '조건을 추가하려면 \"$addFilter\" 버튼을 클릭하세요';
  }

  @override
  String get operator => '연산자';

  @override
  String get value => '값';

  @override
  String get sorts => '정렬';

  @override
  String get addSort => '정렬 추가';

  @override
  String get group => '그룹';

  @override
  String get groupBy => '그룹';

  @override
  String get addGroup => '그룹 추가';

  @override
  String get currentState => '현재 상태';

  @override
  String get noConditionApplied => '적용된 필터, 정렬, 그룹이 존재하지 않습니다.';

  @override
  String get asc => '오름차순';

  @override
  String get desc => '내림차순';

  @override
  String get order => '정렬';

  @override
  String get allColumnGrouped => '모든 컬럼이 이미 그룹지어져 있습니다.';

  @override
  String get addGroupBy => '그룹 추가';

  @override
  String get filterConditionError => '필터 조건이 올바르지 않습니다.';
}
