-- 1. 테이블 생성
DROP TABLE GENERATOR;

CREATE TABLE GENERATOR AS
SELECT ROWNUM ID
FROM   ALL_OBJECTS
WHERE  ROWNUM <= 2000
;

DROP TABLE T1;

-- 1-1) 디폴트 값 있는 T1
CREATE TABLE T1
NOLOGGING
PCTFREE 0
AS
SELECT /*+ ORDERED USE_NL(V2) */
       DECODE(MOD(ROWNUM - 1, 1000),
              0,
              TO_DATE('49991031', 'YYYYMMDD'),
              TO_DATE('20000101', 'YYYYMMDD') + TRUNC((ROWNUM - 1) / 100)) DATE_CLOSED
FROM   GENERATOR V1,
       GENERATOR V2
WHERE  ROWNUM <= 1827 * 100
;

DROP TABLE T2;

-- 1-2) 디폴트 값 없는 T2
CREATE TABLE T2
NOLOGGING
PCTFREE 0
AS
SELECT /*+ ORDERED USE_NL(V2) */
       TO_DATE('20000101', 'YYYYMMDD') + TRUNC((ROWNUM - 1) / 100) DATE_CLOSED
FROM   GENERATOR V1,
       GENERATOR V2
WHERE  ROWNUM <= 1827 * 100
;


-- 2. 데이터 조회
-- 2-1) 디폴트 값 있는 T1
SELECT DATE_CLOSED, COUNT(*)
FROM   (SELECT /*+ ORDERED USE_NL(V2) */
               DECODE(MOD(ROWNUM - 1, 1000),
                      0,
                      TO_DATE('49991031', 'YYYYMMDD'),
                      TO_DATE('20000101', 'YYYYMMDD') + TRUNC((ROWNUM - 1) / 100)) DATE_CLOSED
        FROM   GENERATOR V1,
               GENERATOR V2
        WHERE  ROWNUM <= 1827 * 100)
GROUP BY DATE_CLOSED
ORDER BY 1 DESC
;

-- 2-2) 디폴트 값 없는 T2
SELECT DATE_CLOSED, COUNT(*)
FROM   (SELECT /*+ ORDERED USE_NL(V2) */
               TO_DATE('20000101', 'YYYYMMDD') + TRUNC((ROWNUM - 1) / 100) DATE_CLOSED
        FROM   GENERATOR V1,
               GENERATOR V2
        WHERE  ROWNUM <= 1827 * 100)
GROUP BY DATE_CLOSED
ORDER BY 1 DESC
;



-- 3. 통계정보 생성
-- 3-1) 디폴트 값 있는 T1
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME           => USER,
                                  TABNAME           => 'T1',
                                  CASCADE           => TRUE,
                                  ESTIMATE_PERCENT  => NULL,
                                  METHOD_OPT        =>'FOR ALL COLUMNS SIZE 1');
END;


-- 3-2) 디폴트 값 없는 T2
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME           => USER,
                                  TABNAME           => 'T2',
                                  CASCADE           => TRUE,
                                  ESTIMATE_PERCENT  => NULL,
                                  METHOD_OPT        =>'FOR ALL COLUMNS SIZE 1');
END;


-- 4. 통계정보 확인
-- 4-1) 디폴트 값 있는 T1
SELECT COLUMN_NAME,
       NUM_DISTINCT,
       DENSITY
FROM   USER_TAB_COLUMNS
WHERE  TABLE_NAME = 'T1'
;

-- 4-2) 디폴트 값 없는 T2
SELECT COLUMN_NAME,
       NUM_DISTINCT,
       DENSITY
FROM   USER_TAB_COLUMNS
WHERE  TABLE_NAME = 'T2'
;

-- 6. T1 테이블 히스토그램 생성
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME           => USER,
                                  TABNAME           => 'T1',
                                  CASCADE           => TRUE,
                                  ESTIMATE_PERCENT  => NULL,
                                  METHOD_OPT        =>'FOR ALL COLUMNS SIZE 11');
END;

-- 7. 데이터 분포 확인
SELECT ROWNUM BUCKET,
       TO_CHAR(TO_DATE(PREV, 'J'), 'DD-MON-YYYY') LOW_VAL,
       TO_CHAR(TO_DATE(CURR, 'J'), 'DD-MON-YYYY') HIGH_VAL,
       CURR - PREV WIDTH,
       ROUND((182700 / 11) / (CURR - PREV), 4) HEIGHT
FROM   (SELECT ENDPOINT_VALUE CURR,
               LAG(ENDPOINT_VALUE, 1) OVER(ORDER BY ENDPOINT_NUMBER) PREV
        FROM   USER_TAB_HISTOGRAMS
        WHERE  TABLE_NAME = 'T1'
        AND    COLUMN_NAME = 'DATE_CLOSED')
WHERE  PREV IS NOT NULL
ORDER  BY CURR
;