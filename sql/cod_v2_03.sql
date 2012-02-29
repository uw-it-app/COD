BEGIN;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.rt_process_escalation(integer, xml) RETURNS xml
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod_v2.rt_process_escalation(integer, xml)
    Description:  Process rt update on an escalation
    Affects:      
    Arguments:    integer: Item Id
                  xml: Escalation XML Representation
    Returns:      xml
*/
DECLARE
    v_item_id       ALIAS FOR $1;
    v_xml           ALIAS FOR $2;
    _aliases        integer[];
    _status         varchar;
    _escalation     cod.escalation%ROWTYPE;
BEGIN
    _aliases := xpath.get_varchar_array('/Escalation/AliasIds/AliasId', v_xml)::integer[];
    RAISE NOTICE 'ESCALATION, %', v_xml::varchar;
    SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', v_xml);
    IF _escalation.id IS NULL THEN
        RAISE NOTICE 'ESCALATION does not exist';
        --Check to see if under an alias
        SELECT * INTO _escalation FROM cod.escalation WHERE ARRAY[rt_ticket]::integer[] <@ _aliases LIMIT 1;
        IF _escalation.id IS NOT NULL THEN
            UPDATE cod.escalation SET rt_ticket = xpath.get_integer('/Escalation/Id', v_xml) WHERE id = _escalation.id;

        ELSEIF xpath.get_timestamptz('/Escalation/Created', v_xml) < now() - '1 minute'::interval THEN
            RAISE NOTICE 'ESCALATION creating';
            INSERT INTO cod.escalation (item_id, rt_ticket, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at) VALUES (
                v_item.id,
                xpath.get_integer('/Escalation/Id', v_xml),
                standard.enum_value_id('cod', 'esc_state', 'Passive'),
                standard.enum_value_id('cod', 'page_state', 'Passive'),
                'n/a',
                xpath.get_varchar('/Escalation/Queue', v_xml),
                xpath.get_varchar('/Escalation/Owner', v_xml),
                xpath.get_timestamptz('/Escalation/Created', v_xml)
            );
            SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', v_xml);
            IF NOT FOUND THEN
                RAISE NOTICE 'ESCALATION creation failed';
                CONTINUE;
            END IF;
        ELSE
            RAISE NOTICE 'ESCALATION skipping creation, %, %', xpath.get_timestamptz('/Escalation/Created', _incident), xpath.get_timestamptz('/Escalation/Created', _incident) < now() - '1 minute'::interval;
            CONTINUE;
        END IF;
    END IF;
    -- set severity from RT???
    _status := xpath.get_varchar('/Escalation/Status', v_xml);
    IF ARRAY['new', 'open', 'stalled']::varchar[] @> ARRAY[_status] THEN
        _escalation.resolved_at := NULL;
    ELSE
        IF _escalation.resolved_at IS NULL THEN
            _escalation.resolved_at  := now();
        END IF;
        IF _status = 'rejected' THEN
            _escalation.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Rejected');
        ELSE
            _escalation.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Resolved');
        END IF;
    END IF;
    UPDATE cod.escalation SET 
        resolved_at = _escalation.resolved_at,
        queue = xpath.get_varchar('/Escalation/Queue', v_xml),
        owner = xpath.get_varchar('/Escalation/Owner', v_xml),
        esc_state_id = _escalation.esc_state_id
        WHERE id = _escalation.id;
    --foreach aliasid, if it exists then set status to merged
    UPDATE cod.escalation 
        SET esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Merged'),
            resolved_at = now()
        WHERE ARRAY[rt_ticket]::integer[] <@ _aliases;
    RETURN '<Processed/>';
END;
$_$;

COMMENT ON FUNCTION cod_v2.rt_process_escalation(integer, xml) IS 'DR: Process rt update on an escalation (2012-02-29)';


/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.rt_import(xml) RETURNS xml
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod_v2.rt_import(xml)
    Description:  Process RT import data
    Affects:      Any ticket/escalation
    Arguments:    xml: Data from RT
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _count      integer;
    _count2     integer;
    _incidents  xml[];
    _incident   xml;
    _escs       xml[];
    _status     varchar;
    _i          integer;
    _j          integer;
    _item       cod.item%ROWTYPE;
    _output     varchar;
BEGIN
    _incidents := xpath('/Incidents/Incident', v_xml);
    _count     := array_upper(_incidents, 1);
    IF _count IS NULL THEN
        RETURN '<Success/>'::xml;
    END IF;
    -- foreach incident
    FOR _i in 1.._count LOOP
        _incident := _incidents[_i];
        SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
        IF _item.id IS NULL THEN
            IF xpath.get_timestamptz('/Incident/Created', _incident) < now() - '1 minute'::interval THEN
                INSERT INTO cod.item (rt_ticket, subject, state_id, itil_type_id, support_model_id, severity, workflow_lock) VALUES (
                    xpath.get_integer('/Incident/Id', _incident),
                    xpath.get_varchar('/Incident/Subject', _incident),
                    standard.enum_value_id('cod', 'state', 'Tier2'),
                    standard.enum_value_id('cod', 'itil_type', 'Incident'),
                    standard.enum_value_id('cod', 'support_model', ''),
                    xpath.get_integer('/Incident/Severity', _incident),
                    TRUE
                );
                SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
                IF NOT FOUND THEN
                    CONTINUE;
                END IF;
            ELSE
                CONTINUE;
            END IF;
        END IF;
        -- check status (?reset closed if closed?)
        _escs   := xpath('/Incident/Escalations/Escalation', _incident);
        _count2 := array_upper(_escs, 1);
        IF _count2 IS NOT NULL THEN
            -- foreach escalation
            FOR _j in 1.._count2 LOOP
                PERFORM cod_v2.rt_process_escalation(_item.id, _escs[_j]);
            END LOOP;
        END IF;
        IF _item.workflow_lock IS TRUE THEN
            UPDATE cod.item SET workflow_lock = FALSE WHERE id = _item.id;
        END IF;
    END LOOP;
    RETURN '<Success/>'::xml;
END;
$_$;

COMMENT ON FUNCTION cod_v2.rt_import(xml) IS 'DR: Process RT import data (2012-02-16)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.process_hm_update(xml) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
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

COMMENT ON FUNCTION cod_v2.process_hm_update(xml) IS 'DR: Process HM Issues state for COD (2012-02-07)';


COMMIT;