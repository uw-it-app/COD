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
-- Name: event_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION event_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.event_check()
    Description:  Ensure event is valid
    Affects:      cod.event row the trigger executes on
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    IF NOT hm_v1.valid_oncall(NEW.contact) THEN
        NEW.contact := NULL;
    END IF;
    IF NOT hm_v1.valid_oncall(NEW.oncall_primary) THEN
        NEW.oncall_primary := NULL;
    END IF;
    IF NOT hm_v1.valid_oncall(NEW.oncall_alternate) THEN
        NEW.oncall_alternate := NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.event_check() OWNER TO postgres;

--
-- Name: FUNCTION event_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION event_check() IS 'DR: Ensure event is valid (2012-02-16)';


--
-- PostgreSQL database dump complete
--

