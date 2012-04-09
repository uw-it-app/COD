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
-- Name: incident_stage_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_stage_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.incident_stage_check()
    Description:  Ensure Item ITIL Stage is set properly
    Affects:      New record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    IF NEW.closed_at IS NOT NULL THEN -- Incident is closed
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Closure');
    ELSEIF NEW.resolved_at IS NOT NULL THEN -- Escalations resolved
        IF NEW.ended_at IS NOT NULL OR NEW.started_at IS NULL THEN -- Event cleared or no event
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Closure');
        ELSE -- Open event
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Investigation and Diagnosis');
        END IF;
    ELSEIF NEW.escalated_at IS NOT NULL THEN -- open Escalations
        IF NEW.ended_at IS NOT NULL THEN -- Event cleared 
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Resolution and Recovery');
        ELSEIF EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id AND resolved_at IS NULL AND owned_at IS NULL) THEN -- unowned escalation
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Functional Escalation');
        ELSE -- owned escalation
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Investigation and Diagnosis');
        END IF;
    ELSEIF NEW.ended_at IS NOT NULL THEN -- No escalation, closed event
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Closure');
    ELSEIF EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'state', 'HelpText')) 
    THEN -- active helptext action
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Investigation and Diagnosis');
    ELSEIF NEW.rt_ticket IS NULL THEN
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Logging');
    ELSE
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Initial Diagnosis');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.incident_stage_check() OWNER TO postgres;

--
-- Name: FUNCTION incident_stage_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_stage_check() IS 'DR: Ensure Item ITIL Stage is set properly (2012-02-26)';


--
-- PostgreSQL database dump complete
--

