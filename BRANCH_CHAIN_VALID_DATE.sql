/*
스크립트명: BRANCH_CHAIN_VALID_DATE.sql
목적:
  BRANCH_HISTORY 테이블을 생성하고, 특정 기준일(:TARGET_DATE)에 유효한 지점들을 대상으로
  지점-회계 지점 체인을 재귀 CTE로 추적하는 예제 SQL을 제공합니다.

사용 전제:
  - 오라클 SQL*Plus 또는 호환 클라이언트
  - 오라클 12c 이상 (재귀 CTE 및 CYCLE 절 사용)
  - 날짜는 'YYYYMMDD' 형식의 문자열 사용
*/

/*
**BRANCH_CHAIN_VALID_DATE.sql 상세 분석 및 설명**

이 SQL 스크립트는 지점(BRANCH)의 이력 정보를 관리하고, 특정 기준일에 유효한 지점-회계 지점(ACCT_BRANCH) 체인(Chain)을 추적하는 기능을 구현합니다. 주로 오라클 데이터베이스의 재귀 CTE(Common Table Expression)와 계층형 쿼리를 사용하여 복잡한 지점 구조 변화를 분석하는 데 초점을 맞추고 있습니다.

스크립트는 크게 다음과 같은 부분으로 구성됩니다:

1.  **스크립트 메타 정보**:
    *   스크립트의 목적, 사용 전제 조건 등을 설명합니다. 오라클 12c 이상의 버전에서 재귀 CTE와 CYCLE 절을 사용하는 것을 전제로 하며, 날짜는 'YYYYMMDD' 형식의 문자열을 사용합니다.

2.  **테이블 재생성 (DROP TABLE)**:
    *   `BRANCH_HISTORY` 테이블을 제거(DROP)하여 스크립트 실행 시 기존 테이블과의 충돌을 방지합니다. `EXCEPTION` 핸들링을 통해 테이블이 존재하지 않아 발생하는 오류(-942)는 무시하도록 하여 스크립트의 안정성을 높였습니다.

3.  **테이블 생성 및 주석 (CREATE TABLE, COMMENT ON)**:
    *   `BRANCH_HISTORY`라는 지점 이력 정보를 저장하는 테이블을 생성합니다.
    *   **컬럼 설명**:
        *   `BRANCH_CD`: 지점 코드 (VARCHAR2(4), NOT NULL)
        *   `REG_SEQ`: 등록 일련번호 (NUMBER, NOT NULL) - 같은 지점 코드 내에서의 이력 순번을 의미합니다.
        *   `BRANCH_NM`: 지점명 (VARCHAR2(100), NOT NULL)
        *   `ACCT_BRANCH_CD`: 회계 지점 코드 (VARCHAR2(4), NOT NULL) - 이 지점의 회계 처리를 담당하는 지점 코드를 나타냅니다. 체인 추적의 핵심이 됩니다.
        *   `OPEN_DT`: 개설 일자 (VARCHAR2(8), NOT NULL)
        *   `CLOSE_DT`: 폐쇄 일자 (VARCHAR2(8), DEFAULT '99991231', NOT NULL) - 폐쇄되지 않은 지점은 '99991231'로 설정됩니다.
        *   `UPD_USER_ID`: 수정 사용자 ID (VARCHAR2(20), NOT NULL)
        *   `UPD_DT`: 수정 일시 (TIMESTAMP, NOT NULL)
        *   `REMARK`: 비고 (VARCHAR2(200))
    *   **제약 조건**:
        *   `PK_BRANCH_HISTORY`: `(BRANCH_CD, REG_SEQ)`를 기본 키로 설정합니다.
        *   `CK_BRANCH_HISTORY_DATE`: `CLOSE_DT`가 `OPEN_DT`보다 크거나 같음을 보장합니다.
        *   `CK_BRANCH_HISTORY_OPEN_FMT`, `CK_BRANCH_HISTORY_CLOSE_FMT`: `OPEN_DT`와 `CLOSE_DT`가 'YYYYMMDD' 형식의 8자리 숫자로 구성되었는지 정규 표현식으로 검증합니다.
    *   각 테이블과 컬럼에 대한 상세한 주석(COMMENT)이 추가되어 이해를 돕습니다.

4.  **인덱스 생성 (CREATE INDEX)**:
    *   성능 최적화를 위해 여러 인덱스를 생성합니다.
        *   `IDX_BRANCH_HISTORY_ACCT_BRANCH`: `(ACCT_BRANCH_CD, BRANCH_CD)`는 회계 지점 체인 추적 시 조인 성능을 향상시킵니다.
        *   `IDX_BRANCH_HISTORY_DTSEQ`: `(OPEN_DT, CLOSE_DT, BRANCH_CD, REG_SEQ DESC, ACCT_BRANCH_CD)`는 기준일 범위 조회 및 최신 이력 정렬에 유리합니다.
        *   `IDX_BRANCH_HISTORY_BR_REGSEQ`: `(BRANCH_CD, REG_SEQ DESC)`는 지점별 최신 이력을 빠르게 조회하는 데 사용됩니다.

5.  **샘플 데이터 (INSERT INTO)**:
    *   테스트 및 시뮬레이션을 위한 샘플 데이터를 `BRANCH_HISTORY` 테이블에 삽입합니다. 2006년부터 2016년까지 지점의 개설, 폐쇄, 그리고 다른 지점으로의 통폐합(회계 지점 변경) 이력이 포함되어 있어, 다양한 시나리오에서의 체인 추적을 테스트할 수 있도록 구성되었습니다.
    *   `COMMIT` 문을 통해 데이터 삽입을 확정합니다.

6.  **재귀 CTE 예시 (기준일 유효 지점만 체인 추적)**:
    *   **바인드 변수 설정**: `:TARGET_DATE` 변수를 'YYYYMMDD' 형식의 문자열로 선언하고 값을 할당합니다. 이 변수는 체인 추적의 기준이 되는 날짜입니다.
    *   `BASE_MAPPING` CTE: `BRANCH_HISTORY` 테이블에서 `BRANCH_CD`별로 `TARGET_DATE`에 유효한(즉, `OPEN_DT`와 `CLOSE_DT` 사이에 `TARGET_DATE`가 포함되는) 최신 이력 1건을 추출합니다. `CROSS APPLY`와 `FETCH FIRST 1 ROW ONLY`를 사용하여 오라클 12c+의 기능을 활용합니다. 이 CTE는 각 지점의 기준일 시점의 `ACCT_BRANCH_CD`를 확정합니다.
    *   `BRANCH_PATH` CTE (재귀 CTE):
        *   앵커 멤버 (Anchor Member): `BASE_MAPPING`에서 시작하여 각 지점(`START_CD`)의 첫 번째 단계(자신)를 `CUR_CD`, `NEXT_CD`로 설정하고 `PATH_STR`에 경로를 기록합니다. `LVL`은 1로 시작합니다.
        *   재귀 멤버 (Recursive Member): 이전 단계(`p`)의 `NEXT_CD`가 현재 단계(`m`)의 `BRANCH_CD`와 일치하는 경우, 즉 체인이 연결되는 경우 다음 단계를 추적합니다. `PATH_STR`에 현재 지점을 추가하고 `LVL`을 증가시킵니다. `p.CUR_CD <> p.NEXT_CD` 조건은 현재 지점과 다음 지점이 다를 때만 재귀를 계속하여 불필요한 자기 참조를 방지합니다.
    *   `CYCLE` 절: 오라클 12c+에서 제공하는 기능으로, 재귀 CTE 내에서 순환(무한 루프)이 발생했을 때 이를 감지하고 처리합니다. `IS_LOOP` 플래그를 'Y'로 설정하여 순환 경로를 식별할 수 있습니다.
    *   최종 결과 포맷팅: `BRANCH_PATH`에서 각 `START_CD`별로 가장 긴 경로(가장 마지막 `LVL`의 레코드)를 선택하여 출력합니다. `ROW_NUMBER()`를 사용하여 `LVL`이 가장 큰 레코드를 찾습니다. `CASE` 문을 사용하여 경로를 보기 좋게 포맷팅합니다 (예: 'A → A' 또는 'A → B → C').

7.  **오라클 11g 호환 SQL 예시**:
    *   오라클 11g 환경을 위해 `CYCLE` 절이 없는 `CONNECT BY` 계층형 쿼리를 사용한 예시를 제공합니다.
    *   `EFFECTIVE_HIST` CTE: `ROW_NUMBER()`를 사용하여 `TARGET_DATE`에 유효한 최신 이력을 선정하는 부분은 오라클 12c+ 버전과 동일합니다.
    *   `BASE_BRANCH` CTE: `EFFECTIVE_HIST`에서 선정된 1건의 확정 매핑 정보를 추출합니다.
    *   `PATH_DATA` CTE (계층형 쿼리): `CONNECT BY` 절을 사용하여 `BRANCH_CD`에서 `ACCT_BRANCH_CD`로 연결되는 체인을 추적합니다. `SYS_CONNECT_BY_PATH` 함수로 전체 경로 문자열을 생성합니다. `NOCYCLE` 키워드를 사용하여 순환을 방지합니다. `PRIOR ACCT_BRANCH_CD = BRANCH_CD`는 이전 단계의 회계 지점이 현재 단계의 지점 코드가 되는 경우를 연결합니다. `PRIOR BRANCH_CD <> PRIOR ACCT_BRANCH_CD`는 자기 자신으로 향하는 루프를 방지합니다.
    *   최종 결과 출력: `IS_LEAF = 1` 조건을 통해 체인의 마지막 노드만 선택하여 최종 경로를 출력합니다. `CASE` 문으로 자기 자신을 가리키는 경우를 'A → A' 형태로 포맷팅합니다.

8.  **최종 회계 지점만 조회 SQL 예시**:
    *   지점명 없이 `TARGET_DATE` 기준 최종 회계 지점(체인의 마지막 노드)만 반환하는 경량화된 SQL 예시입니다.
    *   오라클 12c+ 버전: `BRANCH_CHAIN` 재귀 CTE를 사용하여 체인을 구성하고, `MAX(CUR_BRANCH_CD) KEEP (DENSE_RANK LAST ORDER BY LVL)`를 통해 가장 깊은 레벨의 지점(최종 회계 지점)을 추출합니다. `GROUP BY START_BRANCH_CD`로 시작 지점별 최종 회계 지점을 집계합니다.
    *   오라클 11g 버전: `CONNECT BY` 계층형 쿼리의 `CONNECT_BY_ROOT`와 `IS_LEAF`를 활용하여 시작 지점과 체인의 마지막에 도달한 지점(`BRANCH_CD AS FINAL_ACCT_BRANCH_CD`)을 추출합니다.

**스크립트의 핵심 아이디어**:
*   `BRANCH_HISTORY` 테이블을 통해 지점의 개폐 이력뿐만 아니라 회계 지점의 변경 이력(통폐합 등)까지 관리합니다.
*   `TARGET_DATE`라는 기준일을 사용하여 특정 시점에 유효한 지점 및 회계 지점 관계를 동적으로 파악합니다.
*   재귀 CTE(Oracle 12c+) 또는 계층형 쿼리(Oracle 11g)를 사용하여, 한 지점의 회계 지점이 다시 다른 지점의 회계 지점이 되는 복잡한 체인 구조를 효율적으로 추적합니다.
*   `CYCLE` 절 또는 `NOCYCLE` 및 추가 조건을 사용하여 무한 루프(순환 참조)를 방지하는 로직이 포함되어 있습니다.

이 스크립트는 금융권 등에서 조직 개편이나 지점 통폐합 이력 관리가 필요한 경우, 특정 시점의 조직 구조를 파악하는 데 유용하게 활용될 수 있습니다.
*/

