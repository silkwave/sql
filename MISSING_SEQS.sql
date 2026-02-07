WITH
/* ============================================================
 * [1] 기준 날짜 데이터만 추출 (실제 테이블 TARGET_HISTORY 기준)
 * ============================================================ */
TARGET_HISTORY AS (
    SELECT
        TR_DT,
        SEQ
    FROM
        TARGET_HISTORY
    WHERE
        TR_DT = '20230128'
),
/* ============================================================
 * [2] 기준 날짜의 시퀀스 범위 산정
 * ============================================================ */
SEQUENCE_RANGE AS (
    SELECT
        1                   AS FT_SEQ,  -- 시퀀스 범위의 첫 번째 값
        MAX(TO_NUMBER(SEQ)) AS LT_SEQ   -- 시퀀스 범위의 마지막 값
    FROM
        TARGET_HISTORY
),
/* ============================================================
 * [3] 누락 시퀀스 생성
 * ============================================================ */
MISSING_SEQS AS (
    SELECT
        LPAD(TO_CHAR(LEVEL + TA.FT_SEQ - 1), 5, '0') AS SEQ
    FROM
        SEQUENCE_RANGE TA
    CONNECT BY
        LEVEL <= TA.LT_SEQ - TA.FT_SEQ + 1  -- 범위 내 모든 시퀀스 번호 생성
    MINUS
    SELECT
        SEQ
    FROM
        TARGET_HISTORY
)
/* ============================================================
 * [4] 누락 시퀀스 출력
 * ============================================================ */
SELECT
    SEQ
FROM
    MISSING_SEQS
WHERE
    EXISTS (
        SELECT 1
        FROM TARGET_HISTORY
    )
ORDER BY
    SEQ;
