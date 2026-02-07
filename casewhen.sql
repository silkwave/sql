-- 조건 파라미터에 따라 컬럼을 선택적으로 비교하는 예제 (CASE 사용)
-- condition1/condition2 값에 따라 특정 컬럼과만 매칭되도록 필터링
SELECT *
FROM your_table
WHERE
    1 = CASE
            WHEN :condition1 IS NULL THEN 1 -- condition1 없으면 통과
            WHEN :condition1 = 'a' AND column1 = :condition1 THEN 1 -- a이면 column1 비교
            WHEN :condition1 = 'c' AND column3 = :condition1 THEN 1 -- c이면 column3 비교
            ELSE 0
        END
    AND
    1 = CASE
            WHEN :condition2 IS NULL THEN 1 -- condition2 없으면 통과
            WHEN :condition2 = 'b' AND column2 = :condition2 THEN 1 -- b이면 column2 비교
            WHEN :condition2 = 'd' AND column4 = :condition2 THEN 1 -- d이면 column4 비교
            ELSE 0
        END;
=======================================================================
-- 동일한 조건을 OR 조건으로 풀어쓴 형태 (가독성 비교용)
SELECT *
FROM your_table
WHERE
    (
        :condition1 IS NULL -- condition1 없으면 통과
        OR (:condition1 = 'a' AND column1 = :condition1) -- a이면 column1 비교
        OR (:condition1 = 'c' AND column3 = :condition1) -- c이면 column3 비교
    )
    AND
    (
        :condition2 IS NULL -- condition2 없으면 통과
        OR (:condition2 = 'b' AND column2 = :condition2) -- b이면 column2 비교
        OR (:condition2 = 'd' AND column4 = :condition2) -- d이면 column4 비교
    );

-- 성능 비교 예시 (실행 계획/실행 통계 확인)
-- SQL*Plus 기준 예시이며, 환경에 맞게 바인드 값을 지정해서 비교한다.
-- 1) CASE 방식
--    EXPLAIN PLAN FOR
--    SELECT /* CASE 방식 */ *
--    FROM your_table
--    WHERE 1 = CASE
--              WHEN :condition1 IS NULL THEN 1
--              WHEN :condition1 = 'a' AND column1 = :condition1 THEN 1
--              WHEN :condition1 = 'c' AND column3 = :condition1 THEN 1
--              ELSE 0
--            END
--      AND 1 = CASE
--              WHEN :condition2 IS NULL THEN 1
--              WHEN :condition2 = 'b' AND column2 = :condition2 THEN 1
--              WHEN :condition2 = 'd' AND column4 = :condition2 THEN 1
--              ELSE 0
--            END;
--    SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- SQL 모니터링 최근 실행 내역 조회
SELECT
    SQL_ID,         -- SQL 문을 고유하게 식별하는 ID
    SQL_EXEC_ID,    -- 특정 SQL 실행에 대한 실행 ID
    SQL_EXEC_START, -- SQL 실행이 시작된 시간 (타임스탬프)
    ELAPSED_TIME,   -- SQL 실행에 소요된 전체 경과 시간 (마이크로초 단위)
    CPU_TIME,       -- SQL 실행 동안 소비된 CPU 시간 (마이크로초 단위)
    SQL_TEXT        -- 실행 중인 SQL 문의 텍스트
FROM
    GV$SQL_MONITOR  -- SQL 모니터링 데이터를 제공하는 뷰
ORDER BY
    SQL_EXEC_START DESC; -- 가장 최근에 실행된 SQL부터 정렬
--
-- 2) OR 방식
--    EXPLAIN PLAN FOR
--    SELECT /* OR 방식 */ *
--    FROM your_table
--    WHERE ( :condition1 IS NULL
--            OR (:condition1 = 'a' AND column1 = :condition1)
--            OR (:condition1 = 'c' AND column3 = :condition1) )
--      AND ( :condition2 IS NULL
--            OR (:condition2 = 'b' AND column2 = :condition2)
--            OR (:condition2 = 'd' AND column4 = :condition2) );
--    SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
