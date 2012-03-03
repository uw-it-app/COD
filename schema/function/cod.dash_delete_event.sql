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
-- Name: dash_delete_event(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dash_delete_event(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.dash_delete_event(integer)
    Description:  Sends a delete message to the appropriate system to eliminate alert from dash
    Affects:      nothing in the database
    Arguments:    integer: event id
    Returns:      boolean
*/
DECLARE
    v_id        ALIAS FOR $1;
    _row        cod.event%ROWTYPE;
    _source     varchar;
BEGIN
    SELECT * into _row FROM cod.event WHERE id = v_id;
    IF NOT FOUND THEN
        RETURN FALSE;
    ELSEIF _row.host IS NULL OR _row.component IS NULL THEN
        RETURN FALSE;
    END IF;

    _source := (SELECT name FROM cod.source WHERE id = _row.source_id);
    IF _source = 'acc' THEN
        RETURN dash_v1.injector_del(_row.host, _row.component);
    ELSEIF _source = 'prox' THEN
        RETURN dash_v1.prox_del(_row.host, _row.component);
    END IF;
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod.dash_delete_event(integer) OWNER TO postgres;

--
-- Name: FUNCTION dash_delete_event(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dash_delete_event(integer) IS 'DR: Sends a delete message to the appropriate system to eliminate alert from dash (2012-02-24)';


--
-- PostgreSQL database dump complete
--

