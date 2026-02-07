# 검색조건을 동적으로 바꾸어야 할 때 - 요약

## 요약
- 동적 조건을 `OR`로 묶고 `USE_CONCAT`로 OR-Expansion을 유도하면 `UNION ALL`과 유사한 효과를 낸다.
- 패턴별 인덱스를 유지하면서 SQL 길이를 줄이고, 필요하면 Global Hint로 블록별 실행계획을 제어한다.

## 문제 배경
- 조회 조건이 패턴에 따라 달라지며, 패턴별로 서로 다른 인덱스를 타게 하고 싶은 상황이다.
- `UNION ALL`로 분기하면 SQL이 길어지고, Dynamic SQL은 힌트까지 동적으로 조립해야 해 관리가 복잡해진다.

## 접근 방법
- 조건 분기를 `OR`로 묶고 `USE_CONCAT` 힌트를 사용한다.
- 공통 필터는 별도로 유지한다. 예: `d.manager_id > 0`.
- OR-Expansion이 작동하려면 **각 패턴에 맞는 인덱스**가 준비되어 있어야 한다.

## 주의점
- SQL 길이가 크게 늘어난다.
- Oracle 11g R2에서는 **쿼리 변환(CBQT)으로 의도치 않은 실행계획**이 발생할 수 있다.
- 예시로 Join Factorization(JF)처럼 공통 테이블을 분리하는 변환이 소개된다.

## 정리
- “동적 조건” 문제는 **OR-Expansion + 적절한 인덱스 + Global Hint**로 해결할 수 있다.
- `UNION ALL`과 Dynamic SQL은 꼭 필요한 경우에만 사용하고, 가능하면 더 단순한 구조를 우선 검토한다.

## 예제 SQL
### 1) OR-Expansion 유도 (권장)
```sql
SELECT /*+ USE_CONCAT */
       e.employee_id, e.email, e.phone_number, e.hire_date, e.salary,
       j.job_title, d.department_name, l.city, l.country_id
  FROM employee   e
  JOIN job        j ON e.job_id        = j.job_id
  JOIN department d ON e.department_id = d.department_id
  JOIN location   l ON d.location_id   = l.location_id
 WHERE (
          (:v_delimit = 1 AND j.job_id       = :v_job)
       OR (:v_delimit = 2 AND e.manager_id   = :v_emp
                        AND e.hire_date BETWEEN :v_hr_fr AND :v_hr_to)
       OR (:v_delimit = 3 AND d.department_id = :v_dept)
       OR (:v_delimit = 4 AND l.location_id  = :v_loc)
       )
   AND d.manager_id > 0;
```

### 2) UNION ALL 방식 (길어지고 관리비용 증가)
```sql
SELECT /* pattern 1 */ ...
  FROM ...
 WHERE :v_delimit = 1
   AND j.job_id = :v_job
   AND d.manager_id > 0
UNION ALL
SELECT /* pattern 2 */ ...
  FROM ...
 WHERE :v_delimit = 2
   AND e.manager_id = :v_emp
   AND e.hire_date BETWEEN :v_hr_fr AND :v_hr_to
   AND d.manager_id > 0
UNION ALL
SELECT /* pattern 3 */ ...
  FROM ...
 WHERE :v_delimit = 3
   AND d.department_id = :v_dept
   AND d.manager_id > 0
UNION ALL
SELECT /* pattern 4 */ ...
  FROM ...
 WHERE :v_delimit = 4
   AND l.location_id = :v_loc
   AND d.manager_id > 0;
```

### 3) 힌트 제어가 필요한 경우
```sql
SELECT /*+ USE_CONCAT */
       ...
  FROM ...
 WHERE (
          (:v_delimit = 1 AND ... )  -- 패턴 1용 인덱스/힌트 고려
       OR (:v_delimit = 2 AND ... )  -- 패턴 2용 인덱스/힌트 고려
       OR (:v_delimit = 3 AND ... )  -- 패턴 3용 인덱스/힌트 고려
       OR (:v_delimit = 4 AND ... )  -- 패턴 4용 인덱스/힌트 고려
       );
```

### 4) Global Hint로 블록별 조인 방식 제어
```sql
SELECT /*+ USE_CONCAT
           LEADING(@SEL$1_1 l d e j) USE_NL(@SEL$1_1 d e j)
           LEADING(@SEL$1_2 d e l j) USE_NL(@SEL$1_2 e l j)
           LEADING(@SEL$1_3 e d l j) USE_NL(@SEL$1_3 d l j)
           LEADING(@SEL$1_4 j e d l) USE_NL(@SEL$1_4 e d l) */
       e.employee_id, e.email, e.phone_number, e.hire_date, e.salary,
       j.job_title, d.department_name, l.city, l.country_id
  FROM employee e,
       job j,
       department d,
       location l
 WHERE e.job_id = j.job_id
   AND e.department_id = d.department_id
   AND d.location_id = l.location_id
   AND (   (:v_delimit = 1 AND j.job_id = :v_job)
        OR (:v_delimit = 2 AND e.manager_id = :v_emp
                          AND e.hire_date BETWEEN :v_hr_fr AND :v_hr_to)
        OR (:v_delimit = 3 AND d.department_id = :v_dept)
       OR (:v_delimit = 4 AND l.location_id = :v_loc)
       )
   AND d.manager_id > 0;
```

## 참고
- 원문: Science of Database, “검색조건을 동적으로 바꾸어야 할 때”
