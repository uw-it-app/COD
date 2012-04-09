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
-- Name: action_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION action_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.action_check()
    Description:  Ensures data is set properly
    Affects:      NEW cod.action row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    IF NEW.completed_at IS NULL THEN
        NEW.completed_by := NULL;
    ELSE
        NEW.completed_by := standard.get_uwnetid();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.action_check() OWNER TO postgres;

--
-- Name: FUNCTION action_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION action_check() IS 'DR: Ensures data is set properly (2012-02-24)';


--
-- PostgreSQL database dump complete
--

