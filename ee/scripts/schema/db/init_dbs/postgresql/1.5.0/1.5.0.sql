\set previous_version 'v1.4.0-ee'
\set next_version 'v1.5.0-ee'
SELECT openreplay_version()                       AS current_version,
       openreplay_version() = :'previous_version' AS valid_previous,
       openreplay_version() = :'next_version'     AS is_next
\gset

\if :valid_previous
\echo valid previous DB version :'previous_version', starting DB upgrade to :'next_version'
BEGIN;
SELECT format($fn_def$
CREATE OR REPLACE FUNCTION openreplay_version()
    RETURNS text AS
$$
SELECT '%1$s'
$$ LANGUAGE sql IMMUTABLE;
$fn_def$, :'next_version')
\gexec

--
CREATE TABLE IF NOT EXISTS traces
(
    user_id     integer NULL REFERENCES users (user_id) ON DELETE CASCADE,
    tenant_id   integer NOT NULL REFERENCES tenants (tenant_id) ON DELETE CASCADE,
    created_at  bigint  NOT NULL DEFAULT (EXTRACT(EPOCH FROM now() at time zone 'utc') * 1000)::bigint,
    auth        text    NULL,
    action      text    NOT NULL,
    method      text    NOT NULL,
    path_format text    NOT NULL,
    endpoint    text    NOT NULL,
    payload     jsonb   NULL,
    parameters  jsonb   NULL,
    status      int     NULL
);

DROP TRIGGER IF EXISTS on_insert_or_update ON projects;
CREATE TRIGGER on_insert_or_update
    AFTER INSERT OR UPDATE
    ON projects
    FOR EACH ROW
EXECUTE PROCEDURE notify_project();

UPDATE tenants
SET name=''
WHERE name ISNULL;
ALTER TABLE tenants
    ALTER COLUMN name SET NOT NULL;

ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS utm_source   text NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS utm_medium   text NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS utm_campaign text NULL DEFAULT NULL;


DROP INDEX IF EXISTS sessions_project_id_user_browser_idx1;
DROP INDEX IF EXISTS sessions_project_id_user_country_idx1;
ALTER INDEX IF EXISTS platform_idx RENAME TO sessions_platform_idx;
ALTER INDEX IF EXISTS events.resources_duration_idx RENAME TO resources_duration_durationgt0_idx;
DROP INDEX IF EXISTS projects_project_key_idx1;

CREATE TABLE IF NOT EXISTS metrics
(
    metric_id  integer generated BY DEFAULT AS IDENTITY PRIMARY KEY,
    project_id integer NOT NULL REFERENCES projects (project_id) ON DELETE CASCADE,
    user_id    integer REFERENCES users (user_id) ON DELETE SET NULL,
    name       text    NOT NULL,
    is_public  boolean NOT NULL DEFAULT FALSE,
    created_at timestamp        default timezone('utc'::text, now()) not null,
    deleted_at timestamp
);

CREATE TABLE IF NOT EXISTS metric_series
(
    series_id  integer generated BY DEFAULT AS IDENTITY PRIMARY KEY,
    metric_id  integer REFERENCES metrics (metric_id) ON DELETE CASCADE,
    index      integer                                        NOT NULL,
    name       text                                           NULL,
    filter     jsonb                                          NOT NULL,
    created_at timestamp DEFAULT timezone('utc'::text, now()) NOT NULL,
    deleted_at timestamp
);


CREATE TABLE IF NOT EXISTS searches
(
    search_id  integer generated BY DEFAULT AS IDENTITY PRIMARY KEY,
    project_id integer NOT NULL REFERENCES projects (project_id) ON DELETE CASCADE,
    user_id    integer NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    name       text    not null,
    filter     jsonb   not null,
    created_at timestamp        default timezone('utc'::text, now()) not null,
    deleted_at timestamp,
    is_public  boolean NOT NULL DEFAULT False
);

ALTER TABLE alerts
    ADD COLUMN IF NOT EXISTS series_id integer NULL REFERENCES metric_series (series_id) ON DELETE CASCADE;

UPDATE alerts
SET options=jsonb_set(options, '{change}', '"change"')
WHERE detection_method = 'change'
  AND options -> 'change' ISNULL;

ALTER TABLE roles
    ADD COLUMN IF NOT EXISTS all_projects bool NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS roles_projects
(
    role_id    integer NOT NULL REFERENCES roles (role_id) ON DELETE CASCADE,
    project_id integer NOT NULL REFERENCES projects (project_id) ON DELETE CASCADE,
    CONSTRAINT roles_projects_pkey PRIMARY KEY (role_id, project_id)
);
--

ALTER TABLE public.metrics
    ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT TRUE;
COMMIT;
ALTER TYPE public.error_source ADD VALUE IF NOT EXISTS 'elasticsearch'; -- cannot add new value inside a transaction block

