/*
================================================================================
-- 스크립트 명: BRANCH_CHAIN_VALID_DATE.sql
-- 목적:
--   BRANCH_HISTORY 테이블 생성 후, 기준일(:TARGET_DATE)에 유효한 지점만 대상으로
--   지점-회계점 체인을 재귀 CTE로 추적하는 예시 SQL 제공.
--
-- 사용 전제:
--   - 오라클 SQL*Plus 또는 호환 클라이언트
--   - 오라클 12c 이상(재귀 CTE 및 CYCLE 절 사용)
--   - 날짜는 YYYYMMDD 형식의 문자열 사용
================================================================================
*/

-- =============================================================================
-- 1. 테이블 재생성
-- =============================================================================
-- 기존 테스트용 테이블을 제거한 뒤 재생성합니다.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE BRANCH_HISTORY PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

-- =============================================================================
-- 2. 테이블 생성 및 주석
-- =============================================================================
-- 지점 이력 정보를 저장하는 기준 테이블입니다.
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

-- 회계 지점 체인 추적 성능 최적화
CREATE INDEX IDX_BRANCH_HISTORY_ACCT_BRANCH
    ON BRANCH_HISTORY (ACCT_BRANCH_CD, BRANCH_CD);

-- 기준일 범위 조회 및 최신 이력 정렬 성능 향상
CREATE INDEX IDX_BRANCH_HISTORY_DTSEQ
    ON BRANCH_HISTORY (OPEN_DT, CLOSE_DT, BRANCH_CD, REG_SEQ DESC, ACCT_BRANCH_CD);

-- 지점별 최신 이력 조회 성능 향상
CREATE INDEX IDX_BRANCH_HISTORY_BR_REGSEQ
    ON BRANCH_HISTORY (BRANCH_CD, REG_SEQ DESC);

-- =============================================================================
-- 3. 재귀 CTE: 기준일 유효 지점만 체인 추적
-- =============================================================================
-- 바인드 변수 예시(:TARGET_DATE) YYYYMMDD 문자열
-- 예: VAR TARGET_DATE VARCHAR2(8); EXEC :TARGET_DATE := '20150421';

-- =============================================================================
-- 3-0. 샘플 데이터(필요 시 사용)
-- =============================================================================
-- 기준일 시뮬레이션을 위한 테스트 데이터입니다.

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


-- =============================================================================
-- 3-0-1. 기준일별 유효 체인 도식(샘플 데이터 기준)
-- =============================================================================
-- 기준일별 체인 흐름을 사람이 읽기 쉽게 정리한 예시입니다.
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

-- =============================================================================
-- 3-0-2. 2015-04-22 기준 조회 SQL 예시          (오라클 12 이상)
-- =============================================================================


VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH BASE_MAPPING AS (
    -- 1. 기준일 시점의 유효 이력을 지점별로 1건씩 확정
    SELECT b.BRANCH_CD, h.ACCT_BRANCH_CD
      FROM (SELECT DISTINCT BRANCH_CD FROM BRANCH_HISTORY) b
     CROSS APPLY (
        SELECT ACCT_BRANCH_CD
          FROM BRANCH_HISTORY
         WHERE BRANCH_CD = b.BRANCH_CD
         ORDER BY 
               CASE WHEN :TARGET_DATE BETWEEN OPEN_DT AND CLOSE_DT THEN 0 ELSE 1 END,
               REG_SEQ DESC
         FETCH FIRST 1 ROW ONLY
     ) h
),
BRANCH_PATH (START_CD, CUR_CD, NEXT_CD, PATH_STR, LVL) AS (
    -- 2. Recursive CTE: 경로를 빌드하되, 마지막 노드가 자기 자신이면 멈춤
    SELECT 
        BRANCH_CD  AS START_CD, 
        BRANCH_CD  AS CUR_CD, 
        ACCT_BRANCH_CD, 
        CAST(BRANCH_CD AS VARCHAR2(4000)), 
        1
    FROM BASE_MAPPING
    UNION ALL
    SELECT 
        p.START_CD, 
        m.BRANCH_CD, 
        m.ACCT_BRANCH_CD, 
        p.PATH_STR || ' → ' || m.BRANCH_CD, 
        p.LVL + 1
    FROM BRANCH_PATH p
    JOIN BASE_MAPPING m ON p.NEXT_CD = m.BRANCH_CD
    WHERE p.CUR_CD <> p.NEXT_CD -- 현재 지점과 다음 지점이 다를 때만 계속 진행
)
-- 무한 루프 방지
CYCLE CUR_CD SET IS_LOOP TO 'Y' DEFAULT 'N'
-- 3. 최종 출력 포맷팅
SELECT '-- ' || TO_CHAR(TO_DATE(:TARGET_DATE, 'YYYYMMDD'), 'YYYY-MM-DD') || ' 기준' AS OUTPUT FROM DUAL
UNION ALL
SELECT '-- ' || 
       CASE 
           -- 규칙 1: 자기 자신인 경우 (LVL 1이고 시작과 끝이 같음) -> 'A → A'
           WHEN LVL = 1 AND START_CD = NEXT_CD THEN PATH_STR || ' → ' || NEXT_CD
           -- 규칙 2: 체인이 형성된 경우 -> 빌드된 PATH_STR 그대로 출력
           ELSE PATH_STR 
       END
FROM (
    -- 각 시작점별로 가장 긴 경로(마지막 단계)만 선택
    SELECT START_CD, NEXT_CD, PATH_STR, LVL,
           ROW_NUMBER() OVER(PARTITION BY START_CD ORDER BY LVL DESC) as RN
    FROM BRANCH_PATH
    WHERE IS_LOOP = 'N'
)
WHERE RN = 1
ORDER BY 1;

-- =============================================================================
-- 3-0-2. 2015-04-22 기준 조회 SQL 예시           (오라클 11)
-- =============================================================================
-- 기준일 시점의 유효 지점만 대상으로 체인을 추적합니다.
VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH EFFECTIVE_HIST AS (
    -- 1. 기준일 시점의 유효 이력 선정 (11g 호환)
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
    -- 2. 각 지점별 1건의 확정 매핑 
    SELECT BRANCH_CD, ACCT_BRANCH_CD
      FROM EFFECTIVE_HIST
     WHERE RN = 1
),
PATH_DATA AS (
    -- 3. 계층형 쿼리로 경로 생성
    SELECT 
        CONNECT_BY_ROOT(BRANCH_CD) AS START_NODE,
        -- 경로 생성 (예: 0006 → 0009 → 0008)
        LTRIM(SYS_CONNECT_BY_PATH(BRANCH_CD, ' → '), ' → ') AS FULL_PATH,
        ACCT_BRANCH_CD AS FINAL_ACCT,
        CONNECT_BY_ISLEAF AS IS_LEAF
    FROM 
        BASE_BRANCH
    CONNECT BY NOCYCLE 
        PRIOR ACCT_BRANCH_CD = BRANCH_CD 
        AND PRIOR BRANCH_CD <> PRIOR ACCT_BRANCH_CD -- 무한루프 방지
)
-- 4. 최종 포맷팅 출력
SELECT '-- ' || TO_CHAR(TO_DATE(:TARGET_DATE, 'YYYYMMDD'), 'YYYY-MM-DD') || ' 기준' AS OUTPUT
FROM DUAL
UNION ALL
SELECT '-- ' || 
       CASE 
           -- 경로에 화살표가 없고(자기 자신), 시작과 끝이 같으면 'A → A' 형태로 강제 변환
           WHEN INSTR(FULL_PATH, ' → ') = 0 THEN FULL_PATH || ' → ' || FINAL_ACCT 
           ELSE FULL_PATH 
       END
FROM PATH_DATA
WHERE IS_LEAF = 1
ORDER BY OUTPUT;   -- 날짜 헤더가 상단에 오도록 정렬 (실제 운영시 정렬 기준 조정 가능)



