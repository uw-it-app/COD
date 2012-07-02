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
-- Name: escalation_dash_update(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_dash_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.escalation_dash_update()
    Description:  Update dash with escalation ownership
    Affects:      Sends data to Dash
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    PERFORM cod.dash_update_event(id) FROM cod.event WHERE item_id = NEW.item_id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN RETURN NEW;
END;
$$;


ALTER FUNCTION cod.escalation_dash_update() OWNER TO postgres;

--
-- Name: FUNCTION escalation_dash_update(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_dash_update() IS 'DR: Update dash with escalation ownership (2012-06-28)';


--
-- PostgreSQL database dump complete
--

