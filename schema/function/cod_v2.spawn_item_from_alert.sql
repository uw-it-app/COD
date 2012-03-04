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
-- Name: spawn_item_from_alert(xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION spawn_item_from_alert(xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.spawn_item_from_alert(xml)
    Description:  Create an incident from an alert
    Affects:      Inserts Event and Item records
    Arguments:    xml: Event XML
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _row        record;
    _netid      varchar;
    _ticket     integer;
    _host       varchar;
    _comp       varchar;
    _model      varchar;
    _smid       integer;
    _contact    varchar;
    _hostpri    varchar;
    _hostalt    varchar;
    _msg        varchar;
    _lmsg       varchar;
    _source     varchar;
    _source_id  integer;
    _subject    varchar;
    _addtags    varchar;
    _cc         varchar;
    _nohelp     varchar;
    _helpurl    varchar;
    _starts     timestamptz;
    _severity   smallint;
    _item_id    integer;
    _event_id   integer;
BEGIN
    -- read event data
    
    _netid := xpath.get_varchar('/Event/Netid', v_xml);
    -- can this netid spawn?
    IF cod_v2.can_spawn(_netid) IS TRUE THEN
        -- if yes set uwit.uwnetid
        EXECUTE 'SET LOCAL uwit.uwnetid = ' || quote_literal(_netid);
    ELSE
        -- else return rejection
        RAISE EXCEPTION 'User is not authorized to create incidents via COD: %', _netid;
    END IF;

    _ticket := xpath.get_integer('/Event/Alert/Ticket', v_xml);         -- check
    -- IF ticket is active then return that ticket's info else continue.
    IF _ticket IS NOT NULL AND _ticket > 0 THEN
        SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate WHERE rt_ticket = _ticket LIMIT 1;
        IF _row.item_id IS NOT NULL THEN
            RETURN xmlelement(name "Incident",
                    xmlelement(name "Id", _row.item_id),
                    xmlelement(name "Ticket", _row.rt_ticket)
            );
        END IF;
    END IF;

    _host := xpath.get_varchar('/Event/Alert/ProblemHost', v_xml);      -- subject(item); (event)
    _comp := xpath.get_varchar('/Event/Alert/Component', v_xml);        -- subject(item); (event)
    _model := upper(xpath.get_varchar('/Event/SupportModel', v_xml));   -- (item); (event)
    _contact := xpath.get_varchar('/Event/Alert/Contact', v_xml);       -- (event)
    _hostpri := xpath.get_varchar('/Event/OnCall', v_xml);        -- (event)
    _hostalt := xpath.get_varchar('/Event/AltOnCall', v_xml);     -- (event)
    _msg := xpath.get_varchar('/Event/Alert/Msg', v_xml);               -- for ticket
    _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', v_xml);          -- for ticket

    _source := COALESCE(xpath.get_varchar('/Event/Source', v_xml), xpath.get_varchar('/Event/Alert/Flavor', v_xml));
    _source_id := COALESCE(standard.enum_value_id('cod', 'source', _source), 1);
    
    _subject := COALESCE(xpath.get_varchar('/Event/Subject', v_xml), _host || ': ' || _comp); -- subject(item)
    _addtags := xpath.get_varchar('/Event/AddTags', v_xml);             -- ticket
    _cc := xpath.get_varchar('/Event/Cc', v_xml);                       -- ticket
    _nohelp := xpath.get_varchar('/Event/Nohelp', v_xml);               -- if true don't prompt for help text
    _helpurl := xpath.get_varchar('/Event/Helpurl', v_xml);             -- (event)
    _starts := now() - (COALESCE(xpath.get_integer('/Event/VisTime', v_xml), 0)::varchar || ' seconds')::interval; -- (item)

    _smid = standard.enum_value_id('cod', 'support_model', _model);        -- (item); (event)
    _severity = 3;                                                      -- (item); (event)
    IF _model = 'A' OR _model = 'B' THEN
        _severity = 2;
    END IF;

    -- check to see if exact duplicate
    SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate 
        WHERE host = _host AND component = _comp ORDER BY item_id ASC LIMIT 1;
    IF _row.item_id IS NOT NULL THEN
        RETURN xmlelement(name "Incident",
                xmlelement(name "Id", _row.item_id),
                xmlelement(name "Ticket", _row.rt_ticket)
        );
    END IF;
    -- check to see if similar duplicate to append alert to the same ticket
/*
    SELECT * INTO _row FROM cod.item_event_duplicate WHERE host = _host AND contact = _contact ORDER BY item_id ASC LIMIT 1;
    IF _row.item_id IS NOT NULL THEN
        INSERT INTO cod.event (item_id, host, component, support_model_id, severity, contact, 
                               oncall_primary, oncall_alternate, content)
            VALUES (_row.item_id, _host, _comp, _smid, _severity, _contact, _hostpri, _hostalt, v_xml);
        RETURN xmlelement(name "Incident",
                xmlelement(name "Id", _row.item_id),
                xmlelement(name "Ticket", _row.rt_ticket)
        );
    END IF;
*/
    -- insert new (incident) item 
    _item_id := nextval('cod.item_id_seq'::regclass);
    INSERT INTO cod.item (id, subject, state_id, itil_type_id, support_model_id, severity, stage_id, started_at, workflow_lock) VALUES (
        _item_id,
        _subject,
        standard.enum_value_id('cod', 'state', 'Processing'),
        standard.enum_value_id('cod', 'itil_type', 'Incident'),
        _smid,
        _severity,
        standard.enum_value_id('cod', 'stage', 'Identification'),
        _starts,
        TRUE
    );
    -- create alert
    _event_id := nextval('cod.event_id_seq'::regclass);
    INSERT INTO cod.event (id, item_id, host, component, support_model_id, severity, contact, 
                           oncall_primary, oncall_alternate, source_id, start_at, content)
        VALUES (_event_id, _item_id, _host, _comp, _smid, _severity, _contact, 
                _hostpri, _hostalt, _source_id, _starts, replace(v_xml::text::varchar, E'<?xml version="1.0"?>\n', ''));
    -- get ticket # for item
    _ticket := cod.create_incident_ticket_from_event(_event_id); 
    -- update item for workflow
    UPDATE cod.item SET 
        rt_ticket     = _ticket, stage_id = standard.enum_value_id('cod', 'stage', 'Initial Diagnosis'), 
        workflow_lock = FALSE
        WHERE id  = _item_id;
    -- IW trigger should execute;
    RETURN xmlelement(name "Incident",
            xmlelement(name "Id", _item_id),
            xmlelement(name "Ticket", _ticket)
    );
END;
$_$;


ALTER FUNCTION cod_v2.spawn_item_from_alert(xml) OWNER TO postgres;

--
-- Name: FUNCTION spawn_item_from_alert(xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION spawn_item_from_alert(xml) IS 'DR: Create an incident from an alert (2012-02-26)';


--
-- PostgreSQL database dump complete
--

