-- ┌────────────────────────────────────────────────────────────────────────────────┐
-- │                                                                                │
-- │  은행 실무용 지점 및 계좌 이력 테이블 생성 스크립트 (v2.0)                       │
-- │                                                                                │
-- ├────────────────────────────────────────────────────────────────────────────────┤
-- │                                                                                │
-- │  - 작성자: Gemini                                                              │
-- │  - 작성일: 2025-11-08                                                          │
-- │  - 변경내용: 실무 적용을 위한 마스터 테이블 추가, 감사 컬럼, FK, 인덱스 등 적용 │
-- │                                                                                │
-- └────────────────────────────────────────────────────────────────────────────────┘

-- ================================================================================
-- 0. 사전 테이블 삭제 (필요시 사용)
-- ================================================================================
-- DROP TABLE ACCOUNT_HISTORY;
-- DROP TABLE BRANCH_HISTORY;
-- DROP TABLE BRANCH_MASTER;


-- ================================================================================
-- 1. BRANCH_MASTER (지점 마스터 테이블)
-- ================================================================================
CREATE TABLE BRANCH_MASTER (
    BRANCH_CD       VARCHAR2(4)         NOT NULL,
    BRANCH_NM       VARCHAR2(100)       NOT NULL,
    REG_DT          DATE                DEFAULT SYSDATE NOT NULL,
    REG_USER_ID     VARCHAR2(20)        NOT NULL,
    UPD_DT          DATE                DEFAULT SYSDATE NOT NULL,
    UPD_USER_ID     VARCHAR2(20)        NOT NULL,
    CONSTRAINT PK_BRANCH_MASTER PRIMARY KEY (BRANCH_CD)
);

COMMENT ON TABLE  BRANCH_MASTER IS '지점 마스터 테이블';
COMMENT ON COLUMN BRANCH_MASTER.BRANCH_CD IS '지점 코드';
COMMENT ON COLUMN BRANCH_MASTER.BRANCH_NM IS '지점 명';
COMMENT ON COLUMN BRANCH_MASTER.REG_DT IS '등록 일시';
COMMENT ON COLUMN BRANCH_MASTER.REG_USER_ID IS '등록자 ID';
COMMENT ON COLUMN BRANCH_MASTER.UPD_DT IS '수정 일시';
COMMENT ON COLUMN BRANCH_MASTER.UPD_USER_ID IS '수정자 ID';


-- ================================================================================
-- 2. BRANCH_HISTORY (지점 이력 테이블)
-- ================================================================================
CREATE TABLE BRANCH_HISTORY (
    BRANCH_CD         VARCHAR2(4)       NOT NULL,
    OPEN_DT           DATE              NOT NULL,
    CLOSE_DT          DATE,
    ACCT_BRANCH_CD    VARCHAR2(4),
    BRANCH_STATUS_CD  VARCHAR2(10)      NOT NULL, -- 'OPEN', 'CLOSED', 'MERGED'
    REG_DT            DATE              DEFAULT SYSDATE NOT NULL,
    REG_USER_ID       VARCHAR2(20)      NOT NULL,
    UPD_DT            DATE              DEFAULT SYSDATE NOT NULL,
    UPD_USER_ID       VARCHAR2(20)      NOT NULL,
    CONSTRAINT PK_BRANCH_HISTORY PRIMARY KEY (BRANCH_CD, OPEN_DT),
    CONSTRAINT FK_BH_BRANCH_CD FOREIGN KEY (BRANCH_CD) REFERENCES BRANCH_MASTER(BRANCH_CD)
);

COMMENT ON TABLE  BRANCH_HISTORY IS '지점 이력 테이블';
COMMENT ON COLUMN BRANCH_HISTORY.BRANCH_CD IS '지점 코드';
COMMENT ON COLUMN BRANCH_HISTORY.OPEN_DT IS '시작일';
COMMENT ON COLUMN BRANCH_HISTORY.CLOSE_DT IS '종료일';
COMMENT ON COLUMN BRANCH_HISTORY.ACCT_BRANCH_CD IS '회계 지점 코드';
COMMENT ON COLUMN BRANCH_HISTORY.BRANCH_STATUS_CD IS '지점 상태 코드';
COMMENT ON COLUMN BRANCH_HISTORY.REG_DT IS '등록 일시';
COMMENT ON COLUMN BRANCH_HISTORY.REG_USER_ID IS '등록자 ID';
COMMENT ON COLUMN BRANCH_HISTORY.UPD_DT IS '수정 일시';
COMMENT ON COLUMN BRANCH_HISTORY.UPD_USER_ID IS '수정자 ID';

