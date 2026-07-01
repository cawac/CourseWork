DROP TABLE IF EXISTS user_actions CASCADE;
DROP TABLE IF EXISTS group_lesson CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS lesson_time CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS subjects CASCADE;
DROP TABLE IF EXISTS auditoriums CASCADE;
DROP TYPE IF EXISTS lesson_type CASCADE;
DROP TYPE IF EXISTS auditorium_type CASCADE;

CREATE TYPE lesson_type AS ENUM (
    'UNKNOWN',
    'LECTURE',
    'PRACTICE',
    'SEMINAR',
    'LAB',
    'EXAM'
);

CREATE TYPE auditorium_type AS ENUM (
    'CLASSROOM',
    'LECTURE_HALL',
    'COMPUTER_LAB',
    'LABORATORY',
    'SEMINAR_ROOM',
    'SPORTS_HALL',
    'GYM',
    'CONFERENCE_ROOM'
);

CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    CONSTRAINT groups_name_not_empty CHECK (name <> '')
);

CREATE INDEX idx_groups_name ON groups(name);

CREATE TABLE subjects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT subjects_name_not_empty CHECK (name <> '')
);

CREATE TABLE auditoriums (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    auditorium_number VARCHAR(20),
    building VARCHAR(100) NOT NULL,
    floor INTEGER NOT NULL,
    capacity INTEGER,
    type auditorium_type NOT NULL DEFAULT 'CLASSROOM',
    CONSTRAINT auditoriums_floor_positive CHECK (floor > 0),
    CONSTRAINT auditoriums_capacity_positive CHECK (capacity IS NULL OR capacity > 0),
    CONSTRAINT auditoriums_building_number_unique UNIQUE (building, auditorium_number)
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    tg_id INTEGER NOT NULL UNIQUE,
    group_id INTEGER,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_users_group FOREIGN KEY (group_id)
        REFERENCES groups(id) ON DELETE SET NULL
);

CREATE INDEX idx_users_tg_id ON users(tg_id);

CREATE TABLE lesson_time (
    lesson_number INTEGER PRIMARY KEY,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CONSTRAINT lesson_number_check CHECK (lesson_number BETWEEN 1 AND 7),
    CONSTRAINT time_order_check CHECK (start_time < end_time)
);

CREATE TABLE lessons (
    id SERIAL PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    lesson_type lesson_type,
    auditorium_id INTEGER,
    lesson_number INTEGER,
    lesson_date DATE NOT NULL,
    CONSTRAINT fk_lessons_subject FOREIGN KEY (subject_name)
        REFERENCES subjects(name) ON DELETE CASCADE,
    CONSTRAINT fk_lessons_auditorium FOREIGN KEY (auditorium_id)
        REFERENCES auditoriums(id) ON DELETE SET NULL,
    CONSTRAINT fk_lessons_lesson_time FOREIGN KEY (lesson_number)
        REFERENCES lesson_time(lesson_number) ON DELETE SET NULL
);

CREATE INDEX idx_lessons_date ON lessons(lesson_date);
CREATE INDEX idx_lessons_subject ON lessons(subject_name);
CREATE INDEX idx_lessons_auditorium ON lessons(auditorium_id);

CREATE TABLE group_lesson (
    group_id INTEGER NOT NULL,
    lesson_id INTEGER NOT NULL,
    PRIMARY KEY (group_id, lesson_id),
    CONSTRAINT fk_group_lesson_group FOREIGN KEY (group_id)
        REFERENCES groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_group_lesson_lesson FOREIGN KEY (lesson_id)
        REFERENCES lessons(id) ON DELETE CASCADE
);

CREATE TABLE user_actions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    command_name VARCHAR(50),
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,
    CONSTRAINT fk_user_actions_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_user_action_command ON user_actions(command_name);
