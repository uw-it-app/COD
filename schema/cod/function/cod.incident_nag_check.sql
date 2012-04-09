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
-- Name: incident_nag_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_nag_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.incident_nag_check()
    Description:  Ensure the nag_next time is properly set or unset
    Affects:      Active row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    IF (SELECT nag FROM cod.support_model WHERE id = NEW.support_model_id) AND
        EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id AND esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Owned'))
    THEN
        IF NEW.nag_next IS NULL THEN
            NEW.nag_next := now() + NEW.nag_interval::interval;
        END IF;
    ELSE
        NEW.nag_next := NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.incident_nag_check() OWNER TO postgres;

--
-- Name: FUNCTION incident_nag_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_nag_check() IS 'DR: Ensure the nag_next time is properly set or unset (2012-02-22)';


--
-- PostgreSQL database dump complete
--

