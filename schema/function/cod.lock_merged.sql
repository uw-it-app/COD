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
-- Name: lock_merged(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION lock_merged() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.lock_merged()
    Description:  Ensure that merged items are workflow_locked
    Affects:      
    Arguments:    
    Returns:      trigger
*/
DECLARE
BEGIN
    NEW.workflow_lock := TRUE;
    IF NEW.closed_at IS NULL THEN
        NEW.closed_at := now();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.lock_merged() OWNER TO postgres;

--
-- Name: FUNCTION lock_merged(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION lock_merged() IS 'DR: Ensure that merged items are workflow_locked (2012-03-01)';


--
-- PostgreSQL database dump complete
--

