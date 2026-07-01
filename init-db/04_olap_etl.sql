INSERT INTO dim_date (date_key, full_date, day_of_week, day_name, day_of_month, day_of_year, week_of_year, month, month_name, quarter, year, is_weekend)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER AS date_key,
    d AS full_date,
    EXTRACT(ISODOW FROM d)::INTEGER AS day_of_week,
    TO_CHAR(d, 'Day') AS day_name,
    EXTRACT(DAY FROM d)::INTEGER AS day_of_month,
    EXTRACT(DOY FROM d)::INTEGER AS day_of_year,
    EXTRACT(WEEK FROM d)::INTEGER AS week_of_year,
    EXTRACT(MONTH FROM d)::INTEGER AS month,
    TO_CHAR(d, 'Month') AS month_name,
    EXTRACT(QUARTER FROM d)::INTEGER AS quarter,
    EXTRACT(YEAR FROM d)::INTEGER AS year,
    EXTRACT(ISODOW FROM d) IN (6, 7) AS is_weekend
FROM generate_series('2026-05-01'::DATE, '2026-09-30'::DATE, '1 day'::INTERVAL) AS d
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO dim_group (group_id, group_name, enrollment_year, current_semester, valid_from, valid_to, is_current)
SELECT
    g.id,
    g.name,
    2000 + SUBSTRING(g.name FROM 1 FOR 2)::INTEGER AS enrollment_year,
    (EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER - (2000 + SUBSTRING(g.name FROM 1 FOR 2)::INTEGER)) * 2 +
    CASE
        WHEN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 9 AND 12 THEN 1
        ELSE 0
    END AS current_semester,
    CURRENT_DATE AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current
FROM groups g
ON CONFLICT DO NOTHING;


INSERT INTO dim_subject (subject_id, subject_name)
SELECT
    s.id,
    s.name
FROM subjects s
ON CONFLICT (subject_name) DO NOTHING;

INSERT INTO dim_auditorium (auditorium_id, auditorium_name, auditorium_number, building, floor, capacity, auditorium_type)
SELECT
    a.id,
    a.name,
    a.auditorium_number,
    a.building,
    a.floor,
    a.capacity,
    a.type
FROM auditoriums a
ON CONFLICT DO NOTHING;


INSERT INTO dim_lesson_time (lesson_number, start_time, end_time)
SELECT
    lt.lesson_number,
    lt.start_time,
    lt.end_time
FROM lesson_time lt
ON CONFLICT (lesson_number) DO NOTHING;

INSERT INTO dim_user (user_id, tg_id, group_key, is_admin, valid_from, valid_to, is_current)
SELECT
    u.id,
    u.tg_id,
    dg.group_key,
    u.is_admin,
    DATE(u.created_at) AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current
FROM users u
LEFT JOIN groups g ON u.group_id = g.id
LEFT JOIN dim_group dg ON g.id = dg.group_id
ON CONFLICT DO NOTHING;


INSERT INTO fact_lessons (date_key, subject_key, auditorium_key, lesson_time_key, lesson_type, total_groups, total_students, is_online)
SELECT
    TO_CHAR(l.lesson_date, 'YYYYMMDD')::INTEGER AS date_key,
    ds.subject_key,
    da.auditorium_key,
    dlt.lesson_time_key,
    l.lesson_type::TEXT,
    COUNT(DISTINCT gl.group_id) AS total_groups,
    COUNT(DISTINCT u.id) AS total_students,
    (l.auditorium_id IS NULL) AS is_online
FROM lessons l
JOIN dim_subject ds ON l.subject_name = ds.subject_name
LEFT JOIN auditoriums a ON l.auditorium_id = a.id
LEFT JOIN dim_auditorium da ON a.id = da.auditorium_id
JOIN dim_lesson_time dlt ON l.lesson_number = dlt.lesson_number
LEFT JOIN group_lesson gl ON l.id = gl.lesson_id
LEFT JOIN users u ON gl.group_id = u.group_id
GROUP BY l.lesson_date, ds.subject_key, da.auditorium_key, dlt.lesson_time_key, l.lesson_type, l.auditorium_id;

INSERT INTO bridge_group_lesson (lesson_key, group_key)
SELECT DISTINCT
    fl.lesson_key,
    dg.group_key
FROM lessons l
JOIN group_lesson gl ON l.id = gl.lesson_id
JOIN dim_group dg ON gl.group_id = dg.group_id
JOIN dim_subject ds ON l.subject_name = ds.subject_name
LEFT JOIN auditoriums a ON l.auditorium_id = a.id
LEFT JOIN dim_auditorium da ON a.id = da.auditorium_id
JOIN dim_lesson_time dlt ON l.lesson_number = dlt.lesson_number
JOIN fact_lessons fl ON
    fl.date_key = TO_CHAR(l.lesson_date, 'YYYYMMDD')::INTEGER
    AND fl.subject_key = ds.subject_key
    AND fl.lesson_time_key = dlt.lesson_time_key
    AND fl.lesson_type = l.lesson_type::TEXT
    AND fl.auditorium_key IS NOT DISTINCT FROM da.auditorium_key
ON CONFLICT (lesson_key, group_key) DO NOTHING;