-- 인덱스 추가
CREATE INDEX IDX_BRANCH_HISTORY_01 ON BRANCH_HISTORY(CLOSE_DT);
CREATE INDEX IDX_BRANCH_HISTORY_02 ON BRANCH_HISTORY(ACCT_BRANCH_CD);


-- ================================================================================
-- 3. ACCOUNT_HISTORY (계좌 이력 테이블)
-- ================================================================================
CREATE TABLE ACCOUNT_HISTORY (
    ACCT_NO         VARCHAR2(20)        NOT NULL,
    OPEN_DT         DATE                NOT NULL,
    CLOSE_DT        DATE,
    BRANCH_CD       VARCHAR2(4)         NOT NULL,
    REG_DT          DATE                DEFAULT SYSDATE NOT NULL,
    REG_USER_ID     VARCHAR2(20)        NOT NULL,
    UPD_DT          DATE                DEFAULT SYSDATE NOT NULL,
    UPD_USER_ID     VARCHAR2(20)        NOT NULL,
    CONSTRAINT PK_ACCOUNT_HISTORY PRIMARY KEY (ACCT_NO, OPEN_DT),
    CONSTRAINT FK_AH_BRANCH_CD FOREIGN KEY (BRANCH_CD) REFERENCES BRANCH_MASTER(BRANCH_CD)
);

COMMENT ON TABLE  ACCOUNT_HISTORY IS '계좌 이력 테이블';
COMMENT ON COLUMN ACCOUNT_HISTORY.ACCT_NO IS '계좌번호';
COMMENT ON COLUMN ACCOUNT_HISTORY.OPEN_DT IS '시작일';
COMMENT ON COLUMN ACCOUNT_HISTORY.CLOSE_DT IS '종료일';
COMMENT ON COLUMN ACCOUNT_HISTORY.BRANCH_CD IS '소속 지점 코드';
COMMENT ON COLUMN ACCOUNT_HISTORY.REG_DT IS '등록 일시';
COMMENT ON COLUMN ACCOUNT_HISTORY.REG_USER_ID IS '등록자 ID';
COMMENT ON COLUMN ACCOUNT_HISTORY.UPD_DT IS '수정 일시';
COMMENT ON COLUMN ACCOUNT_HISTORY.UPD_USER_ID IS '수정자 ID';

-- 인덱스 추가
CREATE INDEX IDX_ACCOUNT_HISTORY_01 ON ACCOUNT_HISTORY(CLOSE_DT);
CREATE INDEX IDX_ACCOUNT_HISTORY_02 ON ACCOUNT_HISTORY(BRANCH_CD);


-- ================================================================================
-- 4. 샘플 데이터
-- ================================================================================
-- SQL*Plus 또는 SQL Developer와 같은 클라이언트에서 사용
VARIABLE USER_ID VARCHAR2(20);
EXEC :USER_ID := 'GEMINI';

-- 예시 1: 'A001' (강남중앙지점), 'B001' (서초지점) 지점 마스터 생성
INSERT INTO BRANCH_MASTER (BRANCH_CD, BRANCH_NM, REG_USER_ID, UPD_USER_ID)
VALUES ('A001', '강남중앙지점', :USER_ID, :USER_ID);
INSERT INTO BRANCH_MASTER (BRANCH_CD, BRANCH_NM, REG_USER_ID, UPD_USER_ID)
VALUES ('B001', '서초지점', :USER_ID, :USER_ID);

-- 예시 2: 'A001' 지점이 2023-01-01에 개설됨
INSERT INTO BRANCH_HISTORY (BRANCH_CD, OPEN_DT, ACCT_BRANCH_CD, BRANCH_STATUS_CD, REG_USER_ID, UPD_USER_ID)
VALUES ('A001', TO_DATE('2023-01-01', 'YYYY-MM-DD'), 'A001', 'OPEN', :USER_ID, :USER_ID);

