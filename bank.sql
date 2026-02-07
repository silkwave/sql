/*
================================================================================
-- 스크립트 명: bank.sql
-- 개요:
--   지점의 이력 정보를 관리하는 BRANCH_HISTORY 테이블을 생성하고,
--   특정 기준일에 각 지점의 최종 회계 지점을 추적하는 SQL을 포함하는 스크립트.
--
-- 주요 특징:
-- 1. DDL (테이블 및 인덱스):
--    - BRANCH_HISTORY: 지점의 개설, 폐쇄, 회계 지점 변경 등 모든 이력을 관리.
--    - IDX_BRANCH_HISTORY_ALL: 기준일 조회 및 데이터 커버링을 위한 핵심 복합 인덱스.
--    - IDX_BRANCH_HISTORY_ACCT_BRANCH: 회계 지점 체인 추적(재귀 조인) 성능 최적화 인덱스.
--
-- 2. 최종 회계 지점 조회 SQL:
--    - 재귀 CTE(Recursive Common Table Expression)를 사용하여 복잡한 지점-회계점 체인을 추적.
--    - MATERIALIZE, RESULT_CACHE, INDEX, USE_HASH 등 다양한 튜닝 힌트를 적용하여 대용량 데이터 환경에서도 고성능을 보장.
--    - ROW_NUMBER() 분석 함수를 사용하여 각 지점별 최종 데이터를 효율적으로 추출.
--    - 시작 지점의 폐쇄일자(START_CLOSE_DT)를 함께 조회하여 데이터 분석의 편의성을 높임.
================================================================================
*/

-- =============================================================================
-- 1. 테이블 및 시퀀스 재생성
-- =============================================================================
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE BRANCH_HISTORY';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
         RAISE;
      END IF;
END;
/

-- =============================================================================
-- 2. 테이블 생성 및 주석, 인덱스 정의
-- =============================================================================
CREATE TABLE BRANCH_HISTORY (
    BRANCH_CD       VARCHAR2(4)   NOT NULL,
    REG_SEQ         NUMBER        NOT NULL,
    BRANCH_NM       VARCHAR2(100),
    ACCT_BRANCH_CD  VARCHAR2(4),
    OPEN_DT         VARCHAR2(8),
    CLOSE_DT        VARCHAR2(8),
    UPD_USER_ID     VARCHAR2(20),
    UPD_DT          TIMESTAMP,
    REMARK          VARCHAR2(200),
    CONSTRAINT PK_BRANCH_HISTORY PRIMARY KEY (BRANCH_CD, REG_SEQ)
);

COMMENT ON TABLE  BRANCH_HISTORY IS '지점 이력 정보';
COMMENT ON COLUMN BRANCH_HISTORY.BRANCH_CD       IS '지점 코드';
COMMENT ON COLUMN BRANCH_HISTORY.REG_SEQ         IS '등록 일련번호';
COMMENT ON COLUMN BRANCH_HISTORY.BRANCH_NM       IS '지점명';
COMMENT ON COLUMN BRANCH_HISTORY.ACCT_BRANCH_CD  IS '회계 지점 코드';
COMMENT ON COLUMN BRANCH_HISTORY.OPEN_DT         IS '개설 일자';
COMMENT ON COLUMN BRANCH_HISTORY.CLOSE_DT        IS '폐쇄 일자';
COMMENT ON COLUMN BRANCH_HISTORY.UPD_USER_ID     IS '수정 사용자 ID';
COMMENT ON COLUMN BRANCH_HISTORY.UPD_DT          IS '수정 일시';
COMMENT ON COLUMN BRANCH_HISTORY.REMARK          IS '비고';

-- 회계 지점 역조인 최적화
CREATE INDEX IDX_BRANCH_HISTORY_ACCT_BRANCH ON BRANCH_HISTORY (ACCT_BRANCH_CD, BRANCH_CD);

-- 복합 인덱스: 범위 + 조인 + 탐색 혼합 케이스용 (Covering Index)
CREATE INDEX IDX_BRANCH_HISTORY_ALL ON BRANCH_HISTORY (OPEN_DT, CLOSE_DT, ACCT_BRANCH_CD, BRANCH_CD);

-- =============================================================================
-- 3. 샘플 데이터 입력
-- =============================================================================
-- 2010년 기본 개설
INSERT INTO BRANCH_HISTORY VALUES ('0004', 1, '종로4가', '0004', '20060101', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:34', NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0005', 1, '종로5가', '0005', '20060101', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:34', NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0006', 1, '종로6가', '0006', '20060101', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:34', NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0007', 1, '종로7가', '0007', '20060101', '20110720', 'SYS', TIMESTAMP '2025-11-08 02:38:34', '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0008', 1, '종로8가', '0008', '20060101', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:34', NULL);
INSERT INTO BRANCH_HISTORY VALUES ('0009', 1, '종로9가', '0009', '20060101', '20150421', 'SYS', TIMESTAMP '2025-11-08 02:38:37', '통폐합 이전');
INSERT INTO BRANCH_HISTORY VALUES ('0010', 1, '종로10가', '0010', '20060101', '20120520', 'SYS', TIMESTAMP '2025-11-08 02:38:41', '통폐합 이전');

-- 2011년 – 0007 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0007', 2, '종로7가', '0006', '20110721', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:34', '통폐합');

