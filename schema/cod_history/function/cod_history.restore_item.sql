--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_history, pg_catalog;

--
-- Name: restore_item(integer); Type: FUNCTION; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE FUNCTION restore_item(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_history.restore_item(integer)
    Description:  Restore a cod.item and associated records that have been deleted
    Affects:      Inserts cod.item and associated records
    Arguments:    integer: ID of the item to restore.
    Returns:      boolean
*/
DECLARE
    v_item_id       ALIAS FOR $1;
BEGIN
    -- is a deleted item?
    IF EXISTS(SELECT NULL FROM cod.item WHERE id = v_item_id) THEN
        RAISE EXCEPTION 'Item ID currently exists: %', v_item_id;
    END IF;

    IF NOT EXISTS(SELECT NULL FROM cod_history.item WHERE id = v_item_id) THEN
        RAISE EXCEPTION 'Item ID never existed: %', v_item_id;
    END IF;
    -- disable modified updating
    ALTER TABLE cod.item disable trigger ALL;
    -- restore item with workflow disabled
    INSERT INTO cod.item (workflow_lock, modified_at, modified_by, id, created_at, created_by, rt_ticket, hm_issue, subject, state_id, itil_type_id, support_model_id, severity, stage_id, reference_no, started_at, ended_at, escalated_at, resolved_at, closed_at, content, nag_interval, nag_next) SELECT true, modified_at, modified_by, id, created_at, created_by, rt_ticket, hm_issue, subject, state_id, itil_type_id, support_model_id, severity, stage_id, reference_no, started_at, ended_at, escalated_at, resolved_at, closed_at, content, nag_interval, nag_next FROM cod_history.item WHERE id = v_item_id AND deleted = true ORDER BY modified_at DESC LIMIT 1;
    -- restore events
    ALTER TABLE cod.event disable trigger ALL;
    INSERT INTO cod.event (modified_at, modified_by, id, item_id, host, component, support_model_id, severity, contact, oncall_primary, oncall_alternate, helptext, source_id, start_at, end_at, content) 
        SELECT modified_at, modified_by, id, item_id, host, component, support_model_id, severity, contact, oncall_primary, oncall_alternate, helptext, source_id, start_at, end_at, content 
        FROM cod_history.event 
        JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.event GROUP BY id) AS uni ON (id = uid AND modified_at = mod)
        WHERE item_id = v_item_id;
    ALTER TABLE cod.event enable trigger ALL;
    -- restore actions
    ALTER TABLE cod.action disable trigger ALL;
    INSERT INTO cod.action (modified_at, modified_by, id, item_id, escalation_id, action_type_id, started_at, completed_at, completed_by, skipped, successful, content)
        SELECT modified_at, modified_by, id, item_id, escalation_id, action_type_id, started_at, completed_at, completed_by, skipped, successful, content
        FROM cod_history.action
        JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.action GROUP BY id) AS uni ON (id = uid AND modified_at = mod)
        WHERE item_id = v_item_id;
    ALTER TABLE cod.action enable trigger ALL;
    -- restore escalations
    ALTER TABLE cod.escalation disable trigger ALL;
    INSERT INTO cod.escalation (modified_at, modified_by, id, item_id, rt_ticket, hm_issue, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at, owned_at, resolved_at, content)
        SELECT modified_at, modified_by, id, item_id, rt_ticket, hm_issue, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at, owned_at, resolved_at, content 
        FROM cod_history.escalation
        JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.escalation GROUP BY id) AS uni ON (id = uid AND modified_at = mod)
        WHERE item_id = v_item_id;
    ALTER TABLE cod.escalation enable trigger ALL;
    -- update item to allow workflow
    UPDATE cod.item SET workflow_lock = false WHERE id = v_item_id;
    -- enable modified updating
    ALTER TABLE cod.item enable trigger ALL;
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION cod_history.restore_item(integer) OWNER TO postgres;

--
-- Name: FUNCTION restore_item(integer); Type: COMMENT; Schema: cod_history; Owner: postgres
--

COMMENT ON FUNCTION restore_item(integer) IS 'DR: Restore a cod.item and associated records that have been deleted (2012-04-16)';


--
-- PostgreSQL database dump complete
--

