/* 
Query 1: 
 The query for the funnel of MetroCar users and rides, segmented by all age groups, platforms, and download timestamps. I utilized this query to address business questions on Tableau, extracting valuable insights.
 */

 WITH temp_table AS (
    SELECT
        ad.platform,
        COALESCE(s.age_range, 'Unknown') AS age_ranges,
        DATE(ad.download_ts) AS download_date,
        COUNT(DISTINCT ad.app_download_key) AS app_downloads,
        COUNT(DISTINCT s.user_id) AS total_users_signed_up,
        COUNT(DISTINCT rr.user_id) AS total_users_ride_requested,
        COUNT(DISTINCT CASE WHEN rr.accept_ts IS NOT NULL THEN rr.user_id END) AS total_users_accepted_rides,
        COUNT(DISTINCT CASE WHEN rr.dropoff_ts IS NOT NULL THEN rr.user_id END) AS total_users_ride_completed,
        COUNT(DISTINCT CASE WHEN tr.charge_status = 'Approved' THEN rr.user_id END) AS total_user_payment,
        COUNT(DISTINCT rv.user_id) AS total_users_reviews,
        COUNT(DISTINCT rr.ride_id) AS total_ride_requested,
        COUNT(DISTINCT CASE WHEN rr.accept_ts IS NOT NULL THEN rr.ride_id END) AS total_ride_accepted,
        COUNT(DISTINCT CASE WHEN rr.dropoff_ts IS NOT NULL THEN rr.ride_id END) AS total_ride_completed,
        COUNT(DISTINCT CASE WHEN tr.charge_status = 'Approved' THEN rr.ride_id END) AS total_ride_payment,
        COUNT(DISTINCT CASE WHEN tr.charge_status = 'Approved' THEN rv.ride_id END) AS total_ride_reviews
    FROM
        app_downloads ad
    LEFT JOIN
        signups s ON ad.app_download_key = s.session_id
    LEFT JOIN
        ride_requests rr ON s.user_id = rr.user_id
    LEFT JOIN
        transactions tr ON tr.ride_id = rr.ride_id
    LEFT JOIN
        reviews rv ON rv.ride_id = rr.ride_id
    GROUP BY
        ad.platform, age_ranges, download_date
),
steps AS (
    SELECT
        1 AS funnel_step,
        'app_downloads' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        app_downloads AS user_count,
        0 AS ride_count
    FROM
        temp_table
    UNION ALL
    SELECT
        2 AS funnel_step,
        'signups' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        total_users_signed_up AS user_count,
        0 AS ride_count
    FROM
        temp_table
    UNION ALL
    SELECT
        3 AS funnel_step,
        'ride_requested' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        total_users_ride_requested AS user_count,
        total_ride_requested AS ride_count
    FROM
        temp_table
    UNION ALL
    SELECT
        4 AS funnel_step,
        'ride_accepted' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        total_users_accepted_rides AS user_count,
        total_ride_accepted AS ride_count
    FROM
        temp_table
    UNION ALL
    SELECT
        5 AS funnel_step,
        'ride_completed' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        total_users_ride_completed AS user_count,
        total_ride_completed AS ride_count
    FROM
        temp_table
    UNION ALL
    SELECT
        6 AS funnel_step,
        'payment' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        total_user_payment AS user_count,
        total_ride_payment AS ride_count
    FROM
        temp_table
    UNION ALL
    SELECT
        7 AS funnel_step,
        'reviews' AS funnel_name,
        platform,
        download_date,
        age_ranges,
        total_users_reviews AS user_count,
        total_ride_reviews AS ride_count
    FROM
        temp_table
)
SELECT
    funnel_step,
    funnel_name,
    platform,
    age_ranges,
    download_date,
    SUM(user_count) AS total_users,
    SUM(ride_count) AS total_rides
FROM
    steps
GROUP BY
    funnel_step, funnel_name, platform, age_ranges, download_date
ORDER BY
    funnel_step, funnel_name, platform, age_ranges, download_date;



/* 
Query 2: 

*  I employed this query to join in Tableau with my initial query, aiming to address a specific business question regarding surge pricing during peak hours.
 */

 SELECT DISTINCT age_range as age_ranges,
       EXTRACT(HOUR FROM request_ts) AS request_hour,
       COUNT(DISTINCT ride_requests.ride_id) AS rides_per_hour
FROM ride_requests
JOIN signups ON signups.user_id = ride_requests.user_id
GROUP BY 1, 2
ORDER BY 1, 2 ;


/* 
Query 3: 


This query is solely for conducting funnel analysis of MetroCar users, focusing on the variance from previous values and the percentage change from previous values. It has not been utilized elsewhere.
*/

WITH app_downloaded AS (
    SELECT COUNT(*) AS total_users_downloaded_app
    FROM app_downloads
),
payment AS(
  SELECT COUNT(DISTINCT transactions.ride_id) AS total,
 	COUNT(DISTINCT ride_requests.user_id) AS users
FROM transactions JOIN ride_requests ON ride_requests.ride_id = transactions.ride_id
WHERE charge_status = 'Approved'
),  
totals AS (
    SELECT
        COUNT(DISTINCT signups.user_id) AS total_users_signed_up,
        COUNT(DISTINCT ride_requests.user_id) AS total_users_ride_requested,
        COUNT(DISTINCT CASE WHEN ride_requests.accept_ts IS NOT NULL THEN ride_requests.user_id END) AS total_accepted_rides,
        COUNT(DISTINCT CASE WHEN ride_requests.dropoff_ts IS NOT NULL THEN ride_requests.user_id END) AS total_users_ride_completed,
        
        COUNT(DISTINCT reviews.user_id) AS total_reviews
    FROM signups 
    LEFT JOIN ride_requests ON signups.user_id = ride_requests.user_id
    LEFT JOIN reviews ON reviews.user_id = ride_requests.user_id
),
funnel_stages AS (
    SELECT
        1 AS funnel_step,
        'app_downloads' AS funnel_name,
        total_users_downloaded_app AS user_count
    FROM app_downloaded
    UNION
    SELECT
        2 AS funnel_step,
        'signups' AS funnel_name,
        total_users_signed_up AS user_count
    FROM totals
    UNION
    SELECT
        3 AS funnel_step,
        'ride_requested' AS funnel_name,
        total_users_ride_requested AS user_count
    FROM totals
    UNION
    SELECT
        4 AS funnel_step,
        'ride_accepted' AS funnel_name,
        total_accepted_rides AS user_count
    FROM totals
    UNION
    SELECT
        5 AS funnel_step,
        'ride_completed' AS funnel_name,
        total_users_ride_completed AS user_count
    FROM totals
    UNION
    SELECT
        6 AS funnel_step,
        'payment' AS funnel_name,
        users AS user_count
    FROM payment
    UNION
    SELECT
        7 AS funnel_step,
        'reviews' AS funnel_name,
        total_reviews AS user_count
    FROM totals
  
)
SELECT *,
			LAG(user_count) OVER() - user_count AS diff_from_previous_value,
    	user_count::FLOAT / LAG(user_count) OVER (ORDER BY funnel_step) AS percent_of_previous
FROM funnel_stages
ORDER BY funnel_step;


