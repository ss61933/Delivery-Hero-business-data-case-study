WITH city_tab1 AS --Get 5th largest City bsed on no of orders in 2018
 (
    SELECT
        r.city,
        COUNT(f.order_id),
        RANK() OVER( ORDER BY COUNT(order_id) DESC ) rn --Rank the city based on count of order 
    FROM
        fct_orders    f,
        dim_restaurant r
    WHERE
            f.restaurant_id = r.restaurant_id
        AND f.is_canceled = 'FALSE'
        AND EXTRACT(YEAR FROM(order_date)) = 2018
    GROUP BY
        r.city
)
--select * from city_tab1;
, customer_tab2 AS --get citiwise customer with their total spent 
 (
    SELECT
        *
    FROM
        (
            SELECT
                r.city,
                f.customer_id,
                SUM(f.paid_amount) total_paid_eur,
                ROW_NUMBER() OVER(PARTITION BY city ORDER BY SUM(f.paid_amount) DESC) rn -- rank the customer within city based on total spent 
            FROM
                fct_orders    f,
                dim_restaurant r
            WHERE
                    f.is_canceled = 'FALSE'
                AND f.restaurant_id = r.restaurant_id
                AND EXTRACT(YEAR FROM(order_date)) = 2018
            GROUP BY
                r.city,
                f.customer_id
            ORDER BY
                city,
                total_paid_eur DESC
        )
    WHERE
        rn = 1
)
--select * from customer_tab2;
SELECT
    t2.customer_id,
    t1.city,
    t2.total_paid_eur
FROM
    city_tab1     t1,
    customer_tab2 t2
WHERE
        t1.rn = 1 --select customer with highest amount spent 
    AND t2.rn = 5 --select City with 5th rank and customer within that city with first rank;
    AND t1.city = t2.city