WITH 
/* 거래 이력을 저장하는 서브쿼리 */
TRADE_HISTORY AS (
    SELECT '20230128' AS TR_DT, '00002' AS SEQ FROM DUAL UNION ALL
    SELECT '20230128', '00003' FROM DUAL UNION ALL
    SELECT '20230128', '00004' FROM DUAL UNION ALL
    SELECT '20230128', '00006' FROM DUAL UNION ALL
    SELECT '20230128', '00008' FROM DUAL UNION ALL
    SELECT '20230128', '00010' FROM DUAL UNION ALL
    SELECT '20230128', '00011' FROM DUAL UNION ALL
    SELECT '20230128', '00013' FROM DUAL UNION ALL
    SELECT '20230128', '00020' FROM DUAL UNION ALL
    SELECT '20230128', '00023' FROM DUAL
),
/* '20230128' 날짜에 해당하는 시퀀스 범위를 구하는 서브쿼리 */
SEQUENCE_RANGE AS (
    SELECT
        1                   AS FT_SEQ,  /* 시퀀스 범위의 첫 번째 값 */
        MAX(TO_NUMBER(SEQ)) AS LT_SEQ   /* 시퀀스 범위의 마지막 값 */
    FROM
        TRADE_HISTORY
    WHERE
        TR_DT = '20230128'  /* '20230128' 날짜에 해당하는 거래 이력을 찾음 */
),
/* 범위 내에서 존재하지 않는 시퀀스를 생성하고, 거래 이력에 없는 시퀀스를 필터링 */
MISSING_SEQS AS (
    SELECT 
        LPAD(TO_CHAR(LEVEL + TA.FT_SEQ - 1), 5, '0') AS SEQ
    FROM 
        SEQUENCE_RANGE TA
    CONNECT BY 
        LEVEL <= TA.LT_SEQ - TA.FT_SEQ + 1   /* 범위 내 모든 시퀀스 번호를 생성 */
    MINUS
    SELECT SEQ
    FROM TRADE_HISTORY
    WHERE TR_DT = '20230128'  /* '20230128' 날짜에 존재하는 시퀀스를 제외 */
)
/* 존재하지 않는 시퀀스를 결과로 출력 */
SELECT SEQ
FROM MISSING_SEQS
WHERE EXISTS (SELECT 1 FROM TRADE_HISTORY WHERE TR_DT = '20230128')  /* '20230128' 날짜의 거래 이력이 존재하는 경우에만 출력 */
ORDER BY SEQ;  /* 시퀀스를 오름차순으로 정렬 */
