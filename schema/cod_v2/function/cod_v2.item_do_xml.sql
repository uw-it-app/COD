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
-- Name: item_do_xml(integer, xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_do_xml(integer, xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.item_do_xml(integer, xml)
    Description:  Perform actions on an item
    Affects:      An item and associated elements
    Arguments:    xml: XML representation of the action to perform
    Returns:      xml
*/
DECLARE
    v_id        ALIAS FOR $1;
    v_xml       ALIAS FOR $2;
    _id         integer;
    _type       varchar;
    _message    varchar;
    _msgType    varchar     := 'comment';
    _msgToSubs  varchar     := 'open';
    _success    boolean;
    _payload    varchar     := '';
    _owner      varchar;
    _page       varchar;
    _oncall     varchar;
    _number     numeric;
    _period     varchar;
    _row        cod.item%ROWTYPE;
BEGIN
    SELECT * INTO _row FROM cod.item WHERE id = v_id;
    IF _row.id IS NULL THEN
        RETURN NULL;
    END IF;
    _id      := xpath.get_integer('/Item/Do/Id', v_xml);
    _type    := xpath.get_varchar('/Item/Do/Type', v_xml);
    _message := xpath.get_varchar('/Item/Do/Message', v_xml);
    IF _type = 'Update' THEN
        UPDATE cod.item 
            SET subject = xpath.get_varchar('/Item/Do/Subject', v_xml),
                reference_no = xpath.get_varchar('/Item/Do/RefNo', v_xml),
                severity = xpath.get_integer('/Item/Do/Severity', v_xml),
                support_model_id = standard.enum_value_id('cod', 'support_model', xpath.get_varchar('/Item/Do/SupportModel', v_xml))
            WHERE id = v_id;
        --  itil_type_id = standard.enum_value_id('cod', 'itil_type', xpath.get_varchar('/Item/Do/ITILType', v_xml))    
    ELSEIF _type = 'Close' THEN
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = TRUE
            WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close');
        UPDATE cod.item SET workflow_lock = FALSE, closed_at = now() WHERE id = v_id;
        _msgType   := 'correspond';
        _msgToSubs := 'none';
        _payload   := E'Status: resolved\n';
    ELSEIF _type = 'Clear' THEN
        UPDATE cod.event SET end_at = now() WHERE item_id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = v_id AND completed_at IS NULL AND 
                action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
    ELSEIF _type = 'Reactivate' THEN
        UPDATE cod.event SET end_at = NULL WHERE item_id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = v_id AND completed_at IS NULL AND 
                action_type_id = standard.enum_value_id('cod', 'action_type', 'Close');
    ELSEIF _type = 'PhoneCall' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Take' THEN
            _success := TRUE;
        ELSEIF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Fail' THEN
            _success := FALSE;
        END IF;
        IF _success IS TRUE THEN
            UPDATE cod.action SET successful = TRUE, completed_at = now() WHERE id = _id;
        ELSE
            UPDATE cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating')
                WHERE id = (SELECT escalation_id FROM cod.action WHERE id = _id);
            IF NOT FOUND THEN
                UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Escalating')
                    WHERE id = (SELECT item_id FROM cod.action WHERE id = _id);
            END IF;
            UPDATE cod.action SET successful = FALSE, completed_at = now() WHERE id = _id;
        END IF;
        PERFORM hm_v1.update_squawk(xpath.get_integer('/Item/Do/SquawkId', v_xml), _success, _message);
        _message := NULL;
    ELSEIF _type = 'HelpText' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Clear' THEN
            UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_id;
            UPDATE cod.action SET completed_at = now(), successful = TRUE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText');
            UPDATE cod.event set end_at = now() WHERE item_id = v_id;
            UPDATE cod.item SET workflow_lock = FALSE WHERE id = v_id;
        ELSE
            UPDATE cod.action SET completed_at = now(), successful = FALSE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText');
        END IF;
        _msgToSubs := 'none';
    ELSEIF _type = 'Message' THEN
        _msgType   := xpath.get_varchar_check('/Item/Do/MsgType', v_xml, _msgType);
        _msgToSubs := xpath.get_varchar('/Item/Do/ToSubs', v_xml);
    ELSEIF _type = 'SetOwner' THEN
        _owner := xpath.get_varchar('/Item/Do/Owner', v_xml);
        IF _owner IS NOT NULL THEN
            UPDATE cod.escalation SET owner = _owner WHERE item_id = v_id AND id = xpath.get_integer('/Item/Do/EscId', v_xml);
        END IF;
    ELSEIF _type = 'Escalate' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Submit' THEN
            IF xpath.get_varchar('/Item/Do/ContactType', v_xml) = 'passive' THEN
                _page := 'Passive';
            ELSE
                _page := 'Active';
            END IF;
            _oncall := xpath.get_varchar('/Item/Do/EscalateTo', v_xml);
            IF _oncall = '_' THEN
                _oncall = xpath.get_varchar('/Item/Do/Custom', v_xml);
            END IF;
            IF NOT hm_v1.valid_oncall(_oncall) THEN
                RAISE EXCEPTION 'InvalidInput: Not a valid oncall group -- %', _oncall;
            END IF;
            INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) 
                VALUES (v_id, _oncall, standard.enum_value_id('cod', 'page_state', _page));
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Failed to create and escalation to the oncall group %', _oncall;
            ELSE
                UPDATE cod.action SET completed_at = now(), successful = TRUE
                    WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
            END IF;
        ELSE
            UPDATE cod.action SET completed_at = now(), successful = TRUE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
        END IF;
    ELSEIF _type = 'Nag' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Cancel' THEN
            _message := NULL;
        END IF;
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = _row.id;
        UPDATE cod.action SET completed_at = now(), successful = true WHERE item_id = _row.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag');
        UPDATE cod.item SET workflow_lock = FALSE, nag_next = NULL WHERE id = _row.id;
    ELSEIF _type = 'SetNag' THEN
        _number := xpath.get_numeric('/Item/Do/Number', v_xml);
        IF _number IS NULL OR _number <= 0 THEN
            RAISE EXCEPTION 'InvalidInput: Nag period number must be a positive number not "%"', _period;
        END IF;
        _period := xpath.get_varchar('/Item/Do/Period', v_xml);
        IF _period IS NULL OR NOT (ARRAY[_period]::varchar[] <@ ARRAY['minutes', 'hours', 'days']::varchar[]) THEN
            RAISE EXCEPTION 'InvalidInput: Nag period must be in minutes, hours, or days not "%"', _period;
        END IF;
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = _row.id;
        UPDATE cod.action SET completed_at = now(), successful = false WHERE item_id = _row.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag');
        UPDATE cod.item SET workflow_lock = FALSE, nag_next = NULL, nag_interval = _number::varchar || ' ' || _period WHERE id = _row.id;
    END IF;
    IF _message IS NOT NULL THEN
        _payload := E'UpdateType: ' || _msgType || E'\n'
                 || E'CONTENT: ' || _message || cod_v2.comment_post()
                 || E'ENDOFCONTENT\n'
                 || _payload;
    END IF;
    IF _payload <> '' THEN
        PERFORM rt.update_ticket(_row.rt_ticket, _payload);
        IF _msgToSubs = 'all' THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id;
        ELSEIF _msgToSubs = 'open' THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id 
                AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Resolved') 
                AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Rejected');
        ELSEIF _msgToSubs = 'owned' THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id 
                AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Owned');
        END IF;
    END IF;
    RETURN cod_v2.item_xml(v_id);
END;
$_$;


ALTER FUNCTION cod_v2.item_do_xml(integer, xml) OWNER TO postgres;

--
-- Name: FUNCTION item_do_xml(integer, xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION item_do_xml(integer, xml) IS 'DR: Perform actions on an item (2012-02-13)';


--
-- PostgreSQL database dump complete
--

