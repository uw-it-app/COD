BEGIN;

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
    _esc        xml;
    _status     varchar;
    _i          integer;
    _j          integer;
    _item       cod.item%ROWTYPE;
    _escalation cod.escalation%ROWTYPE;
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
        END IF;
        -- check status (?reset closed if closed?)
        _escs   := xpath('/Incident/Escalations/Escalation', _incident);
        _count2 := array_upper(_escs, 1);
        IF _count2 IS NOT NULL THEN
            -- foreach escalation
            FOR _j in 1.._count2 LOOP
                _esc := _escs[_j];
                SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', _esc);
                IF _escalation.id IS NULL THEN
                    INSERT INTO cod.escalation (item_id, rt_ticket, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at) VALUES (
                        _item.id,
                        xpath.get_integer('/Escalation/Id', _esc),
                        standard.enum_value_id('cod', 'esc_state', 'Passive'),
                        standard.enum_value_id('cod', 'page_state', 'Passive'),
                        'n/a',
                        xpath.get_varchar('/Escalation/Queue', _esc),
                        xpath.get_varchar('/Escalation/Owner', _esc),
                        xpath.get_timestamptz('/Escalation/Created', _esc)
                    );
                    SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', _esc);
                    IF NOT FOUND THEN
                        CONTINUE;
                    END IF;
                END IF;
                -- set severity from RT???
                _status := xpath.get_varchar('/Escalation/Status', _esc);
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
                    queue = xpath.get_varchar('/Escalation/Queue', _esc),
                    owner = xpath.get_varchar('/Escalation/Owner', _esc),
                    esc_state_id = _escalation.esc_state_id
                    WHERE id = _escalation.id;
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

CREATE OR REPLACE FUNCTION cod_v2.nag_check() RETURNS xml
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod_v2.nag_check()
    Description:  Update items where nag may be needed
    Affects:      cod.item where nag may be needed
    Arguments:    none
    Returns:      xml
*/
DECLARE
    _count      integer;
BEGIN
    UPDATE cod.item AS item SET modified_at = now() WHERE nag_next < now() AND NOT EXISTS(SELECT NULL FROM cod.action WHERE action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag') AND completed_at IS NULL AND item_id = item.id);
    GET DIAGNOSTICS _count = ROW_COUNT;
    RETURN ('<Updated>' || _count::varchar || '</Updated>')::xml;
EXCEPTION
    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION cod_v2.nag_check() IS 'DR: Update items where nag may be needed (2012-02-23)';


COMMIT;