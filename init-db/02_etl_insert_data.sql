COPY lesson_time(lesson_number, start_time, end_time)
FROM '/tmp/database_export/lesson_time.csv'
DELIMITER ','
CSV HEADER;

CREATE TEMPORARY TABLE temp_auditoriums (
    name VARCHAR(100),
    auditorium_number VARCHAR(20),
    building VARCHAR(100),
    floor INTEGER,
    capacity INTEGER,
    type auditorium_type
);

COPY temp_auditoriums(name, auditorium_number, building, floor, capacity, type)
FROM '/tmp/database_export/auditoriums.csv'
DELIMITER ','
CSV HEADER;

INSERT INTO auditoriums(name, auditorium_number, building, floor, capacity, type)
SELECT DISTINCT ON (building, auditorium_number)
    name,
    auditorium_number,
    building,
    floor,
    capacity,
    type
FROM temp_auditoriums
ORDER BY building, auditorium_number;

DROP TABLE temp_auditoriums;

CREATE TEMPORARY TABLE temp_users_for_groups (
    tg_id INTEGER,
    group_name VARCHAR(100),
    is_admin BOOLEAN
);

COPY temp_users_for_groups(tg_id, group_name, is_admin)
FROM '/tmp/database_export/users.csv'
DELIMITER ','
CSV HEADER
NULL '';

INSERT INTO groups(name)
SELECT DISTINCT group_name
FROM temp_users_for_groups
WHERE group_name IS NOT NULL AND group_name != ''
ORDER BY group_name;

INSERT INTO users(tg_id, group_id, is_admin)
SELECT DISTINCT ON (tu.tg_id)
    tu.tg_id,
    g.id,
    tu.is_admin
FROM temp_users_for_groups tu
LEFT JOIN groups g ON tu.group_name = g.name
ORDER BY tu.tg_id, tu.is_admin DESC;

DROP TABLE temp_users_for_groups;

CREATE TEMPORARY TABLE temp_lessons (
    group_name VARCHAR(100),
    subject_name VARCHAR(100),
    lesson_type lesson_type,
    building VARCHAR(100),
    auditorium_number VARCHAR(20),
    lesson_number INTEGER,
    lesson_date DATE
);

COPY temp_lessons(group_name, subject_name, lesson_type, building, auditorium_number, lesson_number, lesson_date)
FROM '/tmp/database_export/lessons.csv'
DELIMITER ','
CSV HEADER;

INSERT INTO subjects(name)
SELECT DISTINCT subject_name
FROM temp_lessons
ORDER BY subject_name;

INSERT INTO lessons(subject_name, lesson_type, auditorium_id, lesson_number, lesson_date)
SELECT DISTINCT
    tl.subject_name,
    tl.lesson_type,
    a.id,
    tl.lesson_number,
    tl.lesson_date
FROM temp_lessons tl
LEFT JOIN auditoriums a ON tl.building = a.building AND tl.auditorium_number = a.auditorium_number
ORDER BY tl.lesson_date, tl.lesson_number;

INSERT INTO group_lesson(group_id, lesson_id)
SELECT DISTINCT
    g.id,
    l.id
FROM temp_lessons tl
JOIN groups g ON tl.group_name = g.name
LEFT JOIN auditoriums a ON tl.building = a.building AND tl.auditorium_number = a.auditorium_number
JOIN lessons l ON
    l.subject_name = tl.subject_name
    AND l.lesson_type = tl.lesson_type
    AND l.lesson_number = tl.lesson_number
    AND l.lesson_date = tl.lesson_date
    AND l.auditorium_id IS NOT DISTINCT FROM a.id;

CREATE TEMPORARY TABLE temp_users (
    tg_id INTEGER,
    group_name VARCHAR(100),
    is_admin BOOLEAN
);

CREATE TEMPORARY TABLE temp_user_actions (
    tg_id INTEGER,
    action_type VARCHAR(50),
    command_name VARCHAR(50),
    timestamp TIMESTAMP,
    metadata JSONB
);

COPY temp_user_actions(tg_id, action_type, command_name, timestamp, metadata)
FROM '/tmp/database_export/user_actions.csv'
DELIMITER ','
CSV HEADER
NULL '';

INSERT INTO user_actions(user_id, action_type, command_name, timestamp, metadata)
SELECT DISTINCT ON (u.id, tua.action_type, tua.timestamp)
    u.id,
    tua.action_type,
    tua.command_name,
    tua.timestamp,
    tua.metadata
FROM temp_user_actions tua
JOIN users u ON tua.tg_id = u.tg_id
ORDER BY u.id, tua.action_type, tua.timestamp;

DROP TABLE temp_user_actions;

SELECT setval('groups_id_seq', (SELECT MAX(id) FROM groups));
SELECT setval('subjects_id_seq', (SELECT MAX(id) FROM subjects));
SELECT setval('auditoriums_id_seq', (SELECT MAX(id) FROM auditoriums));
SELECT setval('lessons_id_seq', (SELECT MAX(id) FROM lessons));
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('user_actions_id_seq', (SELECT MAX(id) FROM user_actions));
