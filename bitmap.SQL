drop table t1;

begin
    begin       execute immediate 'purge recyclebin';
    exception   when others then null;
    end;

    begin       execute immediate 'begin dbms_stats.delete_system_stats; end;';
    exception   when others then null;
    end;

    begin       execute immediate 'alter session set "_optimizer_cost_model"=io';
    exception   when others then null;
    end;

end;

CREATE TABLE t1
PCTFREE 70
PCTUSED 30
NOLOGGING
AS
SELECT
    CASE MOD((ROWNUM-1), 20)   WHEN 0 THEN ROWNUM-1 ELSE NULL END AS n1,
    CASE TRUNC((ROWNUM-1)/500) WHEN 0 THEN ROWNUM-1 ELSE NULL END AS n2,
    --
    CASE MOD((ROWNUM-1), 25)   WHEN 0 THEN ROWNUM-1 ELSE NULL END AS n3,
    CASE TRUNC((ROWNUM-1)/400) WHEN 0 THEN ROWNUM-1 ELSE NULL END AS n4,
    --
    CASE MOD((ROWNUM-1), 25)   WHEN 0 THEN ROWNUM-1 ELSE NULL END AS n5,
    CASE TRUNC((ROWNUM-1)/400) WHEN 0 THEN ROWNUM-1 ELSE NULL END AS n6,
    --
    LPAD(ROWNUM, 10, '0') AS small_vc,
    RPAD('x', 220) AS padding
FROM
    all_objects
WHERE
    ROWNUM <= 10000;

create bitmap index t1_i1 on t1(n1)
nologging
pctfree 90
;

create bitmap index t1_i2 on t1(n2)
nologging
pctfree 90
;

create bitmap index t1_i3 on t1(n3)
nologging
pctfree 90
;

create bitmap index t1_i4 on t1(n4)
nologging
pctfree 90
;

create        index t1_i5 on t1(n5)
nologging
pctfree 90
;

create        index t1_i6 on t1(n6)
nologging
pctfree 90
;

begin
    dbms_stats.gather_table_stats(
        user,
        't1',
        cascade => true,
        estimate_percent => null,
        method_opt => 'for all columns size 1'
    );
end;

select    * from    t1 where   n6  = 2;

select    small_vc from    t1 where   n6  = 2;

select    small_vc from    t1 where   n5  = 2;

SELECT    small_vc from    t1 where   n4  = 2;

select    small_vc from    t1 where   n3  = 2;

select
    small_vc
from
    t1
where
    n1  = 2 -- one in 20
and n3  = 2 -- one in 25
;


select
    small_vc
from
    t1
where
    n2  = 2 -- one in 20
and n4  = 2 -- one in 25
;


DROP TABLE t1;

CREATE TABLE t1 AS
WITH generator AS (
    SELECT
        --+ materialize
        rownum id
    FROM
        all_objects
    WHERE
        rownum <= 1000000
)
SELECT
    /*+ ordered use_nl(v2) */
    CASE WHEN MOD(rownum-1, 1000) = 0 THEN rownum - 1 ELSE NULL END AS n1,
    CASE WHEN MOD(rownum-1, 1000) = 0 THEN rownum - 1 ELSE NULL END AS n2,
    LPAD(rownum-1, 10, '0') AS small_vc
FROM
    generator v1
    CROSS JOIN generator v2;



create bitmap index t1_i1 on t1(n1);
create bitmap index t1_i2 on t1(n2);

begin
   dbms_stats.gather_table_stats(
           user,
           't1',
           cascade => true,
           estimate_percent => null,
           method_opt => 'for all columns size 1'
   );
end;


select
    small_vc
from
    t1
where
    n1 = 50000
;

select
    small_vc
from
    t1
where
    n1 = 50000
or  n2 = 50000
;


select
    small_vc
from
    t1
where
    n1 = 50000
or  (n2 = 50000 and n2 is not null)
;



create bitmap index fct_dim_name on fact_table(dim.dim_name)
from
    dim_table   dim,
    fact_table  fct
where
    dim.id = fct.dim_id
;

create bitmap index fct_dim_par on fact_table(dim.par_name)
from
    dim_table   dim,
    fact_table  fct
where
    dim.id = fct.dim_id
;
