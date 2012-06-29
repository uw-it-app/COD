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
-- Name: dash_update_event(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dash_update_event(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.dash_update_event(integer)
    Description:  Update Dash with Ticket/Owner data
    Affects:      nothing in the database
    Arguments:    integer: event id
    Returns:      boolean
*/
DECLARE
    v_id        ALIAS FOR $1;
    _row        cod.event%ROWTYPE;
    _source     varchar;
    _tickets    text;
    _payload    varchar;
BEGIN
    SELECT * into _row FROM cod.event WHERE id = v_id;
    IF NOT FOUND THEN
        RETURN FALSE;
    ELSEIF _row.host IS NULL OR _row.component IS NULL THEN
        RETURN FALSE;
    END IF;

    _source := (SELECT name FROM cod.source WHERE id = _row.source_id);
    IF _source = 'acc' THEN
        _tickets := (SELECT rt_ticket || ':COD' FROM cod.item where id = _row.item_id) || COALESCE( ',' ||
            (SELECT string_agg(rt_ticket || ':' || owner, ',') FROM cod.escalation WHERE item_id = _row.item_id), '');
        _payload := (xmlelement(name "Alert",
                xmlelement(name "Action", 'Updonly'),
                xmlelement(name "ProblemHost", _row.host),
                xmlelement(name "Component", _row.component),
                xmlelement(name "Ticket", _tickets)
            ))::varchar;
        RETURN dash_v1.injector(
            _payload
        );
    END IF;
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod.dash_update_event(integer) OWNER TO postgres;

--
-- Name: FUNCTION dash_update_event(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dash_update_event(integer) IS 'DR: Update Dash with Ticket/Owner data (2012-06-28)';


--
-- PostgreSQL database dump complete
--