-- =============================================================================
-- 3-0-3. 2015-04-22 기준 최종 회계 지점만 조회 SQL 예시    (오라클 12 이상)
-- =============================================================================
-- 지점명 없이 최종 회계 지점만 반환하는 경량 조회입니다.

VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH
EFFECTIVE_HIST AS (
    SELECT /*+ MATERIALIZE INDEX_RS_ASC(bht IDX_BRANCH_HISTORY_DTSEQ) */
           BRANCH_CD,
           BRANCH_NM,
           ACCT_BRANCH_CD,
           OPEN_DT,
           CLOSE_DT,
           -- 기준일 포함 이력을 우선하고, 동일 지점은 최신(REG_SEQ DESC)만 선택
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
    SELECT /*+ MATERIALIZE */
           BRANCH_CD,
           BRANCH_NM,
           ACCT_BRANCH_CD
      -- 지점별 유효 이력 1건만 추출
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
    -- 시작 지점(자기 자신)부터 체인을 시작
    SELECT
        BRANCH_CD,
        BRANCH_NM,
        BRANCH_CD,
        ACCT_BRANCH_CD,
        1
      FROM BASE_BRANCH bbr
    UNION ALL
    -- 회계 지점 코드를 따라 체인을 계속 연결
    SELECT /*+ USE_HASH(bbr) CARDINALITY(bch 100000) */
        bch.START_BRANCH_CD,
        bch.START_BRANCH_NM,
        bbr.BRANCH_CD,
        bbr.ACCT_BRANCH_CD,
        bch.LVL + 1
      FROM BRANCH_CHAIN bch
      JOIN BASE_BRANCH bbr
        ON bch.CUR_ACCT_CD = bbr.BRANCH_CD
     -- 자기 자신으로 향하는 경우는 추가 확장을 방지
     WHERE bch.CUR_BRANCH_CD <> bch.CUR_ACCT_CD
)
-- 순환 참조가 있을 경우 표시
CYCLE CUR_BRANCH_CD SET IS_CYCLE TO 'Y' DEFAULT 'N'
SELECT
    :TARGET_DATE AS TARGET_DATE,
    START_BRANCH_CD AS BRANCH_CD,
    -- 체인 깊이(LVL)가 가장 큰 지점이 최종 회계 지점
    MAX(CUR_BRANCH_CD) KEEP (DENSE_RANK LAST ORDER BY LVL) AS FINAL_ACCT_BRANCH_CD
FROM
    BRANCH_CHAIN bch
-- 순환 제거
WHERE
    IS_CYCLE = 'N'
GROUP BY
    START_BRANCH_CD
ORDER BY
    BRANCH_CD;


-- =============================================================================
-- 3-0-3. 2015-04-22 기준 최종 회계 지점만 조회 SQL 예시  (오라클 11)
-- =============================================================================
-- 지점명 없이 최종 회계 지점만 반환하는 경량 조회입니다.

VAR TARGET_DATE VARCHAR2(8);
EXEC :TARGET_DATE := '20150422';

WITH EFFECTIVE_HIST AS (
    -- 1. 기준일 시점의 유효한 지점 이력 추출 (이 부분은 기존 로직 유지)
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
    -- 2. 각 지점별 1건의 확정된 매핑 정보를 가공
    SELECT BRANCH_CD, BRANCH_NM, ACCT_BRANCH_CD
      FROM EFFECTIVE_HIST
     WHERE RN = 1
)
-- 3. CONNECT BY를 이용한 계층 추적
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
    PRIOR ACCT_BRANCH_CD = BRANCH_CD  -- 이전 단계의 회계지점이 현재의 지점코드인 경우 연결
    AND PRIOR BRANCH_CD <> PRIOR ACCT_BRANCH_CD -- 자기 자신으로 향하는 루프 방지
ORDER BY 
    BRANCH_CD;