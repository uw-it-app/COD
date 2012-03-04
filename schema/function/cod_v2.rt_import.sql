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
-- Name: rt_import(xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION rt_import(xml) RETURNS xml
    LANGUAGE plpgsql
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
    _aliases    integer[];
    _i          integer;
    _j          integer;
    _item       cod.item%ROWTYPE;
    _unlock     boolean     := FALSE;
    _new        boolean     := FALSE;
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
        _aliases := xpath.get_varchar_array('/Incident/AliasIds/AliasId', v_xml)::integer[];
        SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
        IF _item.id IS NULL THEN
            SELECT * INTO _item FROM cod.item WHERE ARRAY[rt_ticket]::integer[] <@ _aliases LIMIT 1;
            IF _item.id IS NOT NULL THEN
                UPDATE cod.item SET rt_ticket = xpath.get_integer('/Incident/Id', v_xml) WHERE id = _item.id;
            ELSEIF xpath.get_varchar('/Incident/Type', v_xml) <> 'Incident' THEN
                CONTINUE;
                -- do nothing.
            ELSEIF xpath.get_timestamptz('/Incident/Created', _incident) < now() - '1 minute'::interval THEN
                INSERT INTO cod.item (rt_ticket, subject, state_id, itil_type_id, support_model_id, severity, workflow_lock) VALUES (
                    xpath.get_integer('/Incident/Id', _incident),
                    xpath.get_varchar('/Incident/Subject', _incident),
                    standard.enum_value_id('cod', 'state', 'Tier2'),
                    standard.enum_value_id('cod', 'itil_type', 'Incident'),
                    standard.enum_value_id('cod', 'support_model', ''),
                    xpath.get_integer('/Incident/Severity', _incident),
                    TRUE
                );
                _unlock := TRUE;
                _new    := TRUE;
                SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
                IF NOT FOUND THEN
                    CONTINUE;
                END IF;
            ELSE
                CONTINUE;
            END IF;
        END IF;
        IF _item.workflow_lock IS FALSE THEN
            UPDATE cod.item SET workflow_lock = TRUE WHERE id = _item.id;
        END IF;
        -- Merge in other tickets
        PERFORM cod.item_merge(_item.id, id, FALSE) FROM cod.item WHERE ARRAY[rt_ticket]::integer[] <@ _aliases;

        -- check status (?reset closed if closed?)
        _escs   := xpath('/Incident/Escalations/Escalation', _incident);
        _count2 := array_upper(_escs, 1);
        IF _count2 IS NOT NULL THEN
            -- foreach escalation
            FOR _j in 1.._count2 LOOP
                PERFORM cod_v2.rt_process_escalation(_item.id, _new, _escs[_j]);
            END LOOP;
        END IF;
        UPDATE cod.item SET workflow_lock = FALSE WHERE id = _item.id;
    END LOOP;
    RETURN '<Success/>'::xml;
END;
$_$;


ALTER FUNCTION cod_v2.rt_import(xml) OWNER TO postgres;

--
-- Name: FUNCTION rt_import(xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION rt_import(xml) IS 'DR: Process RT import data (2012-02-16)';


--
-- PostgreSQL database dump complete
--