-- 예시 3: '1234-5678' 계좌가 2023-01-01에 'A001' 지점에 개설됨
INSERT INTO ACCOUNT_HISTORY (ACCT_NO, OPEN_DT, BRANCH_CD, REG_USER_ID, UPD_USER_ID)
VALUES ('1234-5678', TO_DATE('2023-01-01', 'YYYY-MM-DD'), 'A001', :USER_ID, :USER_ID);

COMMIT;

-- 예시 4: (시간 경과 후) 'A001' 지점이 2025-12-31에 폐쇄되고 'B001' 지점으로 통폐합됨
--         a. 기존 'A001' 이력의 종료일 업데이트
UPDATE BRANCH_HISTORY
   SET CLOSE_DT = TO_DATE('2025-12-31', 'YYYY-MM-DD'),
       BRANCH_STATUS_CD = 'MERGED',
       UPD_DT = SYSDATE,
       UPD_USER_ID = :USER_ID
 WHERE BRANCH_CD = 'A001'
   AND CLOSE_DT IS NULL;

--         b. 통폐합 이후 'A001'의 회계지점을 'B001'로 하는 신규 이력 생성
INSERT INTO BRANCH_HISTORY (BRANCH_CD, OPEN_DT, ACCT_BRANCH_CD, BRANCH_STATUS_CD, REG_USER_ID, UPD_USER_ID)
VALUES ('A001', TO_DATE('2026-01-01', 'YYYY-MM-DD'), 'B001', 'CLOSED', :USER_ID, :USER_ID);


-- 예시 5: '1234-5678' 계좌의 소속 지점이 2026-01-01부터 'B001'로 변경됨
--         a. 기존 계좌 이력의 종료일 업데이트
UPDATE ACCOUNT_HISTORY
   SET CLOSE_DT = TO_DATE('2025-12-31', 'YYYY-MM-DD'),
       UPD_DT = SYSDATE,
       UPD_USER_ID = :USER_ID
 WHERE ACCT_NO = '1234-5678'
   AND CLOSE_DT IS NULL;

--         b. 'B001' 지점으로 신규 이력 생성
INSERT INTO ACCOUNT_HISTORY (ACCT_NO, OPEN_DT, BRANCH_CD, REG_USER_ID, UPD_USER_ID)
VALUES ('1234-5678', TO_DATE('2026-01-01', 'YYYY-MM-DD'), 'B001', :USER_ID, :USER_ID);

COMMIT;

-- ================================================================================
-- 5. 데이터 조회 예시
-- ================================================================================
-- 예시 1: 특정 기준일(2024-06-01) 현재 유효한 계좌의 소속 지점 조회
SELECT a.ACCT_NO, a.BRANCH_CD, b.BRANCH_NM
  FROM ACCOUNT_HISTORY a
  JOIN BRANCH_MASTER b ON a.BRANCH_CD = b.BRANCH_CD
 WHERE TO_DATE('2024-06-01', 'YYYY-MM-DD') BETWEEN a.OPEN_DT AND NVL(a.CLOSE_DT, TO_DATE('9999-12-31', 'YYYY-MM-DD'));

-- 예시 2: 특정 기준일(2026-06-01) 현재 유효한 계좌의 소속 지점 및 '회계' 지점 조회
SELECT a.ACCT_NO,
       a.BRANCH_CD AS "소속지점",
       bm.BRANCH_NM AS "소속지점명",
       bh.ACCT_BRANCH_CD AS "회계지점",
       (SELECT BRANCH_NM FROM BRANCH_MASTER WHERE BRANCH_CD = bh.ACCT_BRANCH_CD) AS "회계지점명"
  FROM ACCOUNT_HISTORY a
  JOIN BRANCH_HISTORY bh
    ON a.BRANCH_CD = bh.BRANCH_CD
   AND TO_DATE('2026-06-01', 'YYYY-MM-DD') BETWEEN bh.OPEN_DT AND NVL(bh.CLOSE_DT, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
  JOIN BRANCH_MASTER bm
    ON a.BRANCH_CD = bm.BRANCH_CD
 WHERE TO_DATE('2026-06-01', 'YYYY-MM-DD') BETWEEN a.OPEN_DT AND NVL(a.CLOSE_DT, TO_DATE('9999-12-31', 'YYYY-MM-DD'));
