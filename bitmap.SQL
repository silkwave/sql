-- 비트맵 인덱스 테스트 스크립트
-- 주의: 테스트용 객체를 삭제/생성하므로 개발 스키마에서 실행

DROP TABLE t1;

BEGIN
    -- 리사이클빈 정리(권한/환경에 따라 실패 가능)
    BEGIN
        EXECUTE IMMEDIATE 'purge recyclebin';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- 시스템 통계 삭제(권한/환경에 따라 실패 가능)
    BEGIN
        EXECUTE IMMEDIATE 'begin dbms_stats.delete_system_stats; end;';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- 옵티마이저 비용 모델 설정
    BEGIN
        EXECUTE IMMEDIATE 'alter session set "_optimizer_cost_model" = io';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
END;

-- 테스트용 테이블 생성(소량 데이터)
CREATE TABLE t1
PCTFREE 70
PCTUSED 30
NOLOGGING
AS
SELECT
    -- 선택도 낮은 컬럼(간헐적으로 값이 존재)
    CASE MOD((ROWNUM - 1), 20) WHEN 0 THEN ROWNUM - 1 ELSE NULL END AS n1,
    CASE TRUNC((ROWNUM - 1) / 500) WHEN 0 THEN ROWNUM - 1 ELSE NULL END AS n2,
    --
    CASE MOD((ROWNUM - 1), 25) WHEN 0 THEN ROWNUM - 1 ELSE NULL END AS n3,
    CASE TRUNC((ROWNUM - 1) / 400) WHEN 0 THEN ROWNUM - 1 ELSE NULL END AS n4,
    --
    CASE MOD((ROWNUM - 1), 25) WHEN 0 THEN ROWNUM - 1 ELSE NULL END AS n5,
    CASE TRUNC((ROWNUM - 1) / 400) WHEN 0 THEN ROWNUM - 1 ELSE NULL END AS n6,
    --
    LPAD(ROWNUM, 10, '0') AS small_vc,
    RPAD('x', 220) AS padding
FROM
    all_objects
WHERE
    ROWNUM <= 10000;

-- 비트맵 인덱스 생성
CREATE BITMAP INDEX t1_i1 ON t1(n1)
NOLOGGING
PCTFREE 90
;

CREATE BITMAP INDEX t1_i2 ON t1(n2)
NOLOGGING
PCTFREE 90
;

CREATE BITMAP INDEX t1_i3 ON t1(n3)
NOLOGGING
PCTFREE 90
;

CREATE BITMAP INDEX t1_i4 ON t1(n4)
NOLOGGING
PCTFREE 90
;

-- 비교용 B-Tree 인덱스
CREATE INDEX t1_i5 ON t1(n5)
NOLOGGING
PCTFREE 90
;

CREATE INDEX t1_i6 ON t1(n6)
NOLOGGING
PCTFREE 90
;

BEGIN
    dbms_stats.gather_table_stats(
        user,
        't1',
        cascade => true,
        estimate_percent => null,
        method_opt => 'for all columns size 1'
    );
END;

-- 단일 컬럼 조건 테스트
SELECT * FROM t1 WHERE n6 = 2;

SELECT small_vc FROM t1 WHERE n6 = 2;

SELECT small_vc FROM t1 WHERE n5 = 2;

SELECT small_vc FROM t1 WHERE n4 = 2;

SELECT small_vc FROM t1 WHERE n3 = 2;

-- 복합 조건 테스트(선택도 조합)
SELECT
    small_vc
FROM
    t1
WHERE
    n1 = 2 -- 20건 중 1건
AND n3 = 2 -- 25건 중 1건
;

SELECT
    small_vc
FROM
    t1
WHERE
    n2 = 2 -- 500건 중 1건
AND n4 = 2 -- 400건 중 1건
;

DROP TABLE t1;

-- 대량 데이터로 재생성
CREATE TABLE t1 AS
WITH generator AS (
    SELECT
        --+ MATERIALIZE
        rownum id
    FROM
        all_objects
    WHERE
        rownum <= 1000000
)
SELECT
    /*+ ORDERED USE_NL(v2) */
    -- 1000건 중 1건만 값이 존재하도록 설정
    CASE WHEN MOD(rownum - 1, 1000) = 0 THEN rownum - 1 ELSE NULL END AS n1,
    CASE WHEN MOD(rownum - 1, 1000) = 0 THEN rownum - 1 ELSE NULL END AS n2,
    LPAD(rownum - 1, 10, '0') AS small_vc
FROM
    generator v1
    CROSS JOIN generator v2;

-- 비트맵 인덱스 생성(대량 데이터)
CREATE BITMAP INDEX t1_i1 ON t1(n1);
CREATE BITMAP INDEX t1_i2 ON t1(n2);

BEGIN
    dbms_stats.gather_table_stats(
        user,
        't1',
        cascade => true,
        estimate_percent => null,
        method_opt => 'for all columns size 1'
    );
END;

-- OR 조건 테스트(비트맵 효율 확인)
SELECT
    small_vc
FROM
    t1
WHERE
    n1 = 50000
;

SELECT
    small_vc
FROM
    t1
WHERE
    n1 = 50000
OR  n2 = 50000
;

SELECT
    small_vc
FROM
    t1
WHERE
    n1 = 50000
OR  (n2 = 50000 AND n2 IS NOT NULL)
;

-- 팩트/차원 조인 기반 비트맵 인덱스 예시
CREATE BITMAP INDEX fct_dim_name ON fact_table(dim.dim_name)
FROM
    dim_table   dim,
    fact_table  fct
WHERE
    dim.id = fct.dim_id
;

CREATE BITMAP INDEX fct_dim_par ON fact_table(dim.par_name)
FROM
    dim_table   dim,
    fact_table  fct
WHERE
    dim.id = fct.dim_id
;