INSERT INTO fact_user_actions (date_key, user_key, group_key, action_type, total_actions, total_commands, total_api_calls, unique_commands_used, session_duration_minutes)
SELECT
    TO_CHAR(DATE(ua.timestamp), 'YYYYMMDD')::INTEGER AS date_key,
    du.user_key,
    du.group_key,
    ua.action_type,
    COUNT(*) AS total_actions,
    COUNT(CASE WHEN ua.action_type = 'COMMAND' THEN 1 END) AS total_commands,
    COUNT(CASE WHEN ua.action_type = 'API_CALL' THEN 1 END) AS total_api_calls,
    COUNT(DISTINCT CASE WHEN ua.action_type = 'COMMAND' THEN ua.command_name END) AS unique_commands_used,
    EXTRACT(EPOCH FROM (MAX(ua.timestamp) - MIN(ua.timestamp))) / 60 AS session_duration_minutes
FROM user_actions ua
JOIN users u ON ua.user_id = u.id
JOIN dim_user du ON u.id = du.user_id AND du.is_current = TRUE
GROUP BY DATE(ua.timestamp), du.user_key, du.group_key, ua.action_type;

INSERT INTO agg_weekly_group_metrics (week_key, group_key, total_lessons, total_lectures, total_practices, total_labs, total_seminars, unique_subjects, unique_auditoriums, avg_students_per_lesson, active_users, total_user_actions)
SELECT
    TO_CHAR(DATE_TRUNC('week', dd.full_date), 'YYYYMMDD')::INTEGER AS week_key,
    bgl.group_key,
    COUNT(DISTINCT fl.lesson_key) AS total_lessons,
    COUNT(DISTINCT CASE WHEN fl.lesson_type = 'LECTURE' THEN fl.lesson_key END) AS total_lectures,
    COUNT(DISTINCT CASE WHEN fl.lesson_type = 'PRACTICE' THEN fl.lesson_key END) AS total_practices,
    COUNT(DISTINCT CASE WHEN fl.lesson_type = 'LAB' THEN fl.lesson_key END) AS total_labs,
    COUNT(DISTINCT CASE WHEN fl.lesson_type = 'SEMINAR' THEN fl.lesson_key END) AS total_seminars,
    COUNT(DISTINCT fl.subject_key) AS unique_subjects,
    COUNT(DISTINCT fl.auditorium_key) AS unique_auditoriums,
    ROUND(AVG(fl.total_students), 2) AS avg_students_per_lesson,
    COUNT(DISTINCT fua.user_key) AS active_users,
    COALESCE(SUM(fua.total_actions), 0) AS total_user_actions
FROM bridge_group_lesson bgl
JOIN fact_lessons fl ON bgl.lesson_key = fl.lesson_key
JOIN dim_date dd ON fl.date_key = dd.date_key
LEFT JOIN dim_user du ON bgl.group_key = du.group_key AND du.is_current = TRUE
LEFT JOIN fact_user_actions fua ON du.user_key = fua.user_key AND fua.date_key BETWEEN TO_CHAR(DATE_TRUNC('week', dd.full_date), 'YYYYMMDD')::INTEGER AND TO_CHAR(DATE_TRUNC('week', dd.full_date) + INTERVAL '6 days', 'YYYYMMDD')::INTEGER
GROUP BY DATE_TRUNC('week', dd.full_date), bgl.group_key;

INSERT INTO agg_monthly_subject_metrics (month_key, subject_key, total_lessons, total_groups, total_students, unique_auditoriums)
SELECT
    TO_CHAR(DATE_TRUNC('month', dd.full_date), 'YYYYMMDD')::INTEGER AS month_key,
    fl.subject_key,
    COUNT(DISTINCT fl.lesson_key) AS total_lessons,
    COUNT(DISTINCT bgl.group_key) AS total_groups,
    SUM(fl.total_students) AS total_students,
    COUNT(DISTINCT fl.auditorium_key) AS unique_auditoriums
FROM fact_lessons fl
JOIN dim_date dd ON fl.date_key = dd.date_key
LEFT JOIN bridge_group_lesson bgl ON fl.lesson_key = bgl.lesson_key
LEFT JOIN dim_auditorium da ON fl.auditorium_key = da.auditorium_key
GROUP BY DATE_TRUNC('month', dd.full_date), fl.subject_key;

CREATE OR REPLACE FUNCTION update_dim_user_scd(
    p_user_id INTEGER,
    p_new_group_id INTEGER,
    p_change_date DATE
)
RETURNS void AS $$
DECLARE
    v_old_group_key INTEGER;
    v_new_group_key INTEGER;
    v_current_user_key INTEGER;
BEGIN
    SELECT user_key, group_key INTO v_current_user_key, v_old_group_key
    FROM dim_user
    WHERE user_id = p_user_id AND is_current = TRUE;

    SELECT group_key INTO v_new_group_key
    FROM dim_group
    WHERE group_id = p_new_group_id;

    IF v_old_group_key IS DISTINCT FROM v_new_group_key THEN
        UPDATE dim_user
        SET valid_to = p_change_date - INTERVAL '1 day',
            is_current = FALSE
        WHERE user_key = v_current_user_key;

        INSERT INTO dim_user (user_id, tg_id, group_key, is_admin, valid_from, valid_to, is_current)
        SELECT
            user_id,
            tg_id,
            v_new_group_key,
            is_admin,
            p_change_date,
            NULL,
            TRUE
        FROM dim_user
        WHERE user_key = v_current_user_key;
    END IF;
END;
$$ LANGUAGE plpgsql;

