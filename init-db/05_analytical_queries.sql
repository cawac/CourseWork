SELECT
    DATE(timestamp) AS date,
    COUNT(DISTINCT user_id) AS dau
FROM user_actions
WHERE timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY date DESC;

SELECT COUNT(DISTINCT user_id) AS wau
FROM user_actions
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days';

SELECT COUNT(DISTINCT user_id) AS mau
FROM user_actions
WHERE timestamp >= CURRENT_DATE - INTERVAL '30 days';

SELECT
    u.tg_id,
    g.name AS group_name,
    COUNT(*) AS action_count,
    COUNT(DISTINCT DATE(ua.timestamp)) AS active_days
FROM user_actions ua
JOIN users u ON ua.user_id = u.id
LEFT JOIN groups g ON u.group_id = g.id
WHERE ua.timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.tg_id, g.name
ORDER BY action_count DESC
LIMIT 10;

SELECT
    command_name,
    COUNT(*) AS usage_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM user_actions
WHERE action_type = 'COMMAND'
    AND timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY command_name
ORDER BY usage_count DESC;

SELECT
    EXTRACT(HOUR FROM timestamp) AS hour,
    command_name,
    COUNT(*) AS count
FROM user_actions
WHERE action_type = 'COMMAND'
    AND timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY EXTRACT(HOUR FROM timestamp), command_name
ORDER BY hour, count DESC;

SELECT
    g.name AS group_name,
    COUNT(DISTINCT l.id) AS total_lessons,
    COUNT(DISTINCT CASE WHEN l.lesson_type = 'LECTURE' THEN l.id END) AS lectures,
    COUNT(DISTINCT CASE WHEN l.lesson_type = 'PRACTICE' THEN l.id END) AS practices,
    COUNT(DISTINCT CASE WHEN l.lesson_type = 'LAB' THEN l.id END) AS labs
FROM groups g
JOIN group_lesson gl ON g.id = gl.group_id
JOIN lessons l ON gl.lesson_id = l.id
WHERE l.lesson_date >= DATE_TRUNC('week', CURRENT_DATE)
    AND l.lesson_date < DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '7 days'
GROUP BY g.name
ORDER BY total_lessons DESC;

SELECT
    a.name,
    a.building,
    a.floor,
    a.capacity,
    a.type
FROM auditoriums a
WHERE a.id NOT IN (
    SELECT DISTINCT l.auditorium_id
    FROM lessons l
    WHERE l.lesson_date = CURRENT_DATE
        AND l.lesson_number = 3
        AND l.auditorium_id IS NOT NULL
)
ORDER BY a.building, a.floor;

SELECT
    DATE(created_at) AS registration_date,
    COUNT(*) AS new_users
FROM users
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY registration_date DESC;


SELECT
    COALESCE(g.name, 'No Group') AS group_name,
    COUNT(u.id) AS user_count
FROM users u
LEFT JOIN groups g ON u.group_id = g.id
GROUP BY g.name
ORDER BY user_count DESC;
