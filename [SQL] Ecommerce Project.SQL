--Query 01: Calculate total visit, pageview, transaction for Jan, Feb and March 2017 (order by month)
SELECT
  FORMAT_DATE("%Y%m", parse_date("%Y%m%d", date)) as month,
  SUM(totals.visits) AS visits,
  SUM(totals.pageviews) AS pageviews,
  SUM(totals.transactions) AS transactions,
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331'
GROUP BY 1
ORDER BY 1;

--Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) (order by total_visit DESC)
SELECT 
  trafficSource.source    AS source
  ,COUNT(totals.visits)   AS total_visits
  ,COUNT(totals.bounces)  AS total_no_of_bounces
  ,100 * COUNT(totals.bounces)/COUNT(totals.visits) AS bounce_rate 
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0701' AND '0731'
GROUP BY trafficSource.source
ORDER BY total_visits DESC;

--Query 3: Revenue by traffic source by week, by month in June 2017
WITH 
month_data as(
  SELECT
    "Month" as time_type,
    FORMAT_DATE("%Y%m", parse_date("%Y%m%d", date)) as month,
    trafficSource.source AS source,
    SUM(p.productRevenue)/1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) hits,
    UNNEST(product) p
  WHERE p.productRevenue is not null
  GROUP BY 1,2,3
  ORDER BY revenue DESC
),

week_data as(
  SELECT
    "Week" as time_type,
    format_date("%Y%W", parse_date("%Y%m%d", date)) as week,
    trafficSource.source AS source,
    SUM(p.productRevenue)/1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) hits,
    UNNEST(product) p
  WHERE p.productRevenue is not null
  GROUP BY 1,2,3
  ORDER BY revenue DESC
)

SELECT* FROM month_data
UNION ALL 
SELECT* FROM week_data;

--Query 04: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.
WITH
purchaser_data as(
  SELECT
      FORMAT_DATE("%Y%m",parse_date("%Y%m%d",date)) AS month,
      (SUM(totals.pageviews)/COUNT(distinct fullvisitorid)) AS avg_pageviews_purchase,
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
    ,UNNEST(hits) hits
    ,UNNEST(product) product
  WHERE _table_suffix between '0601' AND '0731'
  AND totals.transactions >= 1
  AND product.productRevenue IS NOT NULL
  GROUP BY month
),

non_purchaser_data AS(
  SELECT
      FORMAT_DATE("%Y%m",parse_date("%Y%m%d",date)) as month,
      SUM(totals.pageviews)/count(distinct fullvisitorid) as avg_pageviews_non_purchase,
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
    ,UNNEST(hits) hits
    ,UNNEST(product) product
  WHERE _table_suffix between '0601' AND '0731'
  AND totals.transactions is null
  AND product.productRevenue is null
  GROUP BY month
)

SELECT
    pd.*,
    avg_pageviews_non_purchase
FROM purchaser_data pd
FULL JOIN non_purchaser_data USING(month)
ORDER BY pd.month;

--Query 05: Average number of transactions per user that made a purchase in July 2017
SELECT  
    FORMAT_DATE("%Y%m",parse_date("%Y%m%d",date)) AS month
    ,SUM(totals.transactions)/COUNT(DISTINCT fullVisitorId ) AS Avg_total_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` 
,UNNEST(hits)    AS h
,UNNEST(product) AS p
WHERE p.productRevenue IS NOT NULL
  AND _table_suffix between '0701' and '0731'
  AND totals.transactions >=1 
GROUP BY month;

--Query 06: Average amount of money spent per session. Only include purchaser data in July 2017
SELECT
    FORMAT_DATE("%Y%m",parse_date("%Y%m%d",date)) as month,
    ((SUM(product.productRevenue)/SUM(totals.visits))/POWER(10,6)) as avg_revenue_by_user_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
  ,UNNEST(hits) hits
  ,UNNEST(product) product
WHERE product.productRevenue IS NOT NULL
GROUP BY month;

--Query 07: Other products purchased by customers who purchased product “YouTube Men’s Vintage Henley” in July 2017. Output should show product name and the quantity was ordered.
WITH buyer_list AS(
    SELECT
        DISTINCT fullVisitorId
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
    , UNNEST(hits) AS hits
    , UNNEST(hits.product) as product
    WHERE product.v2ProductName = "YouTube Men's Vintage Henley"
    AND totals.transactions>=1
    AND product.productRevenue is not null
)

SELECT
  product.v2ProductName AS other_purchased_products,
  SUM(product.productQuantity) AS quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
, UNNEST(hits) AS hits
, UNNEST(hits.product) as product
JOIN buyer_list using(fullVisitorId)
WHERE product.v2ProductName != "YouTube Men's Vintage Henley"
 and product.productRevenue IS NOT NULL
GROUP BY other_purchased_products
ORDER BY quantity DESC;

--Query 08: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.
WITH product_data AS(
SELECT
    FORMAT_DATE('%Y%m', parse_date('%Y%m%d',date)) AS month,
    COUNT(CASE WHEN eCommerceAction.action_type = '2' THEN product.v2ProductName END) as num_product_view,
    COUNT(CASE WHEN eCommerceAction.action_type = '3' THEN product.v2ProductName END) as num_add_to_cart,
    COUNT(CASE WHEN eCommerceAction.action_type = '6' AND product.productRevenue is not null THEN product.v2ProductName END) AS num_purchase
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
,UNNEST(hits) as hits
,UNNEST (hits.product) as product
WHERE_table_suffix between '20170101' AND '20170331'
AND eCommerceAction.action_type in ('2','3','6')
GROUP BY month
ORDER BY month
)

SELECT
    *
   ,ROUND(num_add_to_cart/num_product_view * 100, 2) AS add_to_cart_rate
   ,ROUND(num_purchase/num_product_view * 100, 2) as purchase_rate
FROM product_data;