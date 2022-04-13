/*Question 1
 What is the percentage of customers who used the same payment method for their first and second orders? Show the results split by the payment method they used for their first order. Also, please consider only the customers who placed their first order since the beginning of 2018 and who have placed at least 2 orders so far. Output columns: payment_method (VARCHAR), pct_2order (FLOAT)
2. In 2018, which customer spent the most money in the fifth largest city Mjam 
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
, tab2 AS ( -- Rank customer orders in asc order and find out current and next payment id 
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
        and rn (+) = 1 AND tab2.payment_id (+) = next_payment_id (+)-- get the customer id with sme payment method for first and second order
GROUP BY
    payment_method;