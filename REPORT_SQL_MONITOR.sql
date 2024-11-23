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

 
SELECT
    DBMS_SQLTUNE.REPORT_SQL_MONITOR(SQL_ID=> 'c7u0y4hcxh36n', -- 분석할 SQL 문 ID
                                    SQL_EXEC_ID=> '16777256', -- 분석할 SQL 실행 ID
                                    TYPE=> 'TEXT',           -- 보고서 형식 (TEXT 형식)
                                    REPORT_LEVEL=> 'ALL',    -- 보고서 세부 수준 (모든 정보 포함)
                                    EVENT_DETAIL=> 'YES')    -- 대기 이벤트 정보를 포함 여부
FROM DUAL;


SELECT
    SQL_ID,
    SESSION_ID,
    SESSION_SERIAL#,
    PX_FLAGS,
    WAIT_CLASS,
    EVENT,
    SAMPLE_TIME
FROM
    GV$ACTIVE_SESSION_HISTORY
WHERE
    PX_FLAGS > 0 -- 병렬 실행 플래그가 있는 세션
ORDER BY
    SAMPLE_TIME DESC;


SELECT
    EVENT,
    WAIT_CLASS,
    TOTAL_WAITS,
    TIME_WAITED
FROM
    GV$ACTIVE_SESSION_HISTORY  /* 특정 SQL ID에 대한 대기 이벤트 분석 */
WHERE
    SQL_ID = 'd9p3tq1x5kd9g'
ORDER BY
    TIME_WAITED DESC;


SELECT
    SQL_ID,
    SQL_EXEC_ID,
    SQL_EXEC_START,
    ELAPSED_TIME,
    CPU_TIME,
    SQL_TEXT
FROM
    GV$SQL_MONITOR
WHERE
    SQL_EXEC_START >= SYSDATE - (1/24) /* 최근 1시간 동안 실행된 SQL */
ORDER BY
    SQL_EXEC_START DESC;