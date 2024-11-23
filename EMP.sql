http://www.gurubee.net/lecture/4422#a1

-- 총 20,000명의 사원이 여섯 개 부서로 나뉘도록 테이블을 생성함.
-- 각 사원은 서로 다른 식별자(EMP_NO)를 가지며, 급여(SALARY)도 서로 중복되지 않는다.
CREATE TABLE EMP(DEPT_NO    NOT NULL,
                 SAL,
                 EMP_NO		NOT NULL,
                 PADDING,
                 CONSTRAINT E_PK PRIMARY KEY(EMP_NO))
AS
WITH GENERATOR AS (SELECT ROWNUM ID
                   FROM   ALL_OBJECTS
                   WHERE  ROWNUM <= 1000)
SELECT /*+ ORDERED USE_NL(V2) */
       MOD(ROWNUM, 6),
       ROWNUM,
       ROWNUM,
       RPAD('X', 60)
FROM   GENERATOR V1,
       GENERATOR V2
WHERE  ROWNUM <= 20000
;

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(OWNNAME           => USER,
                                  TABNAME           => 'EMP',
                                  CASCADE           => TRUE,
                                  ESTIMATE_PERCENT  => NULL,
                                  METHOD_OPT        =>'FOR ALL COLUMNS SIZE 1');
END;



SELECT OUTER.*
FROM   EMP OUTER
WHERE  OUTER.SAL > (SELECT /*+ NO_UNNEST */
                           AVG(INNER.SAL)
                    FROM   EMP INNER
                    WHERE  INNER.DEPT_NO = OUTER.DEPT_NO);

/* ******************************************************* */
/* ******************************************************* */
/* ******************************************************* */

DROP TABLE PARENT;
DROP TABLE CHILD;
DROP TABLE SUBTEST;


CREATE TABLE PARENT(ID1        NUMBER NOT NULL,
                    SMALL_VC1  VARCHAR2(10),
                    SMALL_VC2  VARCHAR2(10),
                    PADDING    VARCHAR2(200),
                    CONSTRAINT PAR_PK PRIMARY KEY(ID1));

CREATE TABLE CHILD(ID1        NUMBER    NOT NULL,
                   ID2        NUMBER    NOT NULL,
                   SMALL_VC1  VARCHAR2(10),
                   SMALL_VC2  VARCHAR2(10),
                   PADDING	  VARCHAR2(200),
                   CONSTRAINT CHI_PK PRIMARY KEY (ID1,ID2));

CREATE TABLE SUBTEST (ID1        NUMBER NOT NULL,
                      SMALL_VC1	 VARCHAR2(10),
                      SMALL_VC2	 VARCHAR2(10),
                      PADDING    VARCHAR2(200),
                      CONSTRAINT SUB_PK PRIMARY KEY(ID1));

INSERT INTO PARENT
SELECT ROWNUM,
       TO_CHAR(ROWNUM),
       TO_CHAR(ROWNUM),
       RPAD(TO_CHAR(ROWNUM), 100)
FROM   ALL_OBJECTS
WHERE  ROWNUM <= 3000;

COMMIT;

BEGIN
    FOR I IN 1..8 LOOP
        INSERT INTO CHILD
        SELECT ROWNUM,
               I,
               TO_CHAR(ROWNUM),
               TO_CHAR(ROWNUM),
               RPAD(TO_CHAR(ROWNUM), 100)
        FROM   PARENT;
	COMMIT;
	END LOOP;
END;


INSERT INTO SUBTEST
SELECT * FROM PARENT;
COMMIT;

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER,
                                  'PARENT',
                                  CASCADE          => TRUE,
                                  ESTIMATE_PERCENT => NULL,
                                  METHOD_OPT       => 'FOR ALL COLUMNS SIZE 1');
END;


BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER,
                                  'CHILD',
                                  CASCADE          => TRUE,
                                  ESTIMATE_PERCENT => NULL,
                                  METHOD_OPT       => 'FOR ALL COLUMNS SIZE 1');
END;


BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER,
                                  'SUBTEST',
                                  CASCADE          => TRUE,
                                  ESTIMATE_PERCENT => NULL,
                                  METHOD_OPT       => 'FOR ALL COLUMNS SIZE 1');
END;



SELECT /*+ LEADING(PAR CHI) USE_NL(PAR CHI) */
       PAR.SMALL_VC1,
       CHI.SMALL_VC1
FROM   PARENT PAR,
       CHILD  CHI
WHERE  CHI.ID1 = PAR.ID1
AND    PAR.ID1 BETWEEN 100
               AND     200
AND    EXISTS (SELECT /*+ NO_UNNEST */
                      NULL
               FROM   SUBTEST SUB
               WHERE  SUB.SMALL_VC1 = PAR.SMALL_VC1
               AND    SUB.ID1       = PAR.ID1
               AND    SUB.SMALL_VC2 >= '2');

SELECT /*+ LEADING(PAR) */
       PAR.SMALL_VC1,
       CHI.SMALL_VC1
FROM   PARENT PAR,
       CHILD  CHI
WHERE  CHI.ID1 = PAR.ID1
AND    PAR.ID1 BETWEEN 100
               AND     200
AND    EXISTS (SELECT /*+ USE_NL(SUB) */
                      NULL
               FROM   SUBTEST SUB
               WHERE  SUB.SMALL_VC1 = PAR.SMALL_VC1
               AND    SUB.ID1       = PAR.ID1
               AND    SUB.SMALL_VC2 >= '2');


/* ******************************************************* */
/* ******************************************************* */
/* ******************************************************* */

DROP TABLE EMP;
DROP TABLE GENERATOR;

CREATE TABLE GENERATOR AS
SELECT ROWNUM ID
FROM   ALL_OBJECTS
WHERE  ROWNUM <= 1000;

CREATE TABLE EMP(DEPT_NO    NOT NULL,
                 SAL,
                 EMP_NO     NOT NULL,
                 PADDING,
                 CONSTRAINT E_PK PRIMARY KEY(EMP_NO)
)
AS
SELECT /*+ ORDERED USE_NL(V2) */
       MOD(ROWNUM, 6),
       ROWNUM,
       ROWNUM,
       RPAD('X', 60)
FROM   GENERATOR V1,
       GENERATOR V2
WHERE  ROWNUM <= 20000
;

BEGIN
	DBMS_STATS.GATHER_TABLE_STATS(OWNNAME           => USER,
                                  TABNAME           => 'EMP',
                                  CASCADE           => TRUE,
                                  ESTIMATE_PERCENT  => NULL,
                                  METHOD_OPT        =>'FOR ALL COLUMNS SIZE 1');
END;


SELECT COUNT(AV_SAL)
FROM   (SELECT /*+ NO_MERGE */
              OUTER.DEPT_NO,
              OUTER.SAL,
              OUTER.EMP_NO,
              OUTER.PADDING,
              (SELECT AVG(INNER.SAL)
               FROM   EMP
               INNER  WHERE INNER.DEPT_NO = OUTER.DEPT_NO) AV_SAL
        FROM   EMP OUTER)
WHERE  SAL > AV_SAL
;

SELECT COUNT(AV_SAL)
FROM   (SELECT /*+ NO_MERGE */
              OUTER.DEPT_NO,
              OUTER.SAL,
              OUTER.EMP_NO,
              OUTER.PADDING,
              (SELECT AVG(INNER.SAL)
               FROM   EMP
               INNER  WHERE INNER.DEPT_NO = OUTER.DEPT_NO) AV_SAL
        FROM   EMP OUTER)
--WHERE  SAL > AV_SAL
;

SELECT /*+ NO_MERGE */
      OUTER.DEPT_NO,
      OUTER.SAL,
      OUTER.EMP_NO,
      OUTER.PADDING,
      (SELECT AVG(INNER.SAL)
       FROM   EMP
       INNER  WHERE INNER.DEPT_NO = OUTER.DEPT_NO) AV_SAL
FROM   EMP OUTER
;