-- 1. 테이블 재생성: 기존 테이블이 있다면 제거 후 다시 생성합니다.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE BRANCH_HISTORY PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

-- 2. BRANCH_HISTORY 테이블 생성 및 컬럼 주석 추가
CREATE TABLE BRANCH_HISTORY (
    BRANCH_CD       VARCHAR2(4)   NOT NULL,
    REG_SEQ         NUMBER        NOT NULL,
    BRANCH_NM       VARCHAR2(100) NOT NULL,
    ACCT_BRANCH_CD  VARCHAR2(4)   NOT NULL,
    OPEN_DT         VARCHAR2(8)   NOT NULL,
    CLOSE_DT        VARCHAR2(8)   DEFAULT '99991231' NOT NULL,
    UPD_USER_ID     VARCHAR2(20)  NOT NULL,
    UPD_DT          TIMESTAMP     NOT NULL,
    REMARK          VARCHAR2(200),
    CONSTRAINT PK_BRANCH_HISTORY PRIMARY KEY (BRANCH_CD, REG_SEQ),
    CONSTRAINT CK_BRANCH_HISTORY_DATE CHECK (CLOSE_DT >= OPEN_DT),
    CONSTRAINT CK_BRANCH_HISTORY_OPEN_FMT CHECK (REGEXP_LIKE(OPEN_DT, '^[0-9]{8}$')),
    CONSTRAINT CK_BRANCH_HISTORY_CLOSE_FMT CHECK (REGEXP_LIKE(CLOSE_DT, '^[0-9]{8}$'))
);

