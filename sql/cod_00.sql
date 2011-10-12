SELECT standard.create_data_schema('cod', 'Data for the Computer Operations Dashboard');

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'state', 'COD Item Activity State');

INSERT INTO cod.state (sort, name, description) VALUES
    (10, 'Act', 'COPS has an action to perform'),
    (30, 'Escalating', 'Active contact to Layer 2/3 support'),
    (60, 'L2-3', 'Escalated to Layer 2/3'),
    (80, 'Cleared', 'Impact cleared but not resolved'),
    (90, 'Resolved', 'All work completed');

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'itil_type', 'ITIL classification of the record');

INSERT INTO cod.itil_type (sort, name, description) VALUES
    (10, 'Incident', ''),
    (30, 'Service Request', ''),
    (99, 'N/A', '');

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'stage', 'Stage in the ITIL Incident Process');

INSERT INTO cod.stage (sort, name, description) VALUES
    (10, 'Identification', ''),
    (20, 'Logging', ''),
    (30, 'Categorization', ''),
    (40, 'Prioritization', ''),
    (50, 'Initial Diagnosis', ''),
    (60, 'Functional Escalation', ''),
    (70, 'Management Escalation', ''),
    (80, 'Investigation and Diagnosis', ''),
    (90, 'Resolution and Recovery', ''),
    (99, 'Closure', '');

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'ref_app', 'Application reference number is for');

INSERT INTO cod.ref_app (name) VALUES
    ('COD'),
    ('RT'),
    ('H&M');

/**********************************************************************************************/

CREATE TABLE cod.item (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    ref_app_id      integer     NOT NULL DEFAULT 1 REFERENCES cod.ref_app(id) ON DELETE RESTRICT,
    reference       varchar,
    state_id        integer     NOT NULL DEFAULT 1 REFERENCES cod.state(id) ON DELETE RESTRICT,
    itil_type_id    integer     NOT NULL DEFAULT 1 REFERENCES cod.itil_type(id) ON DELETE RESTRICT,
    stage_id        integer     DEFAULT 1 REFERENCES cod.stage(id) ON DELETE RESTRICT,
    started_at      timestamptz NOT NULL DEFAULT now(),
    ended_at        timestamptz,
    resolved_at     timestamptz,
    closed_at       timestamptz,
    content         xml
);

COMMENT ON TABLE cod.item IS 'DR: COD Line items -- incidents, notifications, etc (2011-10-10)';

GRANT SELECT, INSERT, UPDATE ON TABLE cod.item TO PUBLIC;

SELECT standard.standardize_table_and_trigger('cod', 'item');

ALTER TABLE cod_history.item ADD CONSTRAINT ref_app_exists FOREIGN KEY (ref_app_id) REFERENCES cod.ref_app(id) ON DELETE RESTRICT;
ALTER TABLE cod_history.item ADD CONSTRAINT state_exists FOREIGN KEY (state_id) REFERENCES cod.state(id) ON DELETE RESTRICT;
ALTER TABLE cod_history.item ADD CONSTRAINT itil_type_exists FOREIGN KEY (itil_type_id) REFERENCES cod.itil_type(id) ON DELETE RESTRICT;
ALTER TABLE cod_history.item ADD CONSTRAINT stage_exists FOREIGN KEY sStage_id) REFERENCES cod.stage(id) ON DELETE RESTRICT;

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'esc_state', 'COD escalation state');

INSERT INTO cod.state (sort, name, description) VALUES
    (10, 'Act', 'COPS has an action to perform'),
    (30, 'Active', 'Active contact to Layer 2/3 support'),
    (40, 'Passive', 'Passive contact to Layer 2/3 support'),
    (60, 'Owned', 'Layer 2/3 acknowedged issue'),
    (90, 'Resolved', 'All work completed');

/**********************************************************************************************/

CREATE TABLE cod.escalation (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    item_id         integer     NOT NULL REFERENCES cod.item(id) ON DELETE CASCADE,
    ref_app_id      integer     NOT NULL DEFAULT 1 REFERENCES cod.ref_app(id) ON DELETE RESTRICT,
    reference       varchar,
    esc_state_id    integer     NOT NULL DEFAULT 1 REFERENCES cod.esc_state(id) ON DELETE RESTRICT,
    oncall_group    varchar     NOT NULL,
    queue           varchar     NOT NULL,
    started_at      timestamptz NOT NULL DEFAULT now(),
    owned_at        timestamptz,
    resolved_at     timestamptz,
    content         xml
);

COMMENT ON TABLE cod.escalation IS 'DR: Track Tickets (etc) for escalation to L2/3 oncall groups';

GRANT SELECT, INSERT, UPDATE ON TABLE cod.escalation TO PUBLIC;

SELECT standard.standardize_table_and_trigger('cod', 'escalation');

ALTER TABLE cod_history.escalation ADD CONSTRAINT ref_app_exists FOREIGN KEY (ref_app_id) REFERENCES cod.ref_app(id) ON DELETE RESTRICT;
ALTER TABLE cod_history.escalation ADD CONSTRAINT esc_state_exists FOREIGN KEY (esc_state_id) REFERENCES cod.esc_state(id) ON DELETE RESTRICT;

/**********************************************************************************************/

CREATE TABLE cod.dbcache (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    name            varchar     NOT NULL UNIQUE,
    content         xml         NOT NULL
);

COMMENT ON TABLE cod.dbcache IS 'DR: Cached XML for display (2011-10-10)';

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE cod.dbcache TO PUBLIC;

CREATE TRIGGER t_10_anchored_id
    BEFORE UPDATE ON cod.dbcache
    FOR EACH ROW
    EXECUTE PROCEDURE standard.anchored_id();

CREATE TRIGGER t_11_anchored_column
    BEFORE UPDATE ON cod.dbcache
    FOR EACH ROW
    EXECUTE PROCEDURE standard.anchored_column('name');

CREATE TRIGGER t_30_distinct_update
    BEFORE UPDATE ON cod.dbcache
    FOR EACH ROW
    EXECUTE PROCEDURE standard.distinct_update_nm();

CREATE TRIGGER t_50_modified
    BEFORE INSERT OR UPDATE ON cod.dbcache
    FOR EACH ROW
    EXECUTE PROCEDURE standard.modified();
