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
-- Name: escalation_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.escalation_check()
    Description:  Ensures escalation data is consistent
    Affects:      Single cod.escalation row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    
    IF NEW.resolved_at IS NOT NULL THEN
        IF standard.enum_id_value('cod', 'esc_state', NEW.esc_state_id) NOT IN ('Resolved', 'Rejected', 'Merged') THEN
            NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Resolved');
        END IF;
        RETURN NEW;
    ELSE
        NEW.resolved_at := NULL;
    END IF;

    IF NEW.owner <> 'nobody' THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Owned');
        IF NEW.owned_at IS NULL THEN
            NEW.owned_at := now();
        END IF;
    ELSEIF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Failed') THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Failed');
    ELSEIF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Closed') OR
        NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Cancelled') OR
        NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Passive')
    THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Passive');
    ELSE
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Active');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.escalation_check() OWNER TO postgres;

--
-- Name: FUNCTION escalation_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_check() IS 'DR: Ensures escalation data is consistent (2012-02-04)';


--
-- PostgreSQL database dump complete
--

