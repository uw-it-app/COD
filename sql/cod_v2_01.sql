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
        _incident := v_xml[_i];
        SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
        IF _item.id IS NULL THEN
            -- DEFER: create incident if it doesn't exist
            CONTINUE;
        END IF;
        -- check status (?reset closed if closed?)
        _escs   := xpath('/Incident/Escalations/Escalation', _incident);
        _count2 := array_upper(_escs, 1);
        IF _count2 IS NOT NULL THEN
            -- foreach escalation
            FOR _j in 1.._count2 LOOP
                _esc := incident[_j];
                SELECT * INTO _escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', _esc);
                IF _escalation.id IS NULL THEN
                    -- DEFER: create if doesn't exist
                    CONTINUE;
                END IF;
                -- set status (new/open/stalled => resolved_at = null)(else&resolved_at is null => resolved_at = now())
                IF ARRAY['new', 'open', 'stalled'] @> xpath.get_varchar('/Escalation/Status', _esc) THEN
                    _escalation.resolved_at := NULL;
                ELSEIF _escalation.resolved_at IS NULL THEN
                    _escalation.resolved_at := now();
                END IF;
                UPDATE cod.escalation SET 
                    resolved_at = _escalation.resolved_at,
                    queue = xpath.get_varchar('/Escalation/Queue', _esc),
                    owner = xpath.get_varchar('/Escalation/Owner', _esc)
                    WHERE id = _escalation.id;
            END LOOP;
        END IF;
    END LOOP;
    RETURN '<Success/>'::xml;
END;
$_$;

COMMENT ON FUNCTION cod_v2.rt_import(xml) IS 'DR: Process RT import data (2012-02-16)';


COMMIT;