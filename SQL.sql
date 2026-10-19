CREATE DATABASE commercepath_db;

USE commercepath_db;

-- Create Tables --
-- Create Events Table --

CREATE TABLE events (
    session_id VARCHAR(50),
    customer_id VARCHAR(50),
    event_time DATETIME,
    event_type VARCHAR(50),
    traffic_source VARCHAR(50),
    device_type VARCHAR(50),
    product_id VARCHAR(50),
    product_name VARCHAR(255),
    category VARCHAR(100),
    order_id VARCHAR(50),
    region VARCHAR(100),
    event_date DATE,
    event_month VARCHAR(20)
);

-- Create Orders Table --

CREATE TABLE orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_date DATE,
    traffic_source VARCHAR(50),
    device_type VARCHAR(50),
    region VARCHAR(100),
    product_id VARCHAR(50),
    product_name VARCHAR(255),
    category VARCHAR(100),
    base_price DECIMAL(12,2),
    quantity INT,
    unit_price DECIMAL(12,2),
    discount DECIMAL(12,2),
    gross_revenue DECIMAL(12,2),
    net_revenue DECIMAL(12,2),
    return_flag VARCHAR(10),
    order_month VARCHAR(20)
);

SELECT * FROM events LIMIT 10;

SELECT * FROM orders LIMIT 10;

SELECT COUNT(*) AS total_events FROM events;

SELECT COUNT(*) AS total_orders FROM orders;

-- 1. Funnel-stage counts by month. --

SELECT
    event_month,
    SUM(CASE WHEN event_type = 'view' THEN 1 ELSE 2 END) AS product_views,
    SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 02 END) AS add_to_cart,
    SUM(CASE WHEN event_type = 'checkout' THEN 1 ELSE 4 END) AS checkouts,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 7 END) AS purchases
FROM events
GROUP BY event_month
ORDER BY event_month;

DESCRIBE events;

SELECT * FROM events LIMIT 5;

-- 2. Conversion by traffic source. --

SELECT
    traffic_source,
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(DISTINCT CASE
        WHEN event_type = 'purchase'
        THEN session_id
    END) AS purchase_sessions,
    ROUND(
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN session_id END)
        / COUNT(DISTINCT session_id) * 100,
        2
    ) AS conversion_rate_percent
FROM events
GROUP BY traffic_source
ORDER BY conversion_rate_percent DESC;


-- 3. Device-level conversion comparison. --

SELECT
    device_type,
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(DISTINCT CASE
        WHEN event_type = 'purchase'
        THEN session_id
    END) AS purchase_sessions,
    ROUND(
        COUNT(DISTINCT CASE
            WHEN event_type = 'purchase'
            THEN session_id
        END) * 100.0
        / COUNT(DISTINCT session_id),
        2
    ) AS conversion_rate_percent
FROM events
GROUP BY device_type
ORDER BY conversion_rate_percent DESC;

-- 4. Category view-to-purchase conversion. --

SELECT
    category,
    COUNT(DISTINCT CASE
        WHEN event_type = 'view'
        THEN session_id
    END) AS view_sessions,

    COUNT(DISTINCT CASE
        WHEN event_type = 'purchase'
        THEN session_id
    END) AS purchase_sessions,

    ROUND(
        COUNT(DISTINCT CASE
            WHEN event_type = 'purchase'
            THEN session_id
        END) * 100.0
        /
        NULLIF(
            COUNT(DISTINCT CASE
                WHEN event_type = 'view'
                THEN session_id
            END),
            0
        ),
        2
    ) AS view_to_purchase_conversion_percent

FROM events
GROUP BY category
ORDER BY view_to_purchase_conversion_percent DESC;

-- 5. Average order value by channel.--

SELECT
    traffic_source,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(
        SUM(net_revenue) / COUNT(DISTINCT order_id),
        2
    ) AS average_order_value
FROM orders
GROUP BY traffic_source
ORDER BY average_order_value DESC;

-- 6. Repeat versus one-time customers.--

SELECT
    customer_type,
    COUNT(*) AS total_customers
FROM (
    SELECT
        customer_id,
        CASE
            WHEN COUNT(DISTINCT order_id) > 1
            THEN 'Repeat Customer'
            ELSE 'One-Time Customer'
        END AS customer_type
    FROM orders
    GROUP BY customer_id
) AS customer_summary
GROUP BY customer_type;

-- 7. Top products by revenue and returns.--

SELECT
    product_name,
    category,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    SUM(CASE WHEN return_flag = 'Yes' THEN 1 ELSE 0 END) AS returned_items,
    COUNT(*) AS total_order_lines,
    ROUND(
        SUM(CASE WHEN return_flag = 'Yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS return_rate_percent
FROM orders
GROUP BY product_name, category
ORDER BY total_revenue DESC
LIMIT 10;

-- 8. Cart abandonment by device.--

SELECT
    device_type,

    COUNT(DISTINCT CASE
        WHEN event_type = 'add_to_cart'
        THEN session_id
    END) AS add_to_cart_sessions,

    COUNT(DISTINCT CASE
        WHEN event_type = 'purchase'
        THEN session_id
    END) AS purchase_sessions,

    ROUND(
        (
            COUNT(DISTINCT CASE
                WHEN event_type = 'add_to_cart'
                THEN session_id
            END)
            -
            COUNT(DISTINCT CASE
                WHEN event_type = 'purchase'
                THEN session_id
            END)
        ) * 100.0
        /
        NULLIF(
            COUNT(DISTINCT CASE
                WHEN event_type = 'add_to_cart'
                THEN session_id
            END),
            0
        ),
        2
    ) AS cart_abandonment_percent

FROM events
GROUP BY device_type;

-- 9. Customer ranking by lifetime revenue.--

SELECT
    customer_id,
    ROUND(SUM(net_revenue), 2) AS lifetime_revenue,
    RANK() OVER (
        ORDER BY SUM(net_revenue) DESC
    ) AS customer_rank
FROM orders
GROUP BY customer_id
ORDER BY customer_rank;

-- 10. Monthly running revenue and growth.--

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        SUM(net_revenue) AS monthly_revenue
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)

SELECT
    month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,

    ROUND(
        SUM(monthly_revenue) OVER (
            ORDER BY month
        ),
        2
    ) AS running_revenue,

    ROUND(
        (
            monthly_revenue
            - LAG(monthly_revenue) OVER (ORDER BY month)
        )
        /
        NULLIF(
            LAG(monthly_revenue) OVER (ORDER BY month),
            0
        ) * 100,
        2
    ) AS monthly_growth_percent

FROM monthly_revenue
ORDER BY month;








