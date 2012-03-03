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
-- Name: incident_time_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_time_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.incident_time_check()
    Description:  Set time fields based on related objects
    Affects:      single cod.item record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    -- set event related times
    IF NOT EXISTS(SELECT NULL FROM cod.event WHERE item_id = NEW.id) THEN
        NEW.started_at := NULL;
        NEW.ended_at   := NULL;
    ELSE
        NEW.started_at := (SELECT min(start_at) FROM cod.event WHERE item_id = NEW.id);
        IF EXISTS(SELECT NULL FROM cod.event WHERE item_id = NEW.id AND end_at IS NULL) THEN
            NEW.ended_at  := NULL;
            NEW.closed_at := NULL;
        ELSE
            NEW.ended_at := (SELECT max(end_at) FROM cod.event WHERE item_id = NEW.id);
        END IF;
    END IF;

    -- set escalation related times
    IF NOT EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id) THEN
        NEW.escalated_at := NULL;
        NEW.resolved_at  := NULL;
    ELSE
        NEW.escalated_at := (SELECT min(escalated_at) FROM cod.escalation WHERE item_id = NEW.id);
        IF EXISTS(SELECT id FROM cod.escalation WHERE item_id = NEW.id AND resolved_at IS NULL) THEN
            NEW.resolved_at := NULL;
            NEW.closed_at   := NULL;
        ELSE
            NEW.resolved_at := (SELECT max(resolved_at) FROM cod.escalation WHERE item_id = NEW.id);
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.incident_time_check() OWNER TO postgres;

--
-- Name: FUNCTION incident_time_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_time_check() IS 'DR: Set time fields based on related objects (2012-02-02)';


--
-- PostgreSQL database dump complete
--