COMMENT ON TABLE  BRANCH_HISTORY IS '지점 이력 정보';
COMMENT ON COLUMN BRANCH_HISTORY.BRANCH_CD       IS '지점 코드';
COMMENT ON COLUMN BRANCH_HISTORY.REG_SEQ         IS '등록 일련번호';
COMMENT ON COLUMN BRANCH_HISTORY.BRANCH_NM       IS '지점명';
COMMENT ON COLUMN BRANCH_HISTORY.ACCT_BRANCH_CD  IS '회계 지점 코드';
COMMENT ON COLUMN BRANCH_HISTORY.OPEN_DT         IS '개설 일자(YYYYMMDD)';
COMMENT ON COLUMN BRANCH_HISTORY.CLOSE_DT        IS '폐쇄 일자(미폐쇄는 99991231, YYYYMMDD)';
COMMENT ON COLUMN BRANCH_HISTORY.UPD_USER_ID     IS '수정 사용자 ID';
COMMENT ON COLUMN BRANCH_HISTORY.UPD_DT          IS '수정 일시';
COMMENT ON COLUMN BRANCH_HISTORY.REMARK          IS '비고';

-- 지점-회계 지점 체인 추적을 위한 인덱스
CREATE INDEX IDX_BRANCH_HISTORY_ACCT_BRANCH
    ON BRANCH_HISTORY (ACCT_BRANCH_CD, BRANCH_CD);

