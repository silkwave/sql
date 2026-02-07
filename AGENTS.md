# Repository Guidelines

## Project Structure & Module Organization
- 이 리포는 오라클 SQL 스크립트 모음입니다. 소스는 최상위 디렉터리의 `*.sql` 파일로 구성됩니다.
- 현재 별도의 `src/`, `tests/`, `assets/` 디렉터리는 없습니다. 스크립트는 기능별 파일로 분리되어 있습니다(예: `PIVOT_TB.sql`, `TEMPORARY_TABLE.sql`).

## Build, Test, and Development Commands
- 별도의 빌드 시스템은 없습니다. 오라클 클라이언트에서 스크립트를 직접 실행합니다.
- 예시(환경에 맞게 변경):
  - `sqlplus user/password@db @RUN.sql` : 통합 실행 스크립트가 있을 경우 순차 실행.
  - `sqlplus user/password@db @PIVOT_TB.sql` : 개별 스크립트 실행.
- 실행 전 스키마/권한/테이블 존재 여부를 확인하세요.

## Coding Style & Naming Conventions
- 파일 확장자는 `.sql`로 유지하고, 기능 중심의 파일명을 사용합니다(예: `REPORT_SQL_MONITOR.sql`).
- SQL 키워드는 대문자 사용을 권장합니다(예: `SELECT`, `FROM`).
- 주석, 테이블/컬럼 설명은 한글로 작성합니다.
- 오라클 문법을 기본으로 사용합니다.

## Testing Guidelines
- 전용 테스트 프레임워크는 없습니다.
- 스크립트 실행 후 결과를 수동 검증합니다.
  - 예: `SELECT COUNT(*) FROM ...;`로 레코드 수 확인
  - 예: 샘플 데이터는 100만 건 이상을 기준으로 검증
- 변경 사항은 개발용 스키마에서 먼저 실행 후 본 환경으로 반영하세요.

## Commit & Pull Request Guidelines
- 최근 커밋 메시지는 간단한 단어(`sql`)로 기록되어 있습니다. 신규 커밋도 짧고 명확한 메시지를 사용하세요.
- PR에는 아래 정보를 포함하세요.
  - 변경 목적과 영향 범위
  - 수정/추가된 SQL 파일 목록
  - 실행 또는 검증 방법(예: 실행 명령, 확인 쿼리)

## Agent-Specific Instructions
- 답변은 한글로 작성합니다.
- 변경 사항은 열려 있는 파일에 반영합니다.
- 테이블/컬럼 주석은 한글로 작성합니다.
