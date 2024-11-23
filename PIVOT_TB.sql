-- UNPIVOT_TB 테이블이 존재하는 경우 삭제
BEGIN
     EXECUTE IMMEDIATE 'DROP TABLE UNPIVOT_TB';
EXCEPTION
     WHEN OTHERS THEN
         IF SQLCODE != -942 THEN
              RAISE;
         END IF;
END;
-- UNPIVOT_TB 테이블 생성
CREATE TABLE UNPIVOT_TB (nm VARCHAR2(50), c1 VARCHAR2(50), c2 VARCHAR2(50), c3 VARCHAR2(50), c4 VARCHAR2(50));
-- UNPIVOT_TB 테이블에 데이터 삽입
INSERT ALL
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('마농', '사과', '배', '자두', '딸기')
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('재석', '배', '수박', '바나나', '')
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('정식', '메론', '바나나', '자두', '딸기')
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('마소', '메론', '', '', '')
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('민용', '배', '자두', '사과', '딸기')
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('혜연', '자두', '딸기', '사과', '배')
   INTO UNPIVOT_TB (nm, c1, c2, c3, c4) VALUES ('수지', '오디', '코코넛', '두리안', '머루')
SELECT * FROM dual;
-- UNPIVOT 연산 수행
SELECT nm, c, g
FROM UNPIVOT_TB
UNPIVOT (
    c FOR g IN (c1 AS 'C1', c2 AS 'C2', c3 AS 'C3', c4 AS 'C4')
);
-- PIVOT_TB 테이블이 존재하는 경우 삭제
BEGIN
     EXECUTE IMMEDIATE 'DROP TABLE PIVOT_TB';
EXCEPTION
     WHEN OTHERS THEN
         IF SQLCODE != -942 THEN
              RAISE;
         END IF;
END;
-- UNPIVOT 결과를 PIVOT_TB 테이블로 저장
CREATE TABLE PIVOT_TB AS
SELECT nm, c, g
FROM UNPIVOT_TB
UNPIVOT (
    c FOR g IN (c1 AS 'C1', c2 AS 'C2', c3 AS 'C3', c4 AS 'C4')
);
-- PIVOT 연산 수행
SELECT nm, c1, c2, c3, c4
FROM PIVOT_TB
PIVOT (
    MAX(c) FOR g IN ('C1' AS c1, 'C2' AS c2, 'C3' AS c3, 'C4' AS c4)
);