-- 기준일자 범위 조회 및 최신 이력 정렬 성능 향상을 위한 인덱스
CREATE INDEX IDX_BRANCH_HISTORY_DTSEQ
    ON BRANCH_HISTORY (OPEN_DT, CLOSE_DT, BRANCH_CD, REG_SEQ DESC, ACCT_BRANCH_CD);

-- 지점별 최신 이력 조회 성능 향상을 위한 인덱스
CREATE INDEX IDX_BRANCH_HISTORY_BR_REGSEQ
    ON BRANCH_HISTORY (BRANCH_CD, REG_SEQ DESC);

-- 3. 재귀 CTE 및 샘플 데이터: 기준일 유효 지점 체인 추적 예시
-- 바인드 변수(:TARGET_DATE) 예시: YYYYMMDD 형식의 문자열
-- (예: VAR TARGET_DATE VARCHAR2(8); EXEC :TARGET_DATE := '20150421';)

-- 3.1. 샘플 데이터 (필요 시 사용): 기준일 시뮬레이션을 위한 테스트 데이터

-- 2006년 개설
INSERT INTO BRANCH_HISTORY VALUES ('0004', 1, '종로4가', '0004', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0005', 1, '종로5가', '0005', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0006', 1, '종로6가', '0006', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0007', 1, '종로7가', '0007', '20060101', '20110720', 'SYS', SYSTIMESTAMP, '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0008', 1, '종로8가', '0008', '20060101', '20160421', 'SYS', SYSTIMESTAMP, '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0009', 1, '종로9가', '0009', '20060101', '20150421', 'SYS', SYSTIMESTAMP, '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0010', 1, '종로10가', '0010', '20060101', '20120520', 'SYS', SYSTIMESTAMP, '통폐합 이전');

-- 2011년 – 0007 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0007', 2, '종로7가', '0006', '20110721', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');

-- 2012년 – 0006 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0006', 2, '종로6가', '0009', '20120521', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');

-- 2015년 – 0009 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0009', 2, '종로9가', '0008', '20150422', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');

-- 2016년 – 0008 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0008', 2, '종로8가', '0010', '20160422', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');


COMMIT;


-- 3.2. 기준일별 유효 체인 도식 (샘플 데이터 기준)
-- 기준일별 지점-회계 지점 체인 흐름을 이해하기 쉽게 도식화한 예시입니다.
-- 2011-07-21 기준
-- 0004 → 0004
-- 0005 → 0005
-- 0006 → 0006
-- 0007 → 0006
-- 0008 → 0008
-- 0009 → 0009
-- 0010 → 0010


