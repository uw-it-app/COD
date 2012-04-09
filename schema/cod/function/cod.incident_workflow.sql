--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod, pg_catalog;

--
-- Name: incident_workflow(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_workflow() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.incident_workflow()
    Description:  Workflow for incidents (and more for now)
    Affects:      Active Item record and associated elements
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _oncall     varchar;
    _row        record;
BEGIN
    IF NEW.rt_ticket IS NULL THEN
        NEW.rt_ticket := cod.create_incident_ticket_from_event((SELECT id FROM cod.event WHERE item_id = NEW.id ORDER BY id LIMIT 1));
        IF NEW.rt_ticket IS NOT NULL THEN
            UPDATE cod.item SET rt_ticket = NEW.rt_ticket WHERE id = NEW.id;
            RETURN NEW;
        END IF;
    END IF;

    --IF NEW.state_id = standard.enum_value_id('cod', 'state', 'Merged') THEN
    --    RETURN NEW;
    --END IF;

    IF NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN
        IF NEW.ended_at IS NOT NULL THEN
            -- cancel all active escalations
            PERFORM hm_v1.close_issue(hm_issue, owner, ' ') FROM cod.escalation WHERE item_id = NEW.id;
        END IF;
    END IF;

    IF NEW.nag_next IS NULL THEN
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag') AND completed_at IS NULL;
        IF FOUND IS TRUE THEN
            RETURN NEW;
        END IF;
    ELSEIF NEW.nag_next <= now() AND 
        NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag')) 
    THEN
        INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Nag'));
        RETURN NEW;
    END IF;

    IF NEW.state_id = standard.enum_value_id('cod', 'state', 'ACT') THEN
        IF EXISTS (SELECT NULL FROM cod.escalation WHERE standard.enum_id_value('cod', 'esc_state', esc_state_id) NOT IN ('Resolved', 'Rejected', 'Merged')) 
        THEN
            UPDATE cod.action SET completed_at = now(), successful = FALSE 
                WHERE item_id = NEW.id AND escalation_id IS NULL AND completed_at IS NULL 
                AND standard.enum_value_id('cod', 'action_type', 'Escalate');
            RETURN NEW;
        END IF;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed') THEN
        PERFORM cod.dash_delete_event(id) FROM cod.event WHERE item_id = NEW.id;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved') THEN
        IF NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close') AND completed_at IS NULL)
        THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Close'));
        END IF;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Cleared') THEN
        -- If no escalations are unresolved prompt operator to resolve ticket
        IF ((NEW.escalated_at IS NOT NULL AND NEW.resolved_at IS NOT NULL) OR
            (NEW.escalated_at IS NULL AND NEW.resolved_at IS NULL)) AND
            NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close') AND completed_at IS NULL)
        THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Close'));
        END IF;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Processing') THEN
        IF NEW.ended_at IS NULL AND NEW.started_at IS NOT NULL AND NEW.resolved_at IS NOT NULL THEN
            INSERT INTO cod.action (item_id, action_type_id, content) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>All Escalations resolved but the alert is not cleared, clear the alert or Escalate</Note>');
        END IF;
    END IF;

    -- if have not escalated
    IF NEW.escalated_at IS NULL THEN
        -- if no helptext action
        IF NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText'))
        THEN
            IF (SELECT help_text FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
                -- create action to prompt for acting on helptext
                INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'));
            ELSE
                INSERT INTO cod.action (item_id, action_type_id, completed_at, completed_by, skipped, successful) VALUES 
                    (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'), now(), 'ssg-cod', true, false);
            END IF;
        END IF;

        -- if no active (or successful) helptext and unclosed event (and not escalated)
        IF NEW.ended_at is NULL AND
            NOT EXISTS (SELECT NULL FROM cod.action AS a JOIN cod.action_type AS t ON (a.action_type_id=t.id) 
                WHERE a.item_id = NEW.id AND (t.name = 'HelpText' OR t.name = 'Escalate') AND (completed_at IS NULL OR successful IS TRUE))
        THEN
            SELECT * INTO _row FROM cod.event WHERE item_id = NEW.id ORDER BY id DESC LIMIT 1;
            _oncall := COALESCE(_row.contact, _row.oncall_primary, _row.oncall_alternate);
            IF _oncall IS NOT NULL THEN
                -- create escalation (see escalation_workflow)
                IF (SELECT active_notification FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
                    INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (NEW.id, _oncall, standard.enum_value_id('cod', 'page_state', 'Active'));
                ELSE
                    INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (NEW.id, _oncall, standard.enum_value_id('cod', 'page_state', 'Passive'));
                END IF;
            END IF;
            -- if no valid oncall group or failed to insert escalation
            IF _oncall IS NULL OR FOUND IS FALSE THEN
                -- create action to prompt to correct oncall group
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>No valid oncall group in the event, manual escalation required.</Note>');
            END IF;
        END IF;

    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.incident_workflow() OWNER TO postgres;

--
-- Name: FUNCTION incident_workflow(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_workflow() IS 'DR: Workflow for incidents (and more for now) (2012-02-29)';


--
-- PostgreSQL database dump complete
--

