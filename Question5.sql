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
                EXTRACT(YEAR FROM(f.order_date)) = 2020
            AND f.is_canceled = 'FALSE'
            AND f.platform_id = p.platform_id
        GROUP BY
            customer_id
    )
WHERE
    ( android_cnt > 0 AND non_android_cnt = 0 );--approach 1  Check if customer made order only using android 
     --  android_cnts>0;approach 2 