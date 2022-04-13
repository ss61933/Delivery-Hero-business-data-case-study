--Query1 -Assumption here is to get all unqiue custoemrs for each month irrespective whether he/she has placed any order earlier 
WITH innsbruck_r AS ( --Get all unqiue restaurants  and total count for city innsbruck
    SELECT
        restaurant_id,
        COUNT(restaurant_id)
        OVER() cnt
    FROM
        dim_restaurant
    WHERE
        city = 'innsbruck'
), cust_tab1 AS (
    SELECT DISTINCT
        o.customer_id,
        to_date(to_char((o.order_date), 'mon-yyyy'), 'mon-yyyy')                                   month_year,
        o.restaurant_id,
        COUNT(DISTINCT o.restaurant_id)
        OVER(PARTITION BY o.customer_id, to_date(to_char((o.order_date), 'mon-yyyy'), 'mon-yyyy')) c_cnt --Get distinct restaurant count for each customer for city innsbruck
    FROM
        fct_orders o,
        innsbruck_r r
    WHERE
            o.is_canceled = 'FALSE'
        AND order_date >= TO_DATE('01-01-2017', 'dd-mm-yyyy')
        AND o.restaurant_id = r.restaurant_id
)
SELECT
    month_year,
    restaurant_id,
    COUNT(customer_id) customers
FROM
    cust_tab1
WHERE
    c_cnt = ( SELECT DISTINCT  cnt FROM innsbruck_r    ) --Get all customers who visited all restaurants from city innsbruck
GROUP BY
    month_year,
    restaurant_id
ORDER BY
    month_year,
    restaurant_id;


--Query2 -Assumption here is to get all unqiue custoemrs from each momnth, means if customer A has placed some(1 or more ) order in JAN-2020 and in FEB 2020 he placed order in all 
--restaurants in innsbruck then he will nto be counted as he is not new customer. This customer will be counted in Query 1 
WITH innsbruck_r AS (
    SELECT
        restaurant_id,
        COUNT(restaurant_id)
        OVER() cnt
    FROM
        dim_restaurant
    WHERE
        city = 'innsbruck'
), cust_tab1 AS (
    SELECT DISTINCT
        o.customer_id,
        to_date(to_char((o.order_date), 'mon-yyyy'), 'mon-yyyy')                                   month_year,
        o.restaurant_id,
        COUNT(DISTINCT o.restaurant_id)
        OVER(PARTITION BY o.customer_id, to_date(to_char((o.order_date), 'mon-yyyy'), 'mon-yyyy')) c_cnt
    FROM
        fct_orders o,
        innsbruck_r r
    WHERE
            o.is_canceled = 'false'
        AND o.restaurant_id = r.restaurant_id
        AND order_date >= TO_DATE('01-01-2017', 'dd-mm-yyyy')
        AND to_date(to_char((o.order_date), 'mon-yyyy'), 'mon-yyyy') = (
            SELECT
                to_date(to_char((MIN(o1.order_date)), 'mon-yyyy'), 'mon-yyyy')
            FROM
                fct_orders1 o1
            WHERE
                o1.customer_id = o.customer_id
        ) ---This will give us if this is the first month for customer 
)
SELECT
    month_year,
    restaurant_id,
    COUNT(customer_id) customers
FROM
    cust_tab1
WHERE
    c_cnt = (SELECT DISTINCT cnt FROM innsbruck_r )
GROUP BY
    month_year,
    restaurant_id
ORDER BY
    month_year,
    restaurant_id;