-- 2012-05-21 기준
-- 0004 → 0004
-- 0005 → 0005
-- 0006 → 0009
-- 0007 → 0006 → 0009
-- 0008 → 0008
-- 0009 → 0009
-- 0010 → 0010


-- 2015-04-22 기준
-- 0004 → 0004
-- 0005 → 0005
-- 0006 → 0009 → 0008
-- 0007 → 0006 → 0009 → 0008
-- 0008 → 0008
-- 0009 → 0008
-- 0010 → 0010


-- 2015-04-22 기준(최종 회계 지점만 표기)
-- 0004 → 0004
-- 0005 → 0005
-- 0006 → 0008
-- 0007 → 0008
-- 0008 → 0008
-- 0009 → 0008
-- 0010 → 0010

-- 3.3. 기준일별 체인 전체 경로 조회 (Oracle 12c 이상)
VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH BASE_MAPPING AS (
    -- 1. 기준일 시점의 유효한 지점 이력을 각 지점별로 1건씩 확정합니다.
    SELECT b.BRANCH_CD, h.ACCT_BRANCH_CD
      FROM (SELECT DISTINCT BRANCH_CD FROM BRANCH_HISTORY) b
     CROSS APPLY (
        SELECT ACCT_BRANCH_CD
          FROM BRANCH_HISTORY
         WHERE BRANCH_CD = b.BRANCH_CD
           AND :TARGET_DATE BETWEEN OPEN_DT AND CLOSE_DT
         ORDER BY REG_SEQ DESC
         FETCH FIRST 1 ROW ONLY
     ) h
),
BRANCH_PATH (START_CD, CUR_CD, NEXT_CD, PATH_STR, LVL) AS (
    -- 2. 재귀 CTE: 지점-회계 지점 경로를 추적합니다.
    --    마지막 노드가 자기 자신을 가리키면 추적을 멈춥니다.
    SELECT 
        BRANCH_CD  AS START_CD, 
        BRANCH_CD  AS CUR_CD, 
        ACCT_BRANCH_CD AS NEXT_CD, 
        CAST(BRANCH_CD AS VARCHAR2(4000)) AS PATH_STR, 
        1 AS LVL
    FROM BASE_MAPPING
    UNION ALL
    SELECT 
        p.START_CD, 
        m.BRANCH_CD AS CUR_CD, 
        m.ACCT_BRANCH_CD AS NEXT_CD, 
        p.PATH_STR || ' → ' || m.BRANCH_CD, 
        p.LVL + 1
    FROM BRANCH_PATH p
    JOIN BASE_MAPPING m ON p.NEXT_CD = m.BRANCH_CD
    WHERE p.CUR_CD <> p.NEXT_CD -- 현재 지점과 다음 지점이 다를 때만 재귀를 계속합니다.
)
-- 순환(Cycle) 감지: 무한 루프 방지 및 순환 발생 시 'Y'로 표시
CYCLE CUR_CD SET IS_LOOP TO 'Y' DEFAULT 'N'
SELECT '-- ' || TO_CHAR(TO_DATE(:TARGET_DATE, 'YYYYMMDD'), 'YYYY-MM-DD') || ' 기준' AS OUTPUT FROM DUAL
UNION ALL
SELECT '-- ' || 
       CASE 
           -- 시작 지점과 최종 지점이 같은 경우 (LVL 1) -> 'A → A' 형식으로 표시
           WHEN LVL = 1 AND START_CD = NEXT_CD THEN PATH_STR || ' → ' || NEXT_CD
           -- 체인이 형성된 경우 -> 빌드된 PATH_STR 그대로 출력
           ELSE PATH_STR 
       END
FROM (
    -- 각 시작 지점별로 가장 긴 경로(가장 마지막 단계)만 선택합니다.
    SELECT START_CD, NEXT_CD, PATH_STR, LVL,
           ROW_NUMBER() OVER(PARTITION BY START_CD ORDER BY LVL DESC) as RN
    FROM BRANCH_PATH
    WHERE IS_LOOP = 'N' -- 순환 경로가 아닌 경우만 선택
)
WHERE RN = 1
ORDER BY 1;

