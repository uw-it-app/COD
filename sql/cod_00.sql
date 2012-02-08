BEGIN;

SELECT standard.create_data_schema('cod', 'Data for the Computer Operations Dashboard');

ALTER DEFAULT PRIVILEGES IN SCHEMA cod GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA cod_history GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC;

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'state', 'COD Item Activity State');

INSERT INTO cod.state (sort, name, description) VALUES
    (0,  'Building', 'Underconstruction'),
    (10, 'Act', 'COPS has an action to perform'),
    (20, 'Processing', 'COD is updating data in the background'),
    (30, 'Escalating', 'Active contact to Level 2/3 support'),
    (60, 'T2-3', 'Escalated to Tier 2/3'),
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

SELECT standard.create_enum_table('cod', 'support_model', 'Support Model -- determines workflow');

ALTER TABLE cod.support_model ADD COLUMN reject boolean NOT NULL DEFAULT FALSE;
ALTER TABLE cod.support_model ADD COLUMN help_text boolean NOT NULL DEFAULT FALSE;
ALTER TABLE cod.support_model ADD COLUMN active_notification boolean NOT NULL DEFAULT FALSE;
ALTER TABLE cod_history.support_model ADD COLUMN reject boolean NOT NULL DEFAULT FALSE;
ALTER TABLE cod_history.support_model ADD COLUMN help_text boolean NOT NULL DEFAULT FALSE;
ALTER TABLE cod_history.support_model ADD COLUMN active_notification boolean NOT NULL DEFAULT FALSE;

INSERT INTO cod.support_model (sort, name, description, reject, help_text, active_notification) VALUES
    (99, '', 'No Model', false, false, false),
    (10, 'A', 'Immediate escalation with active notification', false, false, true),
    (20, 'B', 'L1 works help text then escalation with active notification', false, true, true),
    (30, 'C', 'L1 works help text then escalation with passive notification', false, true, false),
    (40, 'D', 'No support', true, false, false);

/**********************************************************************************************/

CREATE TABLE cod.item (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    rt_ticket       integer,
    hm_issue        integer,
    subject         varchar     NOT NULL,
    state_id        integer     NOT NULL DEFAULT 1 REFERENCES cod.state(id) ON DELETE RESTRICT,
    itil_type_id    integer     NOT NULL DEFAULT 1 REFERENCES cod.itil_type(id) ON DELETE RESTRICT,
    support_model_id integer    NOT NULL DEFAULT 1 REFERENCES cod.support_model(id) ON DELETE RESTRICT,
    severity        smallint    NOT NULL DEFAULT 3 CHECK (severity BETWEEN 1 AND 5),
    stage_id        integer     DEFAULT 1 REFERENCES cod.stage(id) ON DELETE RESTRICT,
    reference_no    varchar,
    started_at      timestamptz,
    ended_at        timestamptz,
    escalated_at    timestamptz,
    resolved_at     timestamptz,
    closed_at       timestamptz,
    content         varchar
);

COMMENT ON TABLE cod.item IS 'DR: COD Line items -- incidents, notifications, etc (2011-10-10)';

GRANT SELECT, INSERT, UPDATE ON TABLE cod.item TO PUBLIC;

SELECT standard.standardize_table_history_and_trigger('cod', 'item');

DROP TRIGGER t_30_distinct_update ON cod.item;
CREATE TRIGGER t_30_distinct_update
    BEFORE UPDATE ON cod.item
    FOR EACH ROW
    EXECUTE PROCEDURE standard.distinct_update();

ALTER TABLE cod_history.item ADD CONSTRAINT state_exists FOREIGN KEY (state_id) REFERENCES cod.state(id) ON DELETE RESTRICT;
ALTER TABLE cod_history.item ADD CONSTRAINT itil_type_exists FOREIGN KEY (itil_type_id) REFERENCES cod.itil_type(id) ON DELETE RESTRICT;
ALTER TABLE cod_history.item ADD CONSTRAINT support_model_exists FOREIGN KEY (support_model_id) REFERENCES cod.support_model(id) ON DELETE CASCADE;
ALTER TABLE cod_history.item ADD CONSTRAINT stage_exists FOREIGN KEY (stage_id) REFERENCES cod.stage(id) ON DELETE RESTRICT;

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'source', 'Event sources');

INSERT INTO cod.source (name, description) VALUES
    ('cod',   'Generated by COD'),
    ('acc',   'Accumulator'),
    ('prox',  'Proxd'),
    ('pilot', 'Pilot');

/**********************************************************************************************/

CREATE TABLE cod.event (
    modified_at         timestamptz NOT NULL DEFAULT now(),
    modified_by         varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id                  serial      PRIMARY KEY,
    item_id             integer     REFERENCES cod.item(id) ON DELETE CASCADE,
    host                varchar,
    component           varchar,
    support_model_id    integer     NOT NULL REFERENCES cod.support_model(id) ON DELETE RESTRICT,
    severity            smallint    NOT NULL DEFAULT 3 CHECK (severity BETWEEN 1 AND 5),
    contact             varchar,
    oncall_primary      varchar,
    oncall_alternate    varchar,
    helptext            varchar,
    source_id           integer     NOT NULL DEFAULT 1 REFERENCES cod.support_model(id) ON DELETE RESTRICT,
    start_at            timestamptz NOT NULL DEFAULT now(),
    end_at              timestamptz,
    content             varchar
);

