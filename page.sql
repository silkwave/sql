SELECT *
FROM (
    SELECT s.*, ROWNUM rnum
    FROM (
        SELECT /*+ INDEX(S PK_SALES_T) */
            s.prod_id, s.cust_id, s.channel_id, s.time_id, amount_sold,
            SUM(amount_sold) OVER (PARTITION BY s.cust_id ORDER BY s.channel_id, s.time_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS sum_amt
        FROM sales_t s
        WHERE s.prod_id = :v_prod_id
        ORDER BY s.cust_id, s.channel_id, s.time_id
    ) s
    WHERE ROWNUM <= :v_max_row
) 
WHERE rnum >= :v_min_row;