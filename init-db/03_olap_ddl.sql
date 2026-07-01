CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(10) NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    week_of_year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    quarter INTEGER NOT NULL,
    year INTEGER NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

CREATE INDEX idx_dim_date_full_date ON dim_date(full_date);
CREATE INDEX idx_dim_date_year_month ON dim_date(year, month);

CREATE TABLE dim_group (
    group_key SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL,
    group_name VARCHAR(100) NOT NULL,
    enrollment_year INTEGER NOT NULL,
    current_semester INTEGER NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_group_id ON dim_group(group_id);
CREATE INDEX idx_dim_group_name ON dim_group(group_name);
CREATE INDEX idx_dim_group_current ON dim_group(is_current);

CREATE TABLE dim_subject (
    subject_key SERIAL PRIMARY KEY,
    subject_id INTEGER NOT NULL,
    subject_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE INDEX idx_dim_subject_name ON dim_subject(subject_name);

CREATE TABLE dim_auditorium (
    auditorium_key SERIAL PRIMARY KEY,
    auditorium_id INTEGER NOT NULL,
    auditorium_name VARCHAR(100) NOT NULL,
    auditorium_number VARCHAR(20),
    building VARCHAR(100) NOT NULL,
    floor INTEGER NOT NULL,
    capacity INTEGER,
    auditorium_type VARCHAR(50) NOT NULL
);

CREATE INDEX idx_dim_auditorium_id ON dim_auditorium(auditorium_id);
CREATE INDEX idx_dim_auditorium_building ON dim_auditorium(building);
CREATE INDEX idx_dim_auditorium_type ON dim_auditorium(auditorium_type);

CREATE TABLE dim_lesson_time (
    lesson_time_key SERIAL PRIMARY KEY,
    lesson_number INTEGER NOT NULL UNIQUE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL
);

CREATE INDEX idx_dim_lesson_time_number ON dim_lesson_time(lesson_number);

CREATE TABLE dim_user (
    user_key SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    tg_id INTEGER NOT NULL,
    group_key INTEGER REFERENCES dim_group(group_key),
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_user_id ON dim_user(user_id);
CREATE INDEX idx_dim_user_tg_id ON dim_user(tg_id);
CREATE INDEX idx_dim_user_current ON dim_user(is_current);
CREATE INDEX idx_dim_user_group ON dim_user(group_key);

CREATE TABLE bridge_group_lesson (
    bridge_key SERIAL PRIMARY KEY,
    lesson_key INTEGER NOT NULL,
    group_key INTEGER NOT NULL REFERENCES dim_group(group_key),
    UNIQUE(lesson_key, group_key)
);

CREATE INDEX idx_bridge_lesson ON bridge_group_lesson(lesson_key);
CREATE INDEX idx_bridge_group ON bridge_group_lesson(group_key);

CREATE TABLE fact_lessons (
    lesson_key SERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    subject_key INTEGER NOT NULL REFERENCES dim_subject(subject_key),
    auditorium_key INTEGER REFERENCES dim_auditorium(auditorium_key),
    lesson_time_key INTEGER NOT NULL REFERENCES dim_lesson_time(lesson_time_key),
    lesson_type VARCHAR(20),
    total_groups INTEGER NOT NULL DEFAULT 0,
    total_students INTEGER NOT NULL DEFAULT 0,
    is_online BOOLEAN DEFAULT FALSE,
    load_date TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fact_lessons_date ON fact_lessons(date_key);
CREATE INDEX idx_fact_lessons_subject ON fact_lessons(subject_key);
CREATE INDEX idx_fact_lessons_auditorium ON fact_lessons(auditorium_key);
CREATE INDEX idx_fact_lessons_time ON fact_lessons(lesson_time_key);
CREATE INDEX idx_fact_lessons_type ON fact_lessons(lesson_type);

CREATE TABLE fact_user_actions (
    action_key SERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    user_key INTEGER NOT NULL REFERENCES dim_user(user_key),
    group_key INTEGER REFERENCES dim_group(group_key),
    action_type VARCHAR(50) NOT NULL,
    total_actions INTEGER NOT NULL DEFAULT 0,
    total_commands INTEGER NOT NULL DEFAULT 0,
    total_api_calls INTEGER NOT NULL DEFAULT 0,
    unique_commands_used INTEGER NOT NULL DEFAULT 0,
    session_duration_minutes INTEGER,
    load_date TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fact_actions_date ON fact_user_actions(date_key);
CREATE INDEX idx_fact_actions_user ON fact_user_actions(user_key);
CREATE INDEX idx_fact_actions_group ON fact_user_actions(group_key);
CREATE INDEX idx_fact_actions_type ON fact_user_actions(action_type);

CREATE TABLE agg_weekly_group_metrics (
    week_key INTEGER NOT NULL,
    group_key INTEGER NOT NULL REFERENCES dim_group(group_key),
    total_lessons INTEGER NOT NULL DEFAULT 0,
    total_lectures INTEGER NOT NULL DEFAULT 0,
    total_practices INTEGER NOT NULL DEFAULT 0,
    total_labs INTEGER NOT NULL DEFAULT 0,
    total_seminars INTEGER NOT NULL DEFAULT 0,
    unique_subjects INTEGER NOT NULL DEFAULT 0,
    unique_auditoriums INTEGER NOT NULL DEFAULT 0,
    avg_students_per_lesson DECIMAL(10,2),
    active_users INTEGER NOT NULL DEFAULT 0,
    total_user_actions INTEGER NOT NULL DEFAULT 0,
    load_date TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (week_key, group_key)
);

CREATE INDEX idx_agg_weekly_week ON agg_weekly_group_metrics(week_key);
CREATE INDEX idx_agg_weekly_group ON agg_weekly_group_metrics(group_key);

CREATE TABLE agg_monthly_subject_metrics (
    month_key INTEGER NOT NULL,
    subject_key INTEGER NOT NULL REFERENCES dim_subject(subject_key),
    total_lessons INTEGER NOT NULL DEFAULT 0,
    total_groups INTEGER NOT NULL DEFAULT 0,
    total_students INTEGER NOT NULL DEFAULT 0,
    unique_auditoriums INTEGER NOT NULL DEFAULT 0,
    load_date TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (month_key, subject_key)
);

CREATE INDEX idx_agg_monthly_month ON agg_monthly_subject_metrics(month_key);
CREATE INDEX idx_agg_monthly_subject ON agg_monthly_subject_metrics(subject_key);