-- 3.4. 기준일별 체인 전체 경로 조회 (Oracle 11g 호환)
-- 기준일 시점의 유효 지점만을 대상으로 체인을 추적합니다.
VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH EFFECTIVE_HIST AS (
    -- 1. 기준일 시점의 유효한 이력을 지점별로 1건씩 선정합니다.
    SELECT /*+ MATERIALIZE */
           BRANCH_CD,
           BRANCH_NM,
           ACCT_BRANCH_CD,
           ROW_NUMBER() OVER (
               PARTITION BY BRANCH_CD 
               ORDER BY 
                   CASE WHEN :TARGET_DATE BETWEEN OPEN_DT AND CLOSE_DT THEN 0 ELSE 1 END,
                   REG_SEQ DESC
           ) AS RN
      FROM BRANCH_HISTORY
),
BASE_BRANCH AS (
    -- 2. 각 지점별로 확정된 1건의 매핑 정보를 추출합니다.
    SELECT BRANCH_CD, ACCT_BRANCH_CD
      FROM EFFECTIVE_HIST
     WHERE RN = 1
),
PATH_DATA AS (
    -- 3. CONNECT BY 계층형 쿼리로 지점-회계 지점 경로를 생성합니다.
    SELECT 
        CONNECT_BY_ROOT(BRANCH_CD) AS START_NODE,
        -- 경로 문자열 생성 (예: 0006 → 0009 → 0008)
        LTRIM(SYS_CONNECT_BY_PATH(BRANCH_CD, ' → '), ' → ') AS FULL_PATH,
        ACCT_BRANCH_CD AS FINAL_ACCT,
        CONNECT_BY_ISLEAF AS IS_LEAF
    FROM 
        BASE_BRANCH
    CONNECT BY NOCYCLE -- 무한 루프 방지
        PRIOR ACCT_BRANCH_CD = BRANCH_CD -- 이전 단계의 회계 지점이 현재 지점 코드와 연결
        AND PRIOR BRANCH_CD <> PRIOR ACCT_BRANCH_CD -- 자기 자신으로의 순환 방지
)
-- 4. 최종 결과 포맷팅 및 출력
SELECT '-- ' || TO_CHAR(TO_DATE(:TARGET_DATE, 'YYYYMMDD'), 'YYYY-MM-DD') || ' 기준' AS OUTPUT
FROM DUAL
UNION ALL
SELECT '-- ' || 
       CASE 
           -- 경로에 화살표가 없고(자기 자신) 시작과 끝이 같으면 'A → A' 형태로 변환
           WHEN INSTR(FULL_PATH, ' → ') = 0 THEN FULL_PATH || ' → ' || FINAL_ACCT 
           ELSE FULL_PATH 
       END
FROM PATH_DATA
WHERE IS_LEAF = 1 -- 체인의 마지막(최하위 노드)만 선택
ORDER BY OUTPUT;   -- 날짜 헤더가 상단에 오도록 정렬 (운영 시 정렬 기준 조정 가능)



-- 3.5. 기준일별 최종 회계 지점 조회 (Oracle 12c 이상)
-- 지점명 없이 최종 회계 지점 코드만 반환하는 경량화된 조회입니다.

VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH
EFFECTIVE_HIST AS (
    -- 1. 기준일 시점의 유효한 이력을 지점별로 1건씩 선정합니다.
    SELECT /*+ MATERIALIZE INDEX_RS_ASC(bht IDX_BRANCH_HISTORY_DTSEQ) */
           BRANCH_CD,
           BRANCH_NM,
           ACCT_BRANCH_CD,
           OPEN_DT,
           CLOSE_DT,
           -- 기준일 포함 이력을 우선하고, 동일 지점은 최신(REG_SEQ DESC)을 선택
           ROW_NUMBER() OVER (
               PARTITION BY BRANCH_CD
               ORDER BY
                   CASE
                       WHEN :TARGET_DATE BETWEEN OPEN_DT AND CLOSE_DT THEN 0
                       ELSE 1
                   END,
                   REG_SEQ DESC
           ) AS RN
      FROM BRANCH_HISTORY bht
),
BASE_BRANCH AS (
    -- 2. 지점별 유효 이력 중 확정된 1건의 매핑 정보를 추출합니다.
    SELECT /*+ MATERIALIZE */
           BRANCH_CD,
           BRANCH_NM,
           ACCT_BRANCH_CD
      FROM EFFECTIVE_HIST ehs
     WHERE ehs.RN = 1
),
BRANCH_CHAIN (
    START_BRANCH_CD,
    START_BRANCH_NM,
    CUR_BRANCH_CD,
    CUR_ACCT_CD,
    LVL
) AS (
    -- 3. 재귀 CTE: 시작 지점부터 회계 지점 체인을 연결합니다.
    --    앵커 멤버: 시작 지점(자기 자신)부터 체인 시작
    SELECT
        BRANCH_CD,
        BRANCH_NM,
        BRANCH_CD,
        ACCT_BRANCH_CD,
        1
      FROM BASE_BRANCH bbr
    UNION ALL
    -- 재귀 멤버: 회계 지점 코드를 따라 체인을 계속 연결
    SELECT /*+ USE_HASH(bbr) CARDINALITY(bch 100000) */
        bch.START_BRANCH_CD,
        bch.START_BRANCH_NM,
        bbr.BRANCH_CD,
        bbr.ACCT_BRANCH_CD,
        bch.LVL + 1
      FROM BRANCH_CHAIN bch
      JOIN BASE_BRANCH bbr
        ON bch.CUR_ACCT_CD = bbr.BRANCH_CD
     -- 현재 지점과 회계 지점이 같으면(자기 자신으로 향하면) 추가 확장을 방지
     WHERE bch.CUR_BRANCH_CD <> bch.CUR_ACCT_CD
)
-- 순환(Cycle) 감지: 순환 참조가 있을 경우 'Y'로 표시
CYCLE CUR_BRANCH_CD SET IS_CYCLE TO 'Y' DEFAULT 'N'
SELECT
    :TARGET_DATE AS TARGET_DATE,
    START_BRANCH_CD AS BRANCH_CD,
    -- 체인 깊이(LVL)가 가장 큰 지점이 최종 회계 지점입니다.
    MAX(CUR_BRANCH_CD) KEEP (DENSE_RANK LAST ORDER BY LVL) AS FINAL_ACCT_BRANCH_CD
FROM
    BRANCH_CHAIN bch
-- 순환 경로가 아닌 경우만 선택
WHERE
    IS_CYCLE = 'N'
GROUP BY
    START_BRANCH_CD
ORDER BY
    BRANCH_CD;


-- 3.6. 기준일별 최종 회계 지점 조회 (Oracle 11g 호환)
-- 지점명 없이 최종 회계 지점 코드만 반환하는 경량화된 조회입니다.

VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH EFFECTIVE_HIST AS (
    -- 1. 기준일 시점의 유효한 이력을 지점별로 1건씩 추출합니다.
    SELECT /*+ MATERIALIZE */
           BRANCH_CD,
           BRANCH_NM,
           ACCT_BRANCH_CD,
           ROW_NUMBER() OVER (
               PARTITION BY BRANCH_CD 
               ORDER BY 
                   CASE WHEN :TARGET_DATE BETWEEN OPEN_DT AND CLOSE_DT THEN 0 ELSE 1 END,
                   REG_SEQ DESC
           ) AS RN
      FROM BRANCH_HISTORY
),
BASE_BRANCH AS (
    -- 2. 각 지점별로 확정된 1건의 매핑 정보를 가공합니다.
    SELECT BRANCH_CD, BRANCH_NM, ACCT_BRANCH_CD
      FROM EFFECTIVE_HIST
     WHERE RN = 1
)
-- 3. CONNECT BY를 이용한 계층 추적 및 최종 회계 지점 추출
SELECT 
    :TARGET_DATE AS TARGET_DATE,
    CONNECT_BY_ROOT(BRANCH_CD) AS BRANCH_CD,    -- 시작 지점 코드
    CONNECT_BY_ROOT(BRANCH_NM) AS BRANCH_NM,    -- 시작 지점 명칭
    BRANCH_CD AS FINAL_ACCT_BRANCH_CD           -- 최종 도달한 회계 지점
FROM 
    BASE_BRANCH
WHERE 
    CONNECT_BY_ISLEAF = 1  -- 체인의 마지막(최하위 노드)만 선택
CONNECT BY NOCYCLE 
    PRIOR ACCT_BRANCH_CD = BRANCH_CD  -- 이전 단계의 회계 지점이 현재의 지점 코드인 경우 연결
    AND PRIOR BRANCH_CD <> PRIOR ACCT_BRANCH_CD -- 자기 자신으로의 루프 방지
ORDER BY 
    BRANCH_CD;