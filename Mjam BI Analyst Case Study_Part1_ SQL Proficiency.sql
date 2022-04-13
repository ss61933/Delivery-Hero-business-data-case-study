/*Question 1
 What is the percentage of customers who used the same payment method for their first and second orders? 
 Show the results split by the payment method they used for their first order. 
 Also, please consider only the customers who placed their first order since the beginning of 2018 and who have placed at least 2 orders so far. 
 Output columns: payment_method (VARCHAR), pct_2order (FLOAT)

*/
WITH tab1 AS --Get the customer with at least 2 orders(not cancelled) since start of 2018 
 (
    SELECT
        customer_id
    FROM
        fct_orders
    WHERE
            trunc(order_date) >= to_date('01-JAN-2018') -- orders placed since the begining of 2018
        AND is_canceled = 'FALSE' --orders that are not cancelled 
    GROUP BY
        customer_id
    HAVING
        COUNT(order_id) > 1 -- atleast 2 orders 
)
--select * from tab1;
, tab2 AS ( -- Rank customer orders in asc order and find out first and next payment id 
    SELECT
        customer_id,
        order_id,
        payment_id,
        order_date,
        RANK() OVER(PARTITION BY customer_id ORDER BY order_id) rn,
        LEAD(payment_id, 1) OVER(PARTITION BY customer_id ORDER BY order_id) next_payment_id -- Get next payment id 
    FROM
        fct_orders
    WHERE
        customer_id IN (SELECT customer_id FROM tab1)
        AND is_canceled='FALSE'
       )
SELECT
    payment_method,
    round((COUNT(customer_id) /(SELECT  COUNT(DISTINCT customer_id) FROM fct_orders)), 2) * 100 || '%' pct_2order
FROM
    dim_payment,
    tab2 -- adding left join here as we need to display count of customers for each payment method type  
WHERE
        tab2.payment_id (+) = dim_payment.payment_id -- left join with payment method 
        and rn (+) = 1 AND tab2.payment_id (+) = next_payment_id (+)-- get the customer id with same payment method for first and second order
GROUP BY
    payment_method;
	
	
	/*--SampleOuput:
	PAYMENT_METHOD	PCT_2ORDER
	apple_pay    	1%
	cash         	2%
	bank_transfer	0%
	creditcard   	3%
	paypal       	0%
	*/
----------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------
/*Question2
 In 2018, which customer spent the most money in the fifth largest city Mjam operates in 
 (defined as total number of orders per city in 2018)? 
 Output columns: customer_id (INT), city (VARCHAR), total_paid_eur (FLOAT)
*/



WITH city_tab1 AS --Get 5th largest City bsed on no of orders in 2018
 (
    SELECT
        r.city,
        COUNT(f.order_id),
        RANK() OVER( ORDER BY COUNT(order_id) DESC ) rn --Rank the city based on count of order 
    FROM
        fct_orders1    f,
        dim_restaurant r
    WHERE
            f.restaurant_id = r.restaurant_id
        AND f.is_canceled = 'false'
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
                fct_orders1    f,
                dim_restaurant1 r
            WHERE
                    f.is_canceled = 'false'
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
    AND t1.city = t2.city;
	

	/*Sampleoutput 
	CUSTOMER_ID		CITY		TOTAL_PAID_EUR
	231				innsbruck	127.1
	*/



----------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------
/*Question3
What is the ratio of customers placing an order within 45 days after an order to which they left positive feedback for? 
Use 2019 order data only and exclude acquisitions (customers placing their first order). 
Output columns: positive_feedback_45d_return (FLOAT)
*/

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
	
	/*SampleOutput
	positive_feedback_45d_return
	3%

	*/


----------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------
/*Question4
Since 2017, how many unique monthly customers did each restaurant in "Innsbruck" have per month? 
Output columns: month (DATE or VARCHAR), restaurant_id (INTEGER), customers (INTEGER)

*/

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
) select * from innsbruck_r;
, cust_tab1 AS (
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
            o.is_canceled = 'FALSE'
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



	/*Sample Output 
	MONTH_YEAR	RESTAURANT_ID	CUSTOMERS
	01-JAN-2020		2			1
	01-JAN-2020		9			1
	01-JAN-2020		15			1
	01-FEB-2020		2			1
	01-FEB-2020		9			1
	01-FEB-2020		15			1
	*/

----------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------
/*Question5
 How many customers in 2017 ordered exclusively on Android without using any other platform? 
 Output columns: customers (INTEGER)
*/

SELECT
    COUNT(DISTINCT customer_id) customers
FROM
    (
        SELECT
            f.customer_id,
            COUNT(
                CASE WHEN p.platform_name = 'android' THEN 1
                    ELSE NULL END
            ) android_cnt, --approach 1 
            COUNT(
                CASE WHEN p.platform_name <> 'android' THEN 1
                    ELSE NULL END
            ) non_android_cnt  --apporach 1 
--sum(case when p.platform_name='android' then 1 else -1 end) android_cnts --appraoch 2 
        FROM
            fct_orders1  f,
            dim_platform p
        WHERE
                EXTRACT(YEAR FROM(f.order_date)) = 2017
            AND f.is_canceled = 'FALSE'
            AND f.platform_id = p.platform_id
        GROUP BY
            customer_id
    )
WHERE
    ( android_cnt > 0 AND non_android_cnt = 0 );--approach 1  Check if customer made order only using android 
     --  android_cnts>0;approach 2 

	/*Sample outout 
	CUSTOMERS
	21
	
	*/



----------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------------