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
-- Name: event_check_helptext(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION event_check_helptext() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.event_check_helptext()
    Description:  Insert trigger to set default helptext if none present
    Affects:      NEW current record
    Arguments:    none
    Returns:      NEW (current record)
*/
DECLARE
BEGIN
    IF NEW.helptext IS NULL AND NEW.component <> '' THEN
        NEW.helptext := 'https://wiki.cac.washington.edu/display/monhelp/component-' ||
            regexp_replace(regexp_replace(NEW.component, E'\\(.*\\)', '', 'g'), E'[\\:\\,\\@ ]', '_', 'g');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.event_check_helptext() OWNER TO postgres;

--
-- Name: FUNCTION event_check_helptext(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION event_check_helptext() IS 'DR: Insert trigger to set default helptext if none present (2011-10-20)';


--
-- PostgreSQL database dump complete
--

