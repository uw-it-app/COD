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
-- Name: remove_esc_actions(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION remove_esc_actions(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.remove_esc_actions(integer)
    Description:  Remove any actions associated with the provided escalation id
    Affects:      All incomplete actions associated with the provided escalation id
    Arguments:    integer: escalation_id
    Returns:      boolean
*/
DECLARE
    v_esc_id    ALIAS FOR $1;
BEGIN
    UPDATE cod.action SET completed_at = now(), successful = false WHERE escalation_id = v_esc_id AND completed_at IS NULL;
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION cod.remove_esc_actions(integer) OWNER TO postgres;

--
-- Name: FUNCTION remove_esc_actions(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION remove_esc_actions(integer) IS 'DR: Remove any actions associated with the provided escalation id (2012-02-09)';


--
-- PostgreSQL database dump complete
--

