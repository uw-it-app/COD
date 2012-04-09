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
-- Name: incident_state_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_state_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.incident_state_check()
    Description:  Ensure Item state is set properly
    Affects:      NEW record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    If EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND completed_at IS NULL) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Act');
    ELSEIF (NEW.closed_at IS NOT NULL) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed');
    ELSEIF (NEW.resolved_at IS NOT NULL AND NEW.ended_at IS NOT NULL) THEN -- resolved escalations and closed events
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved');
    ELSEIF (NEW.resolved_at IS NOT NULL AND NEW.started_at IS NULL) THEN -- resolved esc no event
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved');
    ELSEIF (NEW.escalated_at IS NULL AND NEW.ended_at IS NOT NULL) THEN -- no esc and cleared event
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved');
    ELSEIF (NEW.resolved_at IS NOT NULL AND NEW.ended_at IS NULL) THEN -- resolved escalation and open event
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Processing'); -- need an action to re-escalate
    ELSEIF (NEW.started_at IS NOT NULL AND NEW.ended_at IS NOT NULL) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Cleared');
    ELSEIF (NEW.escalated_at IS NOT NULL AND NEW.resolved_at IS NULL) THEN
        IF EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id AND esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Active')) THEN
            NEW.state_id = standard.enum_value_id('cod', 'state', 'Escalating');
        ELSE
            NEW.state_id = standard.enum_value_id('cod', 'state', 'Tier2');
        END IF;
    ELSE
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Processing');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.incident_state_check() OWNER TO postgres;

--
-- Name: FUNCTION incident_state_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_state_check() IS 'DR: Ensure Item state is set properly (2012-02-26)';


--
-- PostgreSQL database dump complete
--