CREATE INDEX CONCURRENTLY IF NOT EXISTS traces_user_id_idx ON traces (user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS traces_tenant_id_idx ON traces (tenant_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS user_favorite_sessions_user_id_session_id_idx ON user_favorite_sessions (user_id, session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_first_contentful_paint_time_idx ON events.pages (first_contentful_paint_time) WHERE first_contentful_paint_time > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_dom_content_loaded_time_idx ON events.pages (dom_content_loaded_time) WHERE dom_content_loaded_time > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_first_paint_time_idx ON events.pages (first_paint_time) WHERE first_paint_time > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_ttfb_idx ON events.pages (ttfb) WHERE ttfb > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_time_to_interactive_idx ON events.pages (time_to_interactive) WHERE time_to_interactive > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_session_id_timestamp_loadgt0NN_idx ON events.pages (session_id, timestamp) WHERE load_time > 0 AND load_time IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_session_id_timestamp_visualgt0nn_idx ON events.pages (session_id, timestamp) WHERE visually_complete > 0 AND visually_complete IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_timestamp_metgt0_idx ON events.pages (timestamp) WHERE
        response_time > 0 OR
        first_paint_time > 0 OR
        dom_content_loaded_time > 0 OR
        ttfb > 0 OR
        time_to_interactive > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_session_id_speed_indexgt0nn_idx ON events.pages (session_id, speed_index) WHERE speed_index > 0 AND speed_index IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS pages_session_id_timestamp_dom_building_timegt0nn_idx ON events.pages (session_id, timestamp, dom_building_time) WHERE dom_building_time > 0 AND dom_building_time IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS issues_project_id_idx ON issues (project_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_project_id_error_id_js_exception_idx ON public.errors (project_id, error_id) WHERE source = 'js_exception';
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_project_id_error_id_idx ON public.errors (project_id, error_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_project_id_error_id_integration_idx ON public.errors (project_id, error_id) WHERE source != 'js_exception';
CREATE INDEX CONCURRENTLY IF NOT EXISTS sessions_start_ts_idx ON public.sessions (start_ts) WHERE duration > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS sessions_project_id_idx ON public.sessions (project_id) WHERE duration > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS sessions_session_id_project_id_start_ts_idx ON sessions (session_id, project_id, start_ts) WHERE duration > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS user_favorite_sessions_user_id_session_id_idx ON user_favorite_sessions (user_id, session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS jobs_project_id_idx ON jobs (project_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_session_id_timestamp_error_id_idx ON events.errors (session_id, timestamp, error_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_error_id_timestamp_idx ON events.errors (error_id, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_timestamp_error_id_session_id_idx ON events.errors (timestamp, error_id, session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_error_id_timestamp_session_id_idx ON events.errors (error_id, timestamp, session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_timestamp_idx ON events.resources (timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_success_idx ON events.resources (success);
CREATE INDEX CONCURRENTLY IF NOT EXISTS projects_project_key_idx ON public.projects (project_key);
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_timestamp_type_durationgt0NN_idx ON events.resources (timestamp, type) WHERE duration > 0 AND duration IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_session_id_timestamp_idx ON events.resources (session_id, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_session_id_timestamp_type_idx ON events.resources (session_id, timestamp, type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_timestamp_type_durationgt0NN_noFetch_idx ON events.resources (timestamp, type) WHERE duration > 0 AND duration IS NOT NULL AND type != 'fetch';
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_session_id_timestamp_url_host_fail_idx ON events.resources (session_id, timestamp, url_host) WHERE success = FALSE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_session_id_timestamp_url_host_firstparty_idx ON events.resources (session_id, timestamp, url_host) WHERE type IN ('fetch', 'script');
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_session_id_timestamp_duration_durationgt0NN_img_idx ON events.resources (session_id, timestamp, duration) WHERE duration > 0 AND duration IS NOT NULL AND type = 'img';
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_timestamp_session_id_idx ON events.resources (timestamp, session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS sessions_utm_source_gin_idx ON public.sessions USING GIN (utm_source gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS sessions_utm_medium_gin_idx ON public.sessions USING GIN (utm_medium gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS sessions_utm_campaign_gin_idx ON public.sessions USING GIN (utm_campaign gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS requests_timestamp_session_id_failed_idx ON events_common.requests (timestamp, session_id) WHERE success = FALSE;
CREATE INDEX CONCURRENTLY IF NOT EXISTS errors_parent_error_id_idx ON errors (parent_error_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS performance_session_id_idx ON events.performance (session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS performance_timestamp_idx ON events.performance (timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS performance_session_id_timestamp_idx ON events.performance (session_id, timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS performance_avg_cpu_gt0_idx ON events.performance (avg_cpu) WHERE avg_cpu > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS performance_avg_used_js_heap_size_gt0_idx ON events.performance (avg_used_js_heap_size) WHERE avg_used_js_heap_size > 0;
CREATE INDEX CONCURRENTLY IF NOT EXISTS roles_projects_role_id_idx ON roles_projects (role_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS roles_projects_project_id_idx ON roles_projects (project_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS resources_timestamp_duration_durationgt0NN_idx ON events.resources (timestamp, duration) WHERE duration > 0 AND duration IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS searches_user_id_is_public_idx ON public.searches (user_id, is_public);
CREATE INDEX CONCURRENTLY IF NOT EXISTS searches_project_id_idx ON public.searches (project_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS alerts_project_id_idx ON alerts (project_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS alerts_series_id_idx ON alerts (series_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS metrics_user_id_is_public_idx ON public.metrics (user_id, is_public);
CREATE INDEX CONCURRENTLY IF NOT EXISTS metric_series_metric_id_idx ON public.metric_series (metric_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS funnels_project_id_idx ON public.funnels (project_id);

\elif :is_next
\echo new version detected :'next_version', nothing to do
\else
\warn skipping DB upgrade of :'next_version', expected previous version :'previous_version', found :'current_version'
\endif