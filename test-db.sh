#!/bin/bash

set -e


if ! docker ps | grep -q coursework-db; then
    echo "Container is not running. Start it with: docker-compose up -d"
    exit 1
fi

echo "Container is running"

until docker exec coursework-db pg_isready -U postgres -d coursework > /dev/null 2>&1; do
    sleep 1
done

echo "Database is ready"

echo "Tables:"
docker exec coursework-db psql -U postgres -d coursework -c "\dt" | grep -E "(groups|users|lessons|auditoriums|subjects|lesson_time|group_lesson|user_actions)"

echo "Record counts:"
docker exec coursework-db psql -U postgres -d coursework -t -c "
SELECT
    'groups: ' || COUNT(*) FROM groups
    UNION ALL
SELECT 'users: ' || COUNT(*) FROM users
    UNION ALL
SELECT 'subjects: ' || COUNT(*) FROM subjects
    UNION ALL
SELECT 'auditoriums: ' || COUNT(*) FROM auditoriums
    UNION ALL
SELECT 'lesson_time: ' || COUNT(*) FROM lesson_time
    UNION ALL
SELECT 'lessons: ' || COUNT(*) FROM lessons
    UNION ALL
SELECT 'group_lesson: ' || COUNT(*) FROM group_lesson
    UNION ALL
SELECT 'user_actions: ' || COUNT(*) FROM user_actions;
"

echo "OLAP Tables:"
docker exec coursework-db psql -U postgres -d coursework -c "\dt" | grep -E "(dim_|fact_)" || echo "No OLAP tables found"