-- 2012년 – 0010 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0010', 2, '종로10가', '0009', '20120521', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:41', '통폐합');

-- 2015년 – 0009 통폐합
INSERT INTO BRANCH_HISTORY VALUES ('0009', 2, '종로9가', '0008', '20150421', '99999999', 'SYS', TIMESTAMP '2025-11-08 02:38:37', '통폐합');

COMMIT;
/

-- =============================================================================
-- 4. 통계 정보 수집
-- =============================================================================
-- 옵티마이저가 최적의 실행 계획을 수립하도록 통계 정보를 수집합니다.
-- 'YOUR_SCHEMA_NAME'은 실제 스키마명으로 변경해야 합니다.
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(ownname => 'YOUR_SCHEMA_NAME', tabname => 'BRANCH_HISTORY', estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE, cascade => TRUE);
END;
/

-- =============================================================================
-- 5. 최종 회계 지점 조회 SQL
-- =============================================================================
WITH
-- 5-1. 기준일에 유효한 지점 조회
VALID_BRANCH AS (
    SELECT /*+ MATERIALIZE RESULT_CACHE INDEX(BRANCH_HISTORY IDX_BRANCH_HISTORY_ALL) */
           BRANCH_CD,        -- 지점 코드
           OPEN_DT,          -- 개설 일자
           CLOSE_DT,         -- 폐쇄 일자
           BRANCH_NM,        -- 지점명
           ACCT_BRANCH_CD    -- 회계 지점 코드
      FROM BRANCH_HISTORY
     WHERE :STD_DATE BETWEEN OPEN_DT AND CLOSE_DT
),
-- 5-2. 지점-회계점 체인 재귀 CTE (시작 지점 CLOSE_DT 유지)
BRANCH_CHAIN (
    START_BRANCH_CD,    -- 시작 지점 코드
    START_BRANCH_NM,    -- 시작 지점명
    CUR_BRANCH_CD,      -- 현재 지점 코드 (재귀 추적용)
    CUR_ACCT_CD,        -- 현재 회계 지점 코드
    START_CLOSE_DT,     -- 시작 지점 CLOSE_DT (재귀 중에도 그대로 유지)
    LVL                 -- 재귀 깊이
) AS (
    -- Anchor Member: 각 지점에서 자신의 회계점으로 초기화
    SELECT BRANCH_CD,
           BRANCH_NM,
           BRANCH_CD,
           ACCT_BRANCH_CD,
           CLOSE_DT,   -- 시작 지점 CLOSE_DT
           1
      FROM VALID_BRANCH
    UNION ALL
    -- Recursive Member: 현재 회계점이 다른 지점이면 계속 추적
    SELECT /*+ USE_HASH(vb) */
           bc.START_BRANCH_CD,   -- 시작 지점 코드 그대로
           bc.START_BRANCH_NM,   -- 시작 지점명 그대로
           vb.BRANCH_CD,         -- 다음 지점 코드
           vb.ACCT_BRANCH_CD,    -- 다음 회계 지점 코드
           bc.START_CLOSE_DT,    -- 시작 지점 CLOSE_DT 유지
           bc.LVL + 1
      FROM BRANCH_CHAIN bc
      JOIN VALID_BRANCH vb
        ON bc.CUR_ACCT_CD = vb.BRANCH_CD
     WHERE bc.CUR_BRANCH_CD <> bc.CUR_ACCT_CD
)
CYCLE CUR_BRANCH_CD SET IS_CYCLE TO 'Y' DEFAULT 'N'
-- 5-3. 최종 회계점 조회 (시작 지점 CLOSE_DT 포함)
SELECT :STD_DATE AS STD_DATE,
       START_BRANCH_CD AS BRANCH_CD,
       START_BRANCH_NM AS BRANCH_NM,
       CUR_BRANCH_CD AS FINAL_ACCT_BRANCH_CD,
       START_CLOSE_DT AS START_BRANCH_CLOSE_DT  -- 시작 지점 CLOSE_DT
  FROM (
        SELECT START_BRANCH_CD,
               START_BRANCH_NM,
               CUR_BRANCH_CD,
               START_CLOSE_DT,
               ROW_NUMBER() OVER (PARTITION BY START_BRANCH_CD ORDER BY LVL DESC) AS RN
          FROM BRANCH_CHAIN
         WHERE IS_CYCLE = 'N'
       )
 WHERE RN = 1
 ORDER BY BRANCH_CD;