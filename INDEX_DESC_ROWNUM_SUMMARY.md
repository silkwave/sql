# Index_desc + ROWNUM = 1 조합 안전성 요약

## 결론
- `INDEX_DESC` + `ROWNUM = 1` 조합은 **값의 정확성을 보장하지 못할 수 있어 안전하지 않다**.
- 성능보다 **정확한 결과**가 우선이며, 인덱스 구성 변경/삭제/이름 변경 시 오답 가능성이 커진다.
- 가능한 경우 **`FIRST ROW (MIN/MAX)`를 사용하는 것이 권장**된다.
- 글에서는 **어떤 이유로도 받아들여져서는 안 되는 방법**으로 강하게 경고한다.

## 핵심 논지
- 전통적으로 “최종 값(예: MAX)”을 빠르게 구하려고 `INDEX_DESC` + `ROWNUM = 1`을 사용했으나, **정답 보장보다 성능을 우선한 위험한 방식**으로 평가된다.
- 오라클은 이를 대체하기 위해 **`FIRST ROW (MIN/MAX)` 연산**을 제공하며, **가능한 경우 이를 사용해야 한다**.

## 인덱스 구성별 시나리오 요약
- **조건 컬럼이 인덱스 선두에 잘 맞는 경우**
  - `FIRST ROW (MIN/MAX)`가 효율적이며 정답 보장.
- **중간 컬럼이 조건에서 빠지는 경우**
  - 선택도가 충분하면 `FIRST ROW (MIN/MAX)`를 유지해도 문제 없음.
- **선두 컬럼이 조건에서 빠지는 경우**
  - 인덱스 풀 스캔이 발생할 수 있어 비효율적.
  - 이 경우에도 “정답 보장”이 핵심이며, 단순 `INDEX_DESC + ROWNUM`은 위험.

## 서브쿼리/인라인뷰로 집합 보완 시도
- 인덱스 선두 컬럼 누락 문제를 보완하려고 집합을 인위적으로 추가하는 방법이 제시되지만,
  - 불필요한 조인/스캔 비용이 증가할 수 있고,
  - “MAX 보장”이 명시적으로 확보되는 형태도 아님.

## Index Skip Scan 관련 결론
- `MIN/MAX`와 `INDEX SKIP SCAN`을 동시에 사용하기 어렵다.
- 오라클 10g/11g에서는 `MIN/MAX`와 `INDEX SKIP SCAN` 조합이 지원되지 않는 사례가 제시됨.

## 실무 권고
- **정확성 보장**이 최우선인 SQL에서는 `INDEX_DESC + ROWNUM = 1`을 기본 해법으로 삼지 않는다.
- 가능한 한 `FIRST ROW (MIN/MAX)`를 우선 고려하고,
  - 인덱스 설계를 조정하거나
  - SQL을 명확히 “MAX 보장” 형태로 작성한다.

## 예외적 언급
- 선두 컬럼이 조건절에서 빠지는 상황에서는 `FIRST ROW (MIN/MAX)`와 집합 보완 방식 모두 비효율적일 수 있어, **값이 바뀌지 않음을 전제**로 `INDEX_DESC + ROWNUM`을 고려할 수 있다는 언급이 있다.
- 다만 이 경우 **`INDEX_SS_DESC + ROWNUM`이 필요할 수 있고, SQL 변경 없이는 불가능**하다는 한계가 제시된다.

## 예제 SQL
### 1) 권장: `FIRST ROW (MIN/MAX)` 기반
```sql
SELECT /*+ gather_plan_statistics INDEX(s ix_cust_channel_time) */
       MAX(time_id)
  FROM sales s
 WHERE cust_id = :v_cust
   AND channel_id = 2;
```

### 2) 비권장: `INDEX_DESC + ROWNUM = 1`
```sql
SELECT /*+ INDEX_DESC(s ix_cust_channel_time) */
       time_id
  FROM sales s
 WHERE cust_id = :v_cust
   AND channel_id = 2
   AND ROWNUM = 1;
```

### 3) 집합 보완(인라인뷰) 예시
```sql
SELECT time_id
  FROM (
        SELECT /*+ LEADING(c) INDEX_DESC(s ix_time_cust_channel) */
               s.time_id
          FROM sales s,
               (SELECT TRUNC(SYSDATE) - LEVEL + 1 AS time_id
                  FROM dual
                CONNECT BY LEVEL <= 7300) c
         WHERE s.cust_id = :v_cust
           AND s.channel_id = 2
           AND s.time_id = c.time_id
       )
 WHERE ROWNUM = 1;
```

### 4) 안정적 대안: `INDEX_SS_DESC + ORDER BY`를 인라인뷰에 사용
```sql
SELECT MAX(time_id)
  FROM (
        SELECT /*+ INDEX_SS_DESC(s ix_time_cust_channel) */
               time_id
          FROM sales s
         WHERE cust_id = :v_cust
           AND channel_id = 2
         ORDER BY time_id DESC
       )
 WHERE ROWNUM = 1;
```

## 참고
- 출처(원문 URL):
  - `https://scidb.tistory.com/entry/Indexdesc-%ED%9E%8C%ED%8A%B8%EC%99%80-rownum-1-%EC%A1%B0%ED%95%A9%EC%9D%80-%EC%95%88%EC%A0%84%ED%95%9C%EA%B0%80`
