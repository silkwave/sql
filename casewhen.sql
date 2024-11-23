SELECT *
FROM your_table
WHERE
    1 = CASE
            WHEN :condition1 IS NULL THEN 1
            WHEN :condition1 = 'a' AND column1 = :condition1 THEN 1
            WHEN :condition1 = 'c' AND column3 = :condition1 THEN 1
            ELSE 0
        END
    AND
    1 = CASE
            WHEN :condition2 IS NULL THEN 1
            WHEN :condition2 = 'b' AND column2 = :condition2 THEN 1
            WHEN :condition2 = 'd' AND column4 = :condition2 THEN 1
            ELSE 0
        END;
=======================================================================
SELECT *
FROM your_table
WHERE
    (
        :condition1 IS NULL
        OR (:condition1 = 'a' AND column1 = :condition1)
        OR (:condition1 = 'c' AND column3 = :condition1)
    )
    AND
    (
        :condition2 IS NULL
        OR (:condition2 = 'b' AND column2 = :condition2)
        OR (:condition2 = 'd' AND column4 = :condition2)
    );