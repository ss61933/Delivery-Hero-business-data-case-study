WITH cust_total AS (
    SELECT
        COUNT(DISTINCT customer_id) total_cnt
    FROM fct_orders
), cust_tab AS -- exclude acquisitions (customers placing their first order ).
 (
    SELECT
        customer_id
    FROM
        (SELECT customer_id,MIN(EXTRACT(YEAR FROM order_date)) first_order_year
            FROM fct_orders
            WHERE is_canceled = 'FALSE'
            GROUP BY customer_id
        )
    WHERE
        first_order_year <> 2019 --assuming here we need  to exclude customers placing their first order in 2019
), cust_tab1 --  first order with +ve feedback in 2019
 AS (
    SELECT
        o.customer_id, MIN(o.order_id) order_id
    FROM
        fct_orders o,fct_rating r,cust_tab    o1
    WHERE
            EXTRACT(YEAR FROM(o.order_date)) = 2019 AND o.is_canceled = 'FALSE' AND r.rating = 'POSITIVE'
        AND r.order_id = o.order_id
        AND o.customer_id = o1.customer_id
    GROUP BY o.customer_id
)
--select * from cust_tab1;
, cust_tab2 AS ( --Count of customers placing orders within 45 days 
    SELECT
        COUNT(customer_id) cnt
    FROM
        (SELECT o.customer_id,o.order_id,
                LEAD(o.order_date) OVER(PARTITION BY o.customer_id ORDER BY o.order_id)- o.order_date number_of_days, --no of days between current and next order
                RANK() OVER(PARTITION BY o.customer_id ORDER BY o.order_id )rnk
            FROM fct_orders o,cust_tab1   t
            WHERE o.customer_id = t.customer_id
                AND o.order_id >= t.order_id --to get all orders after first order with positive feedback 
                AND EXTRACT(YEAR FROM(o.order_date)) = 2019
                AND o.is_canceled = 'FALSE'
            ORDER BY o.customer_id,o.order_id
        )
    WHERE
            rnk = 1 AND number_of_days <= 45 --Getting customer id for which order is placed within 45 days 
    GROUP BY customer_id
)
SELECT
    round(cnt / total_cnt, 2) * 100 || '%' positive_feedback_45d_return
FROM
    cust_total,cust_tab2;