COMMENT ON TABLE cod.event IS 'DR: Event associated with an item (incident) (2011-10-12)';

GRANT SELECT, INSERT, UPDATE ON TABLE cod.event TO PUBLIC;

SELECT standard.standardize_table_history_and_trigger('cod', 'event');

ALTER TABLE cod_history.event ADD CONSTRAINT support_model_exists FOREIGN KEY (support_model_id) REFERENCES cod.support_model(id) ON DELETE CASCADE;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.event_check_helptext() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.event_check_helptext()
    Description:  Insert trigger to set default helptext if none present
    Affects:      NEW current record
    Arguments:    none
    Returns:      NEW (current record)
*/
DECLARE
BEGIN
    IF NEW.helptext IS NULL AND NEW.component <> '' THEN
        NEW.helptext := 'https://wiki.cac.washington.edu/display/monhelp/component-' || 
            regexp_replace(regexp_replace(NEW.component, E'\\(.*\\)', '', 'g'), E'\\:\\,\\@ ', '_', 'g');
    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.event_check_helptext() IS 'DR: Insert trigger to set default helptext if none present (2011-10-20)';

CREATE TRIGGER t_12_check_helptext
    BEFORE INSERT ON cod.event
    FOR EACH ROW
    EXECUTE PROCEDURE cod.event_check_helptext();

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'esc_state', 'COD escalation state');

INSERT INTO cod.esc_state (sort, name, description) VALUES
    (0,  'Building', 'Underconstruction'),
--    (10, 'Act', 'COPS has an action to perform'),
    (30, 'Active', 'Active contact to Tier 2/3 support'),
    (33, 'Failed', 'Failed notification to Tier 2/3 support')
    (40, 'Passive', 'Passive contact to Tier 2/3 support'),
    (60, 'Owned', 'Tier 2/3 acknowedged issue'),
    (90, 'Resolved', 'All work completed');

/**********************************************************************************************/

CREATE TABLE cod.escalation (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    item_id         integer     NOT NULL REFERENCES cod.item(id) ON DELETE CASCADE,
    rt_ticket       integer,
    hm_issue        integer,
    esc_state_id    integer     NOT NULL DEFAULT 1 REFERENCES cod.esc_state(id) ON DELETE RESTRICT,
    oncall_group    varchar     NOT NULL,
    queue           varchar,
    owner           varchar     NOT NULL DEFAULT 'nobody',
    escalated_at    timestamptz NOT NULL DEFAULT now(),
    owned_at        timestamptz,
    resolved_at     timestamptz,
    content         varchar
);

COMMENT ON TABLE cod.escalation IS 'DR: Track Tickets (etc) for escalation to L2/3 oncall groups';

GRANT SELECT, INSERT, UPDATE ON TABLE cod.escalation TO PUBLIC;

SELECT standard.standardize_table_history_and_trigger('cod', 'escalation');

ALTER TABLE cod_history.escalation ADD CONSTRAINT esc_state_exists FOREIGN KEY (esc_state_id) REFERENCES cod.esc_state(id) ON DELETE RESTRICT;

/**********************************************************************************************/

SELECT standard.create_enum_table('cod', 'action_type', 'Types of actions to prompt operators to perform');

INSERT INTO cod.action_type (name, description) VALUES
    ('HelpText', 'Work the help text for the component'),
    ('PhoneCall', 'Call the listed person'),
    ('Escalate', 'Manually escalate to an oncall group'),
    ('Resolve', 'Incident cleared and all escalations resolved');

/**********************************************************************************************/

CREATE TABLE cod.action (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    item_id         integer     NOT NULL REFERENCES cod.item(id) ON DELETE CASCADE,
    escalation_id   integer     REFERENCES cod.escalation(id) ON DELETE CASCADE,
    action_type_id  integer     NOT NULL REFERENCES cod.action_type(id) ON DELETE RESTRICT,
    started_at      timestamptz NOT NULL DEFAULT now(),
    completed_at    timestamptz,
    completed_by    varchar,
    skipped         boolean,
    successful      boolean,
    content         varchar   
);

COMMENT ON TABLE cod.action IS 'DR: (2011-10-12)';

GRANT SELECT, INSERT, UPDATE ON TABLE cod.action TO PUBLIC;

SELECT standard.standardize_table_history_and_trigger('cod', 'action');

ALTER TABLE cod_history.action ADD CONSTRAINT action_type_exists FOREIGN KEY (action_type_id) REFERENCES cod.action_type(id) ON DELETE RESTRICT;

/**********************************************************************************************/

CREATE TABLE cod.dbcache (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    name            varchar     NOT NULL UNIQUE,
    content         varchar     NOT NULL
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

/**********************************************************************************************/

CREATE VIEW cod.item_event_duplicate (event_id, item_id, host, component, contact, rt_ticket, state) AS 
  SELECT e.id,
         i.id,
         e.host,
         e.component,
         e.contact,
         i.rt_ticket,
         s.name
    FROM cod.event AS e
    JOIN cod.item AS i ON (i.id = e.item_id)
    JOIN cod.state AS s ON (s.id = i.state_id)
    WHERE s.sort < 90;

COMMENT ON VIEW cod.item_event_duplicate IS 'DR: View to find duplicate event/items to an incoming event (2011-10-20)';

GRANT SELECT ON TABLE cod.item_event_duplicate TO PUBLIC;

COMMIT;