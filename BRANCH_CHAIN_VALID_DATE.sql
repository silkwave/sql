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
/*
-- 2006년 개설
INSERT INTO BRANCH_HISTORY VALUES ('0004', 1, '종로4가', '0004', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0005', 1, '종로5가', '0005', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0006', 1, '종로6가', '0006', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0007', 1, '종로7가', '0007', '20060101', '20110720', 'SYS', SYSTIMESTAMP, '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0008', 1, '종로8가', '0008', '20060101', '99991231', 'SYS', SYSTIMESTAMP, NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0009', 1, '종로9가', '0009', '20060101', '20150421', 'SYS', SYSTIMESTAMP, '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0010', 1, '종로10가', '0010', '20060101', '20120520', 'SYS', SYSTIMESTAMP, '통폐합 이전');

-- 2011년 – 0007 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0007', 2, '종로7가', '0006', '20110721', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');

-- 2012년 – 0006 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0006', 2, '종로6가', '0009', '20120521', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');

-- 2015년 – 0009 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0009', 2, '종로9가', '0008', '20150422', '99991231', 'SYS', SYSTIMESTAMP, '통폐합');

COMMIT;
*/

-- =============================================================================
-- 3-0-1. 기준일별 유효 체인 도식(샘플 데이터 기준)
-- =============================================================================
-- 2011-07-21 기준
-- 0007 → 0006
-- 0006 → 0006
-- 0009 → 0009
-- 0010 → 0010
-- 0008 → 0008
-- 0004 → 0004
-- 0005 → 0005
--
-- 2012-05-21 기준
-- 0007 → 0006 → 0009
-- 0006 → 0009
-- 0009 → 0009
-- 0010 → 0010
-- 0008 → 0008
-- 0004 → 0004
-- 0005 → 0005
--
-- 2015-04-22 기준
-- 0007 → 0006 → 0009 → 0008
-- 0006 → 0009 → 0008
-- 0009 → 0008
-- 0010 → 0010
-- 0008 → 0008
-- 0004 → 0004
-- 0005 → 0005
--
-- 2015-04-22 기준(최종 회계 지점만 표기)
-- 0007 → 0008
-- 0006 → 0008
-- 0009 → 0008
-- 0010 → 0010
-- 0008 → 0008
-- 0004 → 0004
-- 0005 → 0005

-- =============================================================================
-- 3-0-2. 2015-04-22 기준 조회 SQL 예시
-- =============================================================================
/*
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
    SELECT
        BRANCH_CD,
        BRANCH_NM,
        BRANCH_CD,
        ACCT_BRANCH_CD,
        1
      FROM BASE_BRANCH bbr
    UNION ALL
    SELECT /*+ USE_HASH(bbr) CARDINALITY(bch 100000) */
        bch.START_BRANCH_CD,
        bch.START_BRANCH_NM,
        bbr.BRANCH_CD,
        bbr.ACCT_BRANCH_CD,
        bch.LVL + 1
      FROM BRANCH_CHAIN bch
      JOIN BASE_BRANCH bbr
        ON bch.CUR_ACCT_CD = bbr.BRANCH_CD
     WHERE bch.CUR_BRANCH_CD <> bch.CUR_ACCT_CD
)
CYCLE CUR_BRANCH_CD SET IS_CYCLE TO 'Y' DEFAULT 'N'
SELECT
    :TARGET_DATE AS TARGET_DATE,
    START_BRANCH_CD AS BRANCH_CD,
    START_BRANCH_NM AS BRANCH_NM,
    MAX(CUR_BRANCH_CD) KEEP (DENSE_RANK LAST ORDER BY LVL) AS FINAL_ACCT_BRANCH_CD
FROM
    BRANCH_CHAIN bch
WHERE
    IS_CYCLE = 'N'
GROUP BY
    START_BRANCH_CD,
    START_BRANCH_NM
ORDER BY
    BRANCH_CD;
*/

-- =============================================================================
-- 3-0-3. 2015-04-22 기준 최종 회계 지점만 조회 SQL 예시
-- =============================================================================
/*
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
    SELECT
        BRANCH_CD,
        BRANCH_NM,
        BRANCH_CD,
        ACCT_BRANCH_CD,
        1
      FROM BASE_BRANCH bbr
    UNION ALL
    SELECT /*+ USE_HASH(bbr) CARDINALITY(bch 100000) */
        bch.START_BRANCH_CD,
        bch.START_BRANCH_NM,
        bbr.BRANCH_CD,
        bbr.ACCT_BRANCH_CD,
        bch.LVL + 1
      FROM BRANCH_CHAIN bch
      JOIN BASE_BRANCH bbr
        ON bch.CUR_ACCT_CD = bbr.BRANCH_CD
     WHERE bch.CUR_BRANCH_CD <> bch.CUR_ACCT_CD
)
CYCLE CUR_BRANCH_CD SET IS_CYCLE TO 'Y' DEFAULT 'N'
SELECT
    :TARGET_DATE AS TARGET_DATE,
    START_BRANCH_CD AS BRANCH_CD,
    MAX(CUR_BRANCH_CD) KEEP (DENSE_RANK LAST ORDER BY LVL) AS FINAL_ACCT_BRANCH_CD
FROM
    BRANCH_CHAIN bch
WHERE
    IS_CYCLE = 'N'
GROUP BY
    START_BRANCH_CD
ORDER BY
    BRANCH_CD;
*/
