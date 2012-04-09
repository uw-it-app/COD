--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: process_hm_update(xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION process_hm_update(xml) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.process_hm_update(xml)
    Description:  Process HM Issues state for COD
    Affects:      COD.item/escalation/action associated with this H&M notification
    Arguments:    xml: XML representation of an H&M Issue
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _hm_id      integer;
    _ticket     integer;
    _activity   varchar;
    _content    varchar;
    _row        record;
    _item_id    integer;
    _action     cod.action%ROWTYPE;
BEGIN
    _hm_id    := xpath.get_integer('/Issue/Id', v_xml);
    _ticket   := xpath.get_integer('/Issue/Ticket', v_xml);
    _activity := xpath.get_varchar('/Issue/Activity', v_xml);
    _content  := xpath('/Issue/CurrentSquawk', v_xml)::text::varchar;
    SELECT * INTO _row FROM cod.escalation WHERE hm_issue = _hm_id OR (rt_ticket = _ticket AND hm_issue IS NULL);
    IF _row.id IS NOT NULL THEN
        IF _activity = 'closed' THEN
            IF _row.owner = 'nobody' AND xpath.get_varchar('/Issue/Owner', v_xml) <> 'nobody' THEN
                Update cod.escalation SET 
                    owner = xpath.get_varchar('/Issue/Owner', v_xml),
                    page_state_id = standard.enum_value_id('cod', 'page_state', 'Closed')
                    WHERE id = _row.id;
            ELSE
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Closed') WHERE id = _row.id;
            END IF;    
        ELSEIF _activity = 'cancelled' THEN
            PERFORM cod.remove_esc_actions(_row.id);
            Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Cancelled') WHERE id = _row.id;
        ELSEIF _activity = 'failed' THEN
            PERFORM cod.remove_esc_actions(_row.id);
            Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Failed') WHERE id = _row.id;
        ELSEIF _activity = 'escalating' THEN
            PERFORM cod.remove_esc_actions(_row.id);
            Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating') WHERE id = _row.id;
        ELSEIF _activity = 'act' THEN
            UPDATE cod.action SET completed_at = now(), successful = FALSE
                WHERE escalation_id = _row.id AND completed_at IS NULL AND content <> _content;
            SELECT * INTO _action FROM cod.action WHERE escalation_id = _row.id AND content = _content;
            IF _action.id IS NULL THEN
                INSERT INTO cod.action (item_id, escalation_id, action_type_id, content) VALUES (
                    _row.item_id,
                    _row.id,
                    standard.enum_value_id('cod', 'action_type', 'PhoneCall'),
                    _content
                );
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') WHERE id = _row.id;
            ELSEIF _action.completed_at IS NULL THEN
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') WHERE id = _row.id;
            ELSE
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating') WHERE id = _row.id;
            END IF;
        END IF;
        RETURN TRUE;
    END IF;

    SELECT * INTO _row FROM cod.item 
        WHERE (rt_ticket IS NULL OR rt_ticket = _ticket) 
          AND (hm_issue IS NULL OR hm_issue = _hm_id)
          AND (rt_ticket IS NOT NULL OR hm_issue IS NOT NULL);

    IF _row.id IS NULL THEN
        IF ARRAY[_activity] <@ ARRAY['closed', 'cancelled', 'failed']::varchar[] THEN
            RETURN FALSE;
        ELSE
            -- get id
            _item_id := nextval('cod.item_id_seq'::regclass);
            -- create
            INSERT INTO cod.item (id, itil_type_id, state_id, hm_issue, subject, workflow_lock) VALUES (
                _item_id,
                standard.enum_value_id('cod', 'itil_type', '(Notification)'),
                standard.enum_value_id('cod', 'state', 'Escalating'),
                _hm_id,
                xpath.get_varchar('/Issue/Subject', v_xml),
                TRUE
            );
            IF _activity = 'act' THEN
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (
                    _item_id,
                    standard.enum_value_id('cod', 'action_type', 'PhoneCall'),
                    _content
                );
                UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Act') WHERE id = _item_id;
            END IF;
        END IF;
        RETURN TRUE;
    ELSE
        IF ARRAY[_activity] <@ ARRAY['closed', 'cancelled', 'failed']::varchar[] THEN
            -- remove all phoncalls for this item;
            UPDATE cod.action SET completed_at = now(), successful = false 
                WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND completed_at IS NULL;
            UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Closed'), closed_at = now() WHERE id = _row.id;
        ELSEIF _activity = 'escalating' THEN
            UPDATE cod.action SET completed_at = now(), successful = false 
                WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND completed_at IS NULL;
            UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Escalating') WHERE id = _row.id;
        ELSEIF _activity = 'act' THEN
            -- remove any ponecalls where content doesn't equal _content
            UPDATE cod.action SET completed_at = now(),successful = false 
                WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND completed_at IS NULL AND content <> _content AND completed_at IS NULL;
            -- if action doesn't exist then insert
            IF NOT EXISTS (SELECT NULL FROM cod.action WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND content = _content AND completed_at IS NULL)
            THEN
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (
                    _row.id,
                    standard.enum_value_id('cod', 'action_type', 'PhoneCall'),
                    _content
                );
            END IF;
            UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Act') WHERE id = _row.id;
        END IF;
        RETURN TRUE;
    END IF;

    RETURN FALSE;
--EXCEPTION
--    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod_v2.process_hm_update(xml) OWNER TO postgres;

--
-- Name: FUNCTION process_hm_update(xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION process_hm_update(xml) IS 'DR: Process HM Issues state for COD (2012-02-07)';


--
-- PostgreSQL database dump complete
--

