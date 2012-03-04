BEGIN;


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
-- Name: create_incident_ticket_from_event(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION create_incident_ticket_from_event(integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.create_incident_ticket_from_event(integer)
    Description:  Create an RT Ticket from an event
    Affects:      Creates an RT ticket
    Arguments:    integer: alert id to base the incident ticket on
    Returns:      integer: RT ticket number
*/
DECLARE
    v_event_id  ALIAS FOR $1;
    _sep        varchar := E'------------------------------------------\n';
    _row        record;
    _content    xml;
    _msg        varchar;
    _lmsg       varchar;
    _subject    varchar;
    _addtags    varchar;
    _cc         varchar;
    _starts     timestamptz;
    _tags       varchar[];
    _message    varchar;
    _payload    varchar;
BEGIN
    SELECT * INTO _row FROM cod.event WHERE id = v_event_id;
    IF _row.id IS NULL THEN
        RAISE EXCEPTION 'InternalError: Event does not exist to create indicent ticket: %', v_event_id;
    END IF;
    _content = _row.content::xml;

    _msg := xpath.get_varchar('/Event/Alert/Msg', _content);
    _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', _content);
    _subject := COALESCE(xpath.get_varchar('/Event/Subject', _content), _row.host || ': ' || _row.component, _row.host, _row.component, 'Undefined Subject');
    _addtags := xpath.get_varchar('/Event/AddTags', _content);
    _cc := COALESCE(xpath.get_varchar('/Event/Cc', _content), '');

    _tags := regexp_split_to_array(_addtags, E'[, ]+');
    _tags := array2.ucat(_tags, appconfig.get('COD_TAG', ''));

    _message := '';
    IF _row.host IS NOT NULL THEN
        _tags := array2.ucat(_tags, _row.host);
        _message := _message || 'Hostname: ' || _row.host || E'\n';
    END IF;
    IF _row.component IS NOT NULL THEN
        _tags := array2.ucat(_tags, _row.component);
        _message := _message || 'Component: ' || _row.component || E'\n';
    END IF;
    IF _msg IS NOT NULL THEN
        _message := _message || _sep || _msg || E'\n';
    END IF;
    IF _lmsg IS NOT NULL OR _lmsg <> _msg THEN
        _message := _message || _sep || _lmsg || E'\n';
    END IF;
    _message := _message || _sep ||
        'Created By: ' || _row.modified_by || E'\n' ||
        E'UW Information Technology - Computer Operations\n' ||
        E'Email: copstaff@uw.edu\n' ||
        E'Phone: 206-685-1270\n';

    _payload := 'Subject: ' || _subject || E'\n' ||
                E'Queue: ' || appconfig.get('INCIDENT_QUEUE', '') || E'\n' ||
                'Severity: ' || _row.severity::varchar ||  E'\n' ||
                'Tags: ' || array_to_string(_tags, ' ') || E'\n' ||
                'Starts: ' || _row.start_at::varchar || E'\n' ||
                'Cc: ' || _cc  || E'\n' ||
                'ReferredToBy: https://' || appconfig.get('SSGAPP_ALIAS', '') || '/cod/item/Id/' || _row.item_id::varchar || E'\n' ||
                'Content: ' || _message ||
                E'ENDOFCONTENT\nCF-TicketType: Incident\n';

    RETURN rt.create_ticket(_payload);
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$_$;


ALTER FUNCTION cod.create_incident_ticket_from_event(integer) OWNER TO postgres;

--
-- Name: FUNCTION create_incident_ticket_from_event(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION create_incident_ticket_from_event(integer) IS 'DR: Create an RT Ticket from an event (2011-10-21)';


--
-- PostgreSQL database dump complete
--

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
-- Name: dash_delete_event(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dash_delete_event(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.dash_delete_event(integer)
    Description:  Sends a delete message to the appropriate system to eliminate alert from dash
    Affects:      nothing in the database
    Arguments:    integer: event id
    Returns:      boolean
*/
DECLARE
    v_id        ALIAS FOR $1;
    _row        cod.event%ROWTYPE;
    _source     varchar;
BEGIN
    SELECT * into _row FROM cod.event WHERE id = v_id;
    IF NOT FOUND THEN
        RETURN FALSE;
    ELSEIF _row.host IS NULL OR _row.component IS NULL THEN
        RETURN FALSE;
    END IF;

    _source := (SELECT name FROM cod.source WHERE id = _row.source_id);
    IF _source = 'acc' THEN
        RETURN dash_v1.injector_del(_row.host, _row.component);
    ELSEIF _source = 'prox' THEN
        RETURN dash_v1.prox_del(_row.host, _row.component);
    END IF;
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod.dash_delete_event(integer) OWNER TO postgres;

--
-- Name: FUNCTION dash_delete_event(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dash_delete_event(integer) IS 'DR: Sends a delete message to the appropriate system to eliminate alert from dash (2012-02-24)';


--
-- PostgreSQL database dump complete
--

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
-- Name: dbcache_get(character varying, timestamp with time zone); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dbcache_get(character varying, timestamp with time zone) RETURNS character varying
    LANGUAGE sql
    AS $_$
/*  Function:     cod.dbcache_get(varchar, timestamptz)
    Description:  Get dbcache record with the provided name and at or after the provided time
    Affects:      nothing
    Arguments:    varchar: name of record
                  timestamptz: time <= timekey of record
    Returns:      varchar
*/
    SELECT content FROM cod.dbcache WHERE name = $1 and timekey >= $2;
$_$;


ALTER FUNCTION cod.dbcache_get(character varying, timestamp with time zone) OWNER TO postgres;

--
-- Name: FUNCTION dbcache_get(character varying, timestamp with time zone); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dbcache_get(character varying, timestamp with time zone) IS 'DR: Get dbcache record with the provided name and at or after the provided time (DATE)';


--
-- PostgreSQL database dump complete
--

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
-- Name: dbcache_update(character varying, character varying, timestamp with time zone); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dbcache_update(character varying, character varying, timestamp with time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.dbcache_update(varchar, varchar, timestamptz)
    Description:  Update or insert a dbcache record
    Affects:      Updates or Inserts a dbcache record
    Arguments:    varchar: name of the record
                  varchar: content of the record
                  timestamptz: timekey of the record
    Returns:      boolean
*/
DECLARE
    v_name      ALIAS FOR $1;
    v_content   ALIAS FOR $2;
    v_timekey   ALIAS FOR $3;
    _timekey    timestamptz;
BEGIN
    IF v_timekey IS NULL THEN
        _timekey := now();
    ELSE
        _timekey := v_timekey;
    END IF;

    UPDATE cod.dbcache SET content = v_content, timekey = _timekey WHERE name = v_name;
    IF NOT FOUND THEN
        INSERT INTO cod.dbcache (name, content, timekey) VALUES (v_name, v_content, _timekey);
    END IF;
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION cod.dbcache_update(character varying, character varying, timestamp with time zone) OWNER TO postgres;

--
-- Name: FUNCTION dbcache_update(character varying, character varying, timestamp with time zone); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dbcache_update(character varying, character varying, timestamp with time zone) IS 'DR: Update or insert a dbcache record (2012-02-26)';


--
-- PostgreSQL database dump complete
--

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
-- Name: escalation_build(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_build() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.escalation_build()
    Description:  trigger to run on Building escalations
    Affects:      NEW escalation record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _sep        varchar := E'------------------------------------------\n';
    _item       cod.item%ROWTYPE;
    _event      cod.event%ROWTYPE;
    _payload    varchar;
    _content    xml;
    _msg        varchar;
    _lmsg       varchar;
    _message    varchar;
    _tags       varchar[];
BEGIN
    -- get queue from H&M
    IF NEW.queue IS NULL THEN
        NEW.queue := hm_v1.get_oncall_queue(NEW.oncall_group);
        IF NEW.queue IS NULL THEN
            RETURN NULL;
        END IF;
    END IF;
    IF NEW.rt_ticket IS NULL THEN
        -- create ticket
        SELECT * INTO _item FROM cod.item WHERE id = NEW.item_id;
        SELECT * INTO _event FROM cod.event WHERE item_id = NEW.item_id ORDER BY id ASC LIMIT 1;
       _content = _event.content::xml;

        _msg  := xpath.get_varchar('/Event/Alert/Msg', _content);
        _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', _content);

        _tags := array2.ucat(_tags, appconfig.get('COD_TAG', ''));

        _message := '';
        IF _event.host IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.host);
            _message := _message || 'Hostname: ' || _event.host || E'\n';
        END IF;
        IF _event.component IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.component);
            _message := _message || 'Component: ' || _event.component || E'\n';
        END IF;
        IF _msg IS NOT NULL THEN
            _message := _message || _sep || _msg || E'\n';
        END IF;
        IF _lmsg IS NOT NULL OR _lmsg <> _msg THEN
            _message := _message || _sep || _lmsg || E'\n';
        END IF;

        _payload := 'Subject: ' || _item.subject || E'\n' ||
                    'Queue: ' || NEW.queue || E'\n' ||
                    'Severity: ' || _item.severity::varchar ||  E'\n' ||
                    'Tags: ' || array_to_string(_tags, ' ') || E'\n' ||
                    'Super: ' || _item.rt_ticket || E'\n' ||
                    'Content: ' || _message || E'\n' ||
                    E'ENDOFCONTENT\nCF-TicketType: Incident\n';
        
        NEW.rt_ticket    := rt.create_ticket(_payload);
    END IF;
    IF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Passive') THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Passive');
    ELSE
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Active');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.escalation_build() OWNER TO postgres;

--
-- Name: FUNCTION escalation_build(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_build() IS 'DR: trigger to run on Building escalations (2012-02-26)';


--
-- PostgreSQL database dump complete
--

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
-- Name: escalation_workflow(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_workflow() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.escalation_workflow()
    Description:  Workflow trigger to run on !Building escalations
    Affects:      NEW escalation record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _payload        xml;
BEGIN
    IF standard.enum_id_value('cod', 'esc_state', NEW.esc_state_id) IN ('Resolved', 'Rejected', 'Merged') THEN
        IF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') OR
            NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating')
        THEN
            IF NEW.hm_issue IS NOT NULL THEN
                PERFORM hm_v1.close_issue(NEW.hm_issue, NEW.owner, ' ');
            END IF;
        END IF;
        PERFORM cod.remove_esc_actions(NEW.id);
        IF TG_OP = 'UPDATE' AND NEW.owner <> OLD.owner THEN
            PERFORM rt.update_ticket(NEW.rt_ticket, 'Owner: ' || NEW.owner || E'\n');
        END IF;
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Owned')) THEN
        IF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') OR
            NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating')
        THEN
            IF NEW.hm_issue IS NOT NULL THEN
                PERFORM hm_v1.close_issue(NEW.hm_issue, NEW.owner, ' ');
            END IF;
        END IF;
        PERFORM cod.remove_esc_actions(NEW.id);
        IF TG_OP = 'UPDATE' AND NEW.owner <> OLD.owner THEN
            PERFORM rt.update_ticket(NEW.rt_ticket, 'Owner: ' || NEW.owner || E'\n');
        END IF;
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Passive')) THEN
        PERFORM cod.remove_esc_actions(NEW.id);
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Failed')) THEN
        PERFORM cod.remove_esc_actions(NEW.id);
        INSERT INTO cod.action (item_id, escalation_id, action_type_id, content) VALUES (NEW.item_id, NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>Escalation Failed to ' || NEW.oncall_group || ' -- Contact Duty Manager</Note>');
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Active')) THEN
        IF NEW.hm_issue IS NULL THEN
            _payload := xmlelement(name "Issue", 
                xmlforest(
                    NEW.oncall_group AS "Oncall",
                    NEW.rt_ticket AS "Ticket",
                    (SELECT subject FROM cod.item WHERE id = NEW.item_id) AS "Subject",
                    null AS "Message",
                    null AS "ShortMessage",
                    'COPS' AS "Origin"
                )
            );
            UPDATE cod.escalation SET hm_issue = hm_v1.create_issue(_payload) WHERE id=NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.escalation_workflow() OWNER TO postgres;

--
-- Name: FUNCTION escalation_workflow(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_workflow() IS 'DR: Workflow trigger to run on !Building escalations (2012-02-26)';


--
-- PostgreSQL database dump complete
--

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
            regexp_replace(regexp_replace(NEW.component, E'\\(.*\\)', '', 'g'), E'\\:\\,\\@ ', '_', 'g');
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
-- Name: incident_workflow(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_workflow() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.incident_workflow()
    Description:  Workflow for incidents (and more for now)
    Affects:      Active Item record and associated elements
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _oncall     varchar;
    _row        record;
BEGIN
    IF NEW.rt_ticket IS NULL THEN
        NEW.rt_ticket := cod.create_incident_ticket_from_event((SELECT id FROM cod.event WHERE item_id = NEW.id ORDER BY id LIMIT 1));
        IF NEW.rt_ticket IS NOT NULL THEN
            UPDATE cod.item SET rt_ticket = NEW.rt_ticket WHERE id = NEW.id;
            RETURN NEW;
        END IF;
    END IF;

    --IF NEW.state_id = standard.enum_value_id('cod', 'state', 'Merged') THEN
    --    RETURN NEW;
    --END IF;

    IF NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN
        IF NEW.ended_at IS NOT NULL THEN
            -- cancel all active escalations
            PERFORM hm_v1.close_issue(hm_issue, owner, ' ') FROM cod.escalation WHERE item_id = NEW.id;
        END IF;
    END IF;

    IF NEW.nag_next IS NULL THEN
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag') AND completed_at IS NULL;
        IF FOUND IS TRUE THEN
            RETURN NEW;
        END IF;
    ELSEIF NEW.nag_next <= now() AND 
        NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag')) 
    THEN
        INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Nag'));
        RETURN NEW;
    END IF;

    IF NEW.state_id = standard.enum_value_id('cod', 'state', 'ACT') THEN
        IF EXISTS (SELECT NULL FROM cod.escalation WHERE standard.enum_id_value('cod', 'esc_state', esc_state_id) NOT IN ('Resolved', 'Rejected', 'Merged')) 
        THEN
            UPDATE cod.action SET completed_at = now(), successful = FALSE 
                WHERE item_id = NEW.id AND escalation_id IS NULL AND completed_at IS NULL 
                AND standard.enum_value_id('cod', 'action_type', 'Escalate');
            RETURN NEW;
        END IF;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed') THEN
        PERFORM cod.dash_delete_event(id) FROM cod.event WHERE item_id = NEW.id;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved') THEN
        IF NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close') AND completed_at IS NULL)
        THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Close'));
        END IF;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Cleared') THEN
        -- If no escalations are unresolved prompt operator to resolve ticket
        IF ((NEW.escalated_at IS NOT NULL AND NEW.resolved_at IS NOT NULL) OR
            (NEW.escalated_at IS NULL AND NEW.resolved_at IS NULL)) AND
            NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close') AND completed_at IS NULL)
        THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Close'));
        END IF;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Processing') THEN
        IF NEW.ended_at IS NULL AND NEW.started_at IS NOT NULL AND NEW.resolved_at IS NOT NULL THEN
            INSERT INTO cod.action (item_id, action_type_id, content) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>All Escalations resolved but the alert is not cleared, clear the alert or Escalate</Note>');
        END IF;
    END IF;

    -- if have not escalated
    IF NEW.escalated_at IS NULL THEN
        -- if no helptext action
        IF NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText'))
        THEN
            IF (SELECT help_text FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
                -- create action to prompt for acting on helptext
                INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'));
            ELSE
                INSERT INTO cod.action (item_id, action_type_id, completed_at, completed_by, skipped, successful) VALUES 
                    (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'), now(), 'ssg-cod', true, false);
            END IF;
        END IF;

        -- if no active (or successful) helptext and unclosed event (and not escalated)
        IF NEW.ended_at is NULL AND
            NOT EXISTS (SELECT NULL FROM cod.action AS a JOIN cod.action_type AS t ON (a.action_type_id=t.id) 
                WHERE a.item_id = NEW.id AND (t.name = 'HelpText' OR t.name = 'Escalate') AND (completed_at IS NULL OR successful IS TRUE))
        THEN
            SELECT * INTO _row FROM cod.event WHERE item_id = NEW.id ORDER BY id DESC LIMIT 1;
            _oncall := COALESCE(_row.contact, _row.oncall_primary, _row.oncall_alternate);
            IF _oncall IS NOT NULL THEN
                -- create escalation (see escalation_workflow)
                IF (SELECT active_notification FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
                    INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (NEW.id, _oncall, standard.enum_value_id('cod', 'page_state', 'Active'));
                ELSE
                    INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (NEW.id, _oncall, standard.enum_value_id('cod', 'page_state', 'Passive'));
                END IF;
            END IF;
            -- if no valid oncall group or failed to insert escalation
            IF _oncall IS NULL OR FOUND IS FALSE THEN
                -- create action to prompt to correct oncall group
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>No valid oncall group in the event, manual escalation required.</Note>');
            END IF;
        END IF;

    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.incident_workflow() OWNER TO postgres;

--
-- Name: FUNCTION incident_workflow(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_workflow() IS 'DR: Workflow for incidents (and more for now) (2012-02-29)';


--
-- PostgreSQL database dump complete
--

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
-- Name: inject(character varying, character varying); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION inject(character varying, character varying) RETURNS xml
    LANGUAGE sql
    AS $_$
/*  Function:     cod.inject(varchar, varchar)
    Description:  Inject a faux alert
    Affects:      Creates and incident
    Arguments:    varchar: hostname
                  varchar: support model
    Returns:      xml
*/
SELECT cod_v2.spawn_item_from_alert(('<Event><Netid>joby</Netid><Operator>AIE-AE</Operator><OnCall>ssg_oncall</OnCall><AltOnCall>uwnetid_joby</AltOnCall><SupportModel>' || $2 || '</SupportModel><LifeCycle>deployed</LifeCycle><Source>prox</Source><VisTime>500</VisTime><Alert><ProblemHost>' || $1 || '</ProblemHost><Flavor>prox</Flavor><Origin/><Component>joby-test</Component><Msg>Test</Msg><LongMsg>Just a test by joby</LongMsg><Contact>uwnetid_joby</Contact><Owner/><Ticket/><IssueNum/><ItemNum/><Severity>10</Severity><Count>1</Count><Increment>false</Increment><StartTime>1283699633122</StartTime><AutoClear>true</AutoClear><Action>Upd</Action></Alert></Event>')::xml);
$_$;


ALTER FUNCTION cod.inject(character varying, character varying) OWNER TO postgres;

--
-- Name: FUNCTION inject(character varying, character varying); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION inject(character varying, character varying) IS 'DR: Inject a faux alert (2012-02-15)';


--
-- PostgreSQL database dump complete
--

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
-- Name: item_merge(integer, integer, boolean); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_merge(integer, integer, boolean) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.item_merge(integer, integer, boolean)
    Description:  Merge item id 2 into id 1
    Affects:      Both items and records associated with item 2
    Arguments:    integer: Id of Item to merge into
                  integer: ID of Item to merge
                  boolean: Lock and unlock root item
    Returns:      boolean
*/
DECLARE
    v_root      ALIAS FOR $1;
    v_branch    ALIAS FOR $2;
    v_lock      ALIAS FOR $3;
    _mergeid    integer;
BEGIN
    IF v_lock THEN
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_root;
    END IF;
    _mergeid := standard.enum_value_id('cod', 'state', 'Merged');
    UPDATE cod.item SET state_id = _mergeid WHERE id = v_branch AND state_id <> _mergeid;
    UPDATE cod.event SET item_id = v_root WHERE item_id = v_branch;
    UPDATE cod.escalation SET item_id = v_root WHERE item_id = v_branch;
    UPDATE cod.action SET item_id = v_root WHERE item_id = v_branch;
    IF v_lock THEN
        UPDATE cod.item SET workflow_lock = FALSE WHERE id = v_root;
    END IF;
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION cod.item_merge(integer, integer, boolean) OWNER TO postgres;

--
-- Name: FUNCTION item_merge(integer, integer, boolean); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION item_merge(integer, integer, boolean) IS 'DR: Merge item id 2 into id 1 (2012-03-01)';


--
-- PostgreSQL database dump complete
--

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
-- Name: item_rt_update(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_rt_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.item_rt_update()
    Description:  Update rt with item metadata
    Affects:      
    Arguments:    
    Returns:      trigger
*/
DECLARE
    _payload    varchar  := '';
    _comment    varchar  := '';
    _string     varchar;
BEGIN
    IF OLD.itil_type_id IS DISTINCT FROM NEW.itil_type_id THEN
        _string  := standard.enum_id_value('cod', 'itil_type', NEW.itil_type_id);
        _comment := _comment
                 || 'ITIL Type: ' || _string || E'\n';
        IF _string ~ E'^\\(.*\\)$' THEN
            _string = '';
        END IF;
        _payload := _payload
                 || 'CF-TicketType: ' || _string || E'\n';
    END IF;
    IF OLD.support_model_id IS DISTINCT FROM NEW.support_model_id THEN
        _comment := _comment
                 || 'Support Model: ' || standard.enum_id_value('cod', 'support_model', NEW.support_model_id) || E'\n';
    END IF;
    IF OLD.severity IS DISTINCT FROM NEW.severity THEN
        _comment := _comment
                 || 'Severity: ' || NEW.severity::varchar || E'\n';
        _payload := _payload
                 || 'Severity: Sev' || NEW.severity::varchar || E'\n';
    END IF;
    IF OLD.reference_no IS DISTINCT FROM NEW.reference_no THEN
        IF NEW.reference_no IS NULL THEN
            _string := '';
        ELSE
            _string := NEW.reference_no;
        END IF;
        _comment := _comment
                 || 'Reference Number: ' || _string || E'\n';
    END IF;
    IF NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed') THEN
        _payload := _payload
                 || E'Status: resolved\n';

    END IF;
    IF OLD.subject IS DISTINCT FROM NEW.subject THEN
        _payload := _payload
                 || E'Subject: '|| New.subject || E'\n';

    END IF;
    IF _comment <> '' THEN
        _payload := E'UpdateType: comment\n'
                 || E'CONTENT: ' || _comment || cod_v2.comment_post()
                 || E'ENDOFCONTENT\n'
                 || _payload;
    END IF;
    IF _payload <> '' THEN
        PERFORM rt.update_ticket(NEW.rt_ticket, _payload);
    END IF;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN null;
END;
$_$;


ALTER FUNCTION cod.item_rt_update() OWNER TO postgres;

--
-- Name: FUNCTION item_rt_update(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION item_rt_update() IS 'DR: Update rt with item metadata (2012-02-29)';


--
-- PostgreSQL database dump complete
--

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
-- Name: remove_esc_actions(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION remove_esc_actions(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.remove_esc_actions(integer)
    Description:  Remove any actions associated with the provided escalation id
    Affects:      All incomplete actions associated with the provided escalation id
    Arguments:    integer: escalation_id
    Returns:      boolean
*/
DECLARE
    v_esc_id    ALIAS FOR $1;
BEGIN
    UPDATE cod.action SET completed_at = now(), successful = false WHERE escalation_id = v_esc_id AND completed_at IS NULL;
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION cod.remove_esc_actions(integer) OWNER TO postgres;

--
-- Name: FUNCTION remove_esc_actions(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION remove_esc_actions(integer) IS 'DR: Remove any actions associated with the provided escalation id (2012-02-09)';


--
-- PostgreSQL database dump complete
--

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
-- Name: update_item(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION update_item() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.update_item()
    Description:  Update the item associated with this record
    Affects:      Item associated with this record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    UPDATE cod.item SET modified_at = now() WHERE id = NEW.item_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.update_item() OWNER TO postgres;

--
-- Name: FUNCTION update_item(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION update_item() IS 'DR: Update the item associated with this record (2012-02-26)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: action_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION action_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.action_xml(integer)
    Description:  XML Representation of an action
    Affects:      nothing
    Arguments:    integer: action id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Action",
        xmlelement(name "Id", action.id),
        xmlelement(name "Type", type.name),
        xmlelement(name "Successful", action.successful),
        xmlelement(name "Data", action.content::xml),
        xmlelement(name "Completed",
            xmlelement(name "At", date_trunc('second', action.completed_at)::timestamp::varchar),
            xmlelement(name "By", action.completed_by)
        ),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', action.modified_at)::timestamp::varchar),
            xmlelement(name "By", action.modified_by)
        )
    ) FROM cod.action AS action
      JOIN cod.action_type AS type ON (action.action_type_id = type.id)
     WHERE action.id = $1;
$_$;


ALTER FUNCTION cod_v2.action_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION action_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION action_xml(integer) IS 'DR: XML Representation of an action (2012-02-26)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: can_spawn(character varying); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION can_spawn(character varying) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
/*  Function:     cod_v2.can_spawn(varchar)
    Description:  True if the uwnetid is premitted to spawn incidents from events
    Affects:      nothing
    Arguments:    varchar: uwnetid
    Returns:      boolean
*/
DECLARE
    v_netid     ALIAS FOR $1;
BEGIN
    IF ARRAY[v_netid] <@ '{alexc,areed,blakjack,cil5,ddiehl,guerrero,ljahed,lyns,mhouli,rliesik,schrud,tblood,tynand,wizofoz,joby,kkurth,ldugan,kenm}'::varchar[] 
    THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod_v2.can_spawn(character varying) OWNER TO postgres;

--
-- Name: FUNCTION can_spawn(character varying); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION can_spawn(character varying) IS 'DR: True if the uwnetid is premitted to spawn incidents from events (2012-02-26)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: comment_post(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION comment_post() RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
/*  Function:     cod_v2.comment_post()
    Description:  Content to insert after comments
    Affects:      nothing
    Arguments:    none
    Returns:      varchar
*/
    SELECT E'\n-----------------------------------------\n'
        || E'By ' || standard.get_uwnetid() || E' via COD\n';
$$;


ALTER FUNCTION cod_v2.comment_post() OWNER TO postgres;

--
-- Name: FUNCTION comment_post(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION comment_post() IS 'DR: Content to insert after comments (2012-02-17)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: comment_pre(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION comment_pre() RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
/*  Function:     cod_v2.comment_pre()
    Description:  Content to insert before comments
    Affects:      nothing
    Arguments:    none
    Returns:      varchar
*/
    SELECT E'COD\n'
        || E'-----------------------------------------\n';
$$;


ALTER FUNCTION cod_v2.comment_pre() OWNER TO postgres;

--
-- Name: FUNCTION comment_pre(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION comment_pre() IS 'DR: Content to insert before comments (2012-02-17)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: enumerations(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION enumerations() RETURNS xml
    LANGUAGE sql STABLE
    AS $$
/*  Function:     cod_v2.enumerations()
    Description:  Return lists of enumeration data for selects
    Affects:      nothing
    Arguments:    none
    Returns:      xml
*/
SELECT xmlelement(name "Enumerations"
    , rest_v1.enum_to_xml('cod', 'support_model', 'SupportModels', 'SupportModel', false)
    , rest_v1.enum_to_xml('cod', 'itil_type', 'ITILTypes', 'ITILType', false)
    , xmlelement(name "Severities"
        , xmlelement(name "Severity", 1)
        , xmlelement(name "Severity", 2)
        , xmlelement(name "Severity", 3)
        , xmlelement(name "Severity", 4)
        , xmlelement(name "Severity", 5)
    )
);
$$;


ALTER FUNCTION cod_v2.enumerations() OWNER TO postgres;

--
-- Name: FUNCTION enumerations(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION enumerations() IS 'DR: Return lists of enumeration data for selects (2012-02-25)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: escalation_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.escalation_xml(integer)
    Description:  XML Representation of an Escalation
    Affects:      nothing
    Arguments:    integer: escalation id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Escalation", 
        xmlelement(name "Id", e.id),
        xmlelement(name "RTTicket", e.rt_ticket),
        xmlelement(name "HMIssue", e.hm_issue),
        xmlelement(name "State", state.name),
        xmlelement(name "PageState", page.name),
        xmlelement(name "OncallGroup", e.oncall_group),
        xmlelement(name "Queue", e.queue),
        xmlelement(name "Owner", e.owner),
        xmlelement(name "Times", 
            xmlelement(name "Escalated", date_trunc('second', e.escalated_at)::timestamp::varchar),
            xmlelement(name "Owned", date_trunc('second', e.owned_at)::timestamp::varchar),
            xmlelement(name "Resolved", date_trunc('second', e.resolved_at)::timestamp::varchar)
        ),
        xmlelement(name "Content", e.content),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', e.modified_at)::timestamp::varchar),
            xmlelement(name "By", e.modified_by)
        )
    ) FROM cod.escalation AS e
      JOIN cod.esc_state AS state ON (e.esc_state_id = state.id)
      JOIN cod.page_state AS page ON (e.page_state_id = page.id)
     WHERE e.id = $1;
$_$;


ALTER FUNCTION cod_v2.escalation_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION escalation_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION escalation_xml(integer) IS 'DR: XML Representation of an Escalation (2012-02-26)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: event_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION event_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.event_xml(integer)
    Description:  XML Representation of an Event
    Affects:      nothing
    Arguments:    integer: event id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Event",
        xmlelement(name "Id", event.id),
        xmlelement(name "Host", event.host),
        xmlelement(name "Component", event.component),
        xmlelement(name "SupportModel", model.name),
        xmlelement(name "Severity", event.severity),
        xmlelement(name "Contact", event.contact),
        xmlelement(name "OncallPrimary", event.oncall_primary),
        xmlelement(name "OncallAlternate", event.oncall_alternate),
        xmlelement(name "HelpText", event.helptext),
        xmlelement(name "Subject", xpath.get_varchar('/Event/Subject', event.content::xml)),
        xmlelement(name "Message", xpath.get_varchar('/Event/Alert/Msg', event.content::xml)),
        xmlelement(name "LongMessage", xpath.get_varchar('/Event/Alert/LongMsg', event.content::xml)),
        xmlelement(name "Content", event.content::xml),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', event.modified_at)::timestamp::varchar),
            xmlelement(name "By", event.modified_by)
        ),
        xmlelement(name "Times",
            xmlelement(name "Start", date_trunc('second', event.start_at)::timestamp::varchar),
            xmlelement(name "End", date_trunc('second', event.end_at)::timestamp::varchar)
        )
    ) FROM cod.event AS event
      JOIN cod.support_model AS model ON (event.support_model_id = model.id)
     WHERE event.id = $1;
$_$;


ALTER FUNCTION cod_v2.event_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION event_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION event_xml(integer) IS 'DR: XML Representation of an Event (2012-02-26)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: item_do_xml(integer, xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_do_xml(integer, xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.item_do_xml(integer, xml)
    Description:  Perform actions on an item
    Affects:      An item and associated elements
    Arguments:    xml: XML representation of the action to perform
    Returns:      xml
*/
DECLARE
    v_id        ALIAS FOR $1;
    v_xml       ALIAS FOR $2;
    _id         integer;
    _type       varchar;
    _message    varchar;
    _msgType    varchar     := 'comment';
    _msgToSubs  varchar     := 'open';
    _success    boolean;
    _payload    varchar     := '';
    _owner      varchar;
    _page       varchar;
    _oncall     varchar;
    _number     numeric;
    _period     varchar;
    _row        cod.item%ROWTYPE;
BEGIN
    SELECT * INTO _row FROM cod.item WHERE id = v_id;
    IF _row.id IS NULL THEN
        RETURN NULL;
    END IF;
    _id      := xpath.get_integer('/Item/Do/Id', v_xml);
    _type    := xpath.get_varchar('/Item/Do/Type', v_xml);
    _message := xpath.get_varchar('/Item/Do/Message', v_xml);
    IF _type = 'Update' THEN
        UPDATE cod.item 
            SET subject = xpath.get_varchar('/Item/Do/Subject', v_xml),
                reference_no = xpath.get_varchar('/Item/Do/RefNo', v_xml),
                severity = xpath.get_integer('/Item/Do/Severity', v_xml),
                support_model_id = standard.enum_value_id('cod', 'support_model', xpath.get_varchar('/Item/Do/SupportModel', v_xml))
            WHERE id = v_id;
        --  itil_type_id = standard.enum_value_id('cod', 'itil_type', xpath.get_varchar('/Item/Do/ITILType', v_xml))    
    ELSEIF _type = 'Close' THEN
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = TRUE
            WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close');
        UPDATE cod.item SET workflow_lock = FALSE, closed_at = now() WHERE id = v_id;
        _msgType   := 'correspond';
        _msgToSubs := 'none';
        _payload   := E'Status: resolved\n';
    ELSEIF _type = 'Clear' THEN
        UPDATE cod.event SET end_at = now() WHERE item_id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = v_id AND completed_at IS NULL AND 
                action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
    ELSEIF _type = 'Reactivate' THEN
        UPDATE cod.event SET end_at = NULL WHERE item_id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = v_id AND completed_at IS NULL AND 
                action_type_id = standard.enum_value_id('cod', 'action_type', 'Close');
    ELSEIF _type = 'PhoneCall' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Take' THEN
            _success := TRUE;
        ELSEIF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Fail' THEN
            _success := FALSE;
        END IF;
        IF _success IS TRUE THEN
            UPDATE cod.action SET successful = TRUE, completed_at = now() WHERE id = _id;
        ELSE
            UPDATE cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating')
                WHERE id = (SELECT escalation_id FROM cod.action WHERE id = _id);
            IF NOT FOUND THEN
                UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Escalating')
                    WHERE id = (SELECT item_id FROM cod.action WHERE id = _id);
            END IF;
            UPDATE cod.action SET successful = FALSE, completed_at = now() WHERE id = _id;
        END IF;
        PERFORM hm_v1.update_squawk(xpath.get_integer('/Item/Do/SquawkId', v_xml), _success, _message);
        _message := NULL;
    ELSEIF _type = 'HelpText' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Clear' THEN
            UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_id;
            UPDATE cod.action SET completed_at = now(), successful = TRUE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText');
            UPDATE cod.event set end_at = now() WHERE item_id = v_id;
            UPDATE cod.item SET workflow_lock = FALSE WHERE id = v_id;
        ELSE
            UPDATE cod.action SET completed_at = now(), successful = FALSE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText');
        END IF;
        _msgToSubs := 'none';
    ELSEIF _type = 'Message' THEN
        _msgType   := xpath.get_varchar_check('/Item/Do/MsgType', v_xml, _msgType);
        _msgToSubs := xpath.get_varchar('/Item/Do/ToSubs', v_xml);
    ELSEIF _type = 'SetOwner' THEN
        _owner := xpath.get_varchar('/Item/Do/Owner', v_xml);
        IF _owner IS NOT NULL THEN
            UPDATE cod.escalation SET owner = _owner WHERE item_id = v_id AND id = xpath.get_integer('/Item/Do/EscId', v_xml);
        END IF;
    ELSEIF _type = 'Escalate' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Submit' THEN
            IF xpath.get_varchar('/Item/Do/ContactType', v_xml) = 'passive' THEN
                _page := 'Passive';
            ELSE
                _page := 'Active';
            END IF;
            _oncall := xpath.get_varchar('/Item/Do/EscalateTo', v_xml);
            IF _oncall = '_' THEN
                _oncall = xpath.get_varchar('/Item/Do/Custom', v_xml);
            END IF;
            IF NOT hm_v1.valid_oncall(_oncall) THEN
                RAISE EXCEPTION 'InvalidInput: Not a valid oncall group -- %', _oncall;
            END IF;
            INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) 
                VALUES (v_id, _oncall, standard.enum_value_id('cod', 'page_state', _page));
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Failed to create and escalation to the oncall group %', _oncall;
            ELSE
                UPDATE cod.action SET completed_at = now(), successful = TRUE
                    WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
            END IF;
        ELSE
            UPDATE cod.action SET completed_at = now(), successful = TRUE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
        END IF;
    ELSEIF _type = 'Nag' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Cancel' THEN
            _message := NULL;
        END IF;
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = _row.id;
        UPDATE cod.action SET completed_at = now(), successful = true WHERE item_id = _row.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag');
        UPDATE cod.item SET workflow_lock = FALSE, nag_next = NULL WHERE id = _row.id;
    ELSEIF _type = 'SetNag' THEN
        _number := xpath.get_numeric('/Item/Do/Number', v_xml);
        IF _number IS NULL OR _number <= 0 THEN
            RAISE EXCEPTION 'InvalidInput: Nag period number must be a positive number not "%"', _period;
        END IF;
        _period := xpath.get_varchar('/Item/Do/Period', v_xml);
        IF _period IS NULL OR NOT (ARRAY[_period]::varchar[] <@ ARRAY['minutes', 'hours', 'days']::varchar[]) THEN
            RAISE EXCEPTION 'InvalidInput: Nag period must be in minutes, hours, or days not "%"', _period;
        END IF;
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = _row.id;
        UPDATE cod.action SET completed_at = now(), successful = false WHERE item_id = _row.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag');
        UPDATE cod.item SET workflow_lock = FALSE, nag_next = NULL, nag_interval = _number::varchar || ' ' || _period WHERE id = _row.id;
    END IF;
    IF _message IS NOT NULL THEN
        _payload := E'UpdateType: ' || _msgType || E'\n'
                 || E'CONTENT: ' || _message || cod_v2.comment_post()
                 || E'ENDOFCONTENT\n'
                 || _payload;
    END IF;
    IF _payload <> '' THEN
        PERFORM rt.update_ticket(_row.rt_ticket, _payload);
        IF _msgToSubs = 'all' THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id;
        ELSEIF _msgToSubs = 'open' THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id 
                AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Resolved') 
                AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Rejected');
        ELSEIF _msgToSubs = 'owned' THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id 
                AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Owned');
        END IF;
    END IF;
    RETURN cod_v2.item_xml(v_id);
END;
$_$;


ALTER FUNCTION cod_v2.item_do_xml(integer, xml) OWNER TO postgres;

--
-- Name: FUNCTION item_do_xml(integer, xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION item_do_xml(integer, xml) IS 'DR: Perform actions on an item (2012-02-13)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: item_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.item_xml(integer)
    Description:  Retrive XML representation of an item
    Affects:      nothing
    Arguments:    integer: id of the item
    Returns:      xml: XML representation of the item
*/
    SELECT xmlelement(name "Item",
        xmlelement(name "Id", item.id),
        xmlelement(name "Subject", item.subject),
        xmlelement(name "RTTicket", item.rt_ticket),
        xmlelement(name "HMIssue", item.hm_issue),
        xmlelement(name "State", state.name),
        xmlelement(name "ITILType", itil.name),
        xmlelement(name "SupportModel", model.name),
        xmlelement(name "Severity", item.severity),
        xmlelement(name "Stage", stage.name),
        xmlelement(name "ReferenceNumber", item.reference_no),
        xmlelement(name "Times",
            xmlelement(name "Started", date_trunc('second', item.started_at)::timestamp::varchar),
            xmlelement(name "Ended", date_trunc('second', item.ended_at)::timestamp::varchar),
            xmlelement(name "Escalated", date_trunc('second', item.escalated_at)::timestamp::varchar),
            xmlelement(name "Resolved", date_trunc('second', item.resolved_at)::timestamp::varchar),
            xmlelement(name "Nag", date_trunc('second', item.nag_next)::timestamp::varchar),
            xmlelement(name "Closed", date_trunc('second', item.closed_at)::timestamp::varchar)
        ),
        xmlelement(name "Events",
            (SELECT xmlagg(cod_v2.event_xml(e.id)) FROM
               (SELECT id FROM cod.event WHERE item_id = $1 ORDER BY id ASC) AS e
            )  
        ),
        xmlelement(name "Actions",
            (SELECT xmlagg(cod_v2.action_xml(a.id)) FROM
               (SELECT id FROM cod.action WHERE item_id = $1 ORDER BY id) AS a
            )  
        ),
        xmlelement(name "Escalations",
            (SELECT xmlagg(cod_v2.escalation_xml(x.id)) FROM
               (SELECT id FROM cod.escalation WHERE item_id = $1 ORDER BY id DESC) AS x
            )
        ),
        xmlelement(name "Content", item.content),
        xmlelement(name "Created",
            xmlelement(name "At", date_trunc('second', item.created_at)::timestamp::varchar),
            xmlelement(name "By", item.created_by)
        ),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', item.modified_at)::timestamp::varchar),
            xmlelement(name "By", item.modified_by)
        )
    ) FROM cod.item AS item
      JOIN cod.state AS state ON (item.state_id = state.id)
      JOIN cod.itil_type AS itil ON (item.itil_type_id = itil.id)
      JOIN cod.support_model AS model ON (item.support_model_id = model.id)
      LEFT JOIN cod.stage AS stage ON (item.stage_id = stage.id)
     WHERE item.id = $1;
$_$;


ALTER FUNCTION cod_v2.item_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION item_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION item_xml(integer) IS 'DR: Retrive XML representation of an item (2011-10-17)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: items_xml(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION items_xml() RETURNS xml
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod_v2.items_xml()
    Description:  List of cod items
    Affects:      nothing
    Arguments:    none
    Returns:      XML list of items
*/
DECLARE
    _lastmod    timestamptz;
    _cache      xml;
BEGIN
    _lastmod := (SELECT max(modified_at) FROM cod.item);
    _cache   := (cod.dbcache_get('ITEMS', _lastmod))::xml;
    IF _cache IS NULL THEN
        _cache := xmlelement(name "Items",
            (SELECT xmlagg(cod_v2.item_xml(id)) FROM (
                SELECT i.id FROM cod.item i JOIN cod.state s ON (i.state_id=s.id) 
                    WHERE s.sort < 90 OR i.closed_at > now() - '1 hour'::interval ORDER BY s.sort ASC, i.rt_ticket DESC
            ) AS foo),
            xmlelement(name "ModifiedAt", _lastmod)
        );
        PERFORM cod.dbcache_update('ITEMS', _cache::varchar, _lastmod);
    END IF;
    RETURN _cache;
END;
$$;


ALTER FUNCTION cod_v2.items_xml() OWNER TO postgres;

--
-- Name: FUNCTION items_xml(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION items_xml() IS 'DR: List of cod items. Uses cod.dbacache (2012-02-26)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: nag_check(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION nag_check() RETURNS xml
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod_v2.nag_check()
    Description:  Update items where nag may be needed
    Affects:      cod.item where nag may be needed
    Arguments:    none
    Returns:      xml
*/
DECLARE
    _count      integer;
BEGIN
    UPDATE cod.item AS item SET modified_at = now() WHERE nag_next < now() AND NOT EXISTS(SELECT NULL FROM cod.action WHERE action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag') AND completed_at IS NULL AND item_id = item.id);
    GET DIAGNOSTICS _count = ROW_COUNT;
    RETURN ('<Updated>' || _count::varchar || '</Updated>')::xml;
EXCEPTION
    WHEN OTHERS THEN null;
END;
$$;


ALTER FUNCTION cod_v2.nag_check() OWNER TO postgres;

--
-- Name: FUNCTION nag_check(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION nag_check() IS 'DR: Update items where nag may be needed (2012-02-23)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: process_hm_update(xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION process_hm_update(xml) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.process_hm_update(xml)
    Description:  Process HM Issues state for COD
    Affects:      COD.item/escalation/action associated with this H&M notification
    Arguments:    xml: XML representation of an H&M Issue
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _hm_id      integer;
    _ticket     integer;
    _activity   varchar;
    _content    varchar;
    _row        record;
    _item_id    integer;
    _action     cod.action%ROWTYPE;
BEGIN
    _hm_id    := xpath.get_integer('/Issue/Id', v_xml);
    _ticket   := xpath.get_integer('/Issue/Ticket', v_xml);
    _activity := xpath.get_varchar('/Issue/Activity', v_xml);
    _content  := xpath('/Issue/CurrentSquawk', v_xml)::text::varchar;
    SELECT * INTO _row FROM cod.escalation WHERE hm_issue = _hm_id OR (rt_ticket = _ticket AND hm_issue IS NULL);
    IF _row.id IS NOT NULL THEN
        IF _activity = 'closed' THEN
            IF _row.owner = 'nobody' AND xpath.get_varchar('/Issue/Owner', v_xml) <> 'nobody' THEN
                Update cod.escalation SET 
                    owner = xpath.get_varchar('/Issue/Owner', v_xml),
                    page_state_id = standard.enum_value_id('cod', 'page_state', 'Closed')
                    WHERE id = _row.id;
            ELSE
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Closed') WHERE id = _row.id;
            END IF;    
        ELSEIF _activity = 'cancelled' THEN
            PERFORM cod.remove_esc_actions(_row.id);
            Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Cancelled') WHERE id = _row.id;
        ELSEIF _activity = 'failed' THEN
            PERFORM cod.remove_esc_actions(_row.id);
            Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Failed') WHERE id = _row.id;
        ELSEIF _activity = 'escalating' THEN
            PERFORM cod.remove_esc_actions(_row.id);
            Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating') WHERE id = _row.id;
        ELSEIF _activity = 'act' THEN
            UPDATE cod.action SET completed_at = now(), successful = FALSE
                WHERE escalation_id = _row.id AND completed_at IS NULL AND content <> _content;
            SELECT * INTO _action FROM cod.action WHERE escalation_id = _row.id AND content = _content;
            IF _action.id IS NULL THEN
                INSERT INTO cod.action (item_id, escalation_id, action_type_id, content) VALUES (
                    _row.item_id,
                    _row.id,
                    standard.enum_value_id('cod', 'action_type', 'PhoneCall'),
                    _content
                );
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') WHERE id = _row.id;
            ELSEIF _action.completed_at IS NULL THEN
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') WHERE id = _row.id;
            ELSE
                Update cod.escalation SET page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating') WHERE id = _row.id;
            END IF;
        END IF;
        RETURN TRUE;
    END IF;

    SELECT * INTO _row FROM cod.item 
        WHERE (rt_ticket IS NULL OR rt_ticket = _ticket) 
          AND (hm_issue IS NULL OR hm_issue = _hm_id)
          AND (rt_ticket IS NOT NULL OR hm_issue IS NOT NULL);

    IF _row.id IS NULL THEN
        IF ARRAY[_activity] <@ ARRAY['closed', 'cancelled', 'failed']::varchar[] THEN
            RETURN FALSE;
        ELSE
            -- get id
            _item_id := nextval('cod.item_id_seq'::regclass);
            -- create
            INSERT INTO cod.item (id, itil_type_id, state_id, hm_issue, subject, workflow_lock) VALUES (
                _item_id,
                standard.enum_value_id('cod', 'itil_type', '(Notification)'),
                standard.enum_value_id('cod', 'state', 'Escalating'),
                _hm_id,
                xpath.get_varchar('/Issue/Subject', v_xml),
                TRUE
            );
            IF _activity = 'act' THEN
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (
                    _item_id,
                    standard.enum_value_id('cod', 'action_type', 'PhoneCall'),
                    _content
                );
                UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Act') WHERE id = _item_id;
            END IF;
        END IF;
        RETURN TRUE;
    ELSE
        IF ARRAY[_activity] <@ ARRAY['closed', 'cancelled', 'failed']::varchar[] THEN
            -- remove all phoncalls for this item;
            UPDATE cod.action SET completed_at = now(), successful = false 
                WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND completed_at IS NULL;
            UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Closed'), closed_at = now() WHERE id = _row.id;
        ELSEIF _activity = 'escalating' THEN
            UPDATE cod.action SET completed_at = now(), successful = false 
                WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND completed_at IS NULL;
            UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Escalating') WHERE id = _row.id;
        ELSEIF _activity = 'act' THEN
            -- remove any ponecalls where content doesn't equal _content
            UPDATE cod.action SET completed_at = now(),successful = false 
                WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND completed_at IS NULL AND content <> _content AND completed_at IS NULL;
            -- if action doesn't exist then insert
            IF NOT EXISTS (SELECT NULL FROM cod.action WHERE item_id = _row.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'PhoneCall') AND content = _content AND completed_at IS NULL)
            THEN
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (
                    _row.id,
                    standard.enum_value_id('cod', 'action_type', 'PhoneCall'),
                    _content
                );
            END IF;
            UPDATE cod.item SET state_id = standard.enum_value_id('cod', 'state', 'Act') WHERE id = _row.id;
        END IF;
        RETURN TRUE;
    END IF;

    RETURN FALSE;
--EXCEPTION
--    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod_v2.process_hm_update(xml) OWNER TO postgres;

--
-- Name: FUNCTION process_hm_update(xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION process_hm_update(xml) IS 'DR: Process HM Issues state for COD (2012-02-07)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: rt_import(xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION rt_import(xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.rt_import(xml)
    Description:  Process RT import data
    Affects:      Any ticket/escalation
    Arguments:    xml: Data from RT
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _count      integer;
    _count2     integer;
    _incidents  xml[];
    _incident   xml;
    _escs       xml[];
    _status     varchar;
    _aliases    integer[];
    _i          integer;
    _j          integer;
    _item       cod.item%ROWTYPE;
    _unlock     boolean     := FALSE;
    _new        boolean     := FALSE;
    _output     varchar;
BEGIN
    _incidents := xpath('/Incidents/Incident', v_xml);
    _count     := array_upper(_incidents, 1);
    IF _count IS NULL THEN
        RETURN '<Success/>'::xml;
    END IF;
    -- foreach incident
    FOR _i in 1.._count LOOP
        _incident := _incidents[_i];
        _aliases := xpath.get_varchar_array('/Incident/AliasIds/AliasId', v_xml)::integer[];
        SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
        IF _item.id IS NULL THEN
            SELECT * INTO _item FROM cod.item WHERE ARRAY[rt_ticket]::integer[] <@ _aliases LIMIT 1;
            IF _item.id IS NOT NULL THEN
                UPDATE cod.item SET rt_ticket = xpath.get_integer('/Incident/Id', v_xml) WHERE id = _item.id;
            ELSEIF xpath.get_varchar('/Incident/Type', v_xml) <> 'Incident' THEN
                CONTINUE;
                -- do nothing.
            ELSEIF xpath.get_timestamptz('/Incident/Created', _incident) < now() - '1 minute'::interval THEN
                INSERT INTO cod.item (rt_ticket, subject, state_id, itil_type_id, support_model_id, severity, workflow_lock) VALUES (
                    xpath.get_integer('/Incident/Id', _incident),
                    xpath.get_varchar('/Incident/Subject', _incident),
                    standard.enum_value_id('cod', 'state', 'Tier2'),
                    standard.enum_value_id('cod', 'itil_type', 'Incident'),
                    standard.enum_value_id('cod', 'support_model', ''),
                    xpath.get_integer('/Incident/Severity', _incident),
                    TRUE
                );
                _unlock := TRUE;
                _new    := TRUE;
                SELECT * INTO _item FROM cod.item WHERE rt_ticket = xpath.get_integer('/Incident/Id', _incident);
                IF NOT FOUND THEN
                    CONTINUE;
                END IF;
            ELSE
                CONTINUE;
            END IF;
        END IF;
        IF _item.workflow_lock IS FALSE THEN
            UPDATE cod.item SET workflow_lock = TRUE WHERE id = _item.id;
        END IF;
        -- Merge in other tickets
        PERFORM cod.item_merge(_item.id, id, FALSE) FROM cod.item WHERE ARRAY[rt_ticket]::integer[] <@ _aliases;

        -- check status (?reset closed if closed?)
        _escs   := xpath('/Incident/Escalations/Escalation', _incident);
        _count2 := array_upper(_escs, 1);
        IF _count2 IS NOT NULL THEN
            -- foreach escalation
            FOR _j in 1.._count2 LOOP
                PERFORM cod_v2.rt_process_escalation(_item.id, _new, _escs[_j]);
            END LOOP;
        END IF;
        UPDATE cod.item SET workflow_lock = FALSE WHERE id = _item.id;
    END LOOP;
    RETURN '<Success/>'::xml;
END;
$_$;


ALTER FUNCTION cod_v2.rt_import(xml) OWNER TO postgres;

--
-- Name: FUNCTION rt_import(xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION rt_import(xml) IS 'DR: Process RT import data (2012-02-16)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: rt_process_escalation(integer, boolean, xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION rt_process_escalation(integer, boolean, xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.rt_process_escalation(integer, boolean, xml)
    Description:  Process rt update on an escalation
    Affects:      
    Arguments:    integer: Item Id
                  boolean: If true do not wait a minute after created time to create
                  xml: Escalation XML Representation
    Returns:      xml
*/
DECLARE
    v_item_id       ALIAS FOR $1;
    v_new           ALIAS FOR $2;
    v_xml           ALIAS FOR $3;
    _aliases        integer[];
    _status         varchar;
    _escalation     cod.escalation%ROWTYPE;
BEGIN
    _aliases := xpath.get_varchar_array('/Escalation/AliasIds/AliasId', v_xml)::integer[];
    RAISE NOTICE 'ESCALATION, %', v_xml::varchar;
    SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', v_xml);
    IF _escalation.id IS NULL THEN
        RAISE NOTICE 'ESCALATION does not exist';
        --Check to see if under an alias
        SELECT * INTO _escalation FROM cod.escalation WHERE ARRAY[rt_ticket]::integer[] <@ _aliases LIMIT 1;
        IF _escalation.id IS NOT NULL THEN
            UPDATE cod.escalation SET rt_ticket = xpath.get_integer('/Escalation/Id', v_xml) WHERE id = _escalation.id;
        ELSEIF xpath.get_varchar('/Escalation/Type', v_xml) <> 'Incident' THEN
            RETURN '<Skipped/>'::xml;
        ELSEIF v_new OR xpath.get_timestamptz('/Escalation/Created', v_xml) < now() - '1 minute'::interval THEN
            RAISE NOTICE 'ESCALATION creating';
            INSERT INTO cod.escalation (item_id, rt_ticket, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at) VALUES (
                v_item.id,
                xpath.get_integer('/Escalation/Id', v_xml),
                standard.enum_value_id('cod', 'esc_state', 'Passive'),
                standard.enum_value_id('cod', 'page_state', 'Passive'),
                'n/a',
                xpath.get_varchar('/Escalation/Queue', v_xml),
                xpath.get_varchar('/Escalation/Owner', v_xml),
                xpath.get_timestamptz('/Escalation/Created', v_xml)
            );
            SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', v_xml);
            IF NOT FOUND THEN
                RAISE NOTICE 'ESCALATION creation failed';
                RETURN '<FailedToCreate/>'::xml;
            END IF;
        ELSE
            RAISE NOTICE 'ESCALATION skipping creation, %, %', xpath.get_timestamptz('/Escalation/Created', _incident), xpath.get_timestamptz('/Escalation/Created', _incident) < now() - '1 minute'::interval;
            RETURN '<Skipped/>'::xml;
        END IF;
    END IF;
    -- set severity from RT???
    _status := xpath.get_varchar('/Escalation/Status', v_xml);
    IF ARRAY['new', 'open', 'stalled']::varchar[] @> ARRAY[_status] THEN
        _escalation.resolved_at := NULL;
    ELSE
        IF _escalation.resolved_at IS NULL THEN
            _escalation.resolved_at  := now();
        END IF;
        IF _status = 'rejected' THEN
            _escalation.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Rejected');
        ELSE
            _escalation.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Resolved');
        END IF;
    END IF;
    UPDATE cod.escalation SET 
        resolved_at = _escalation.resolved_at,
        queue = xpath.get_varchar('/Escalation/Queue', v_xml),
        owner = xpath.get_varchar('/Escalation/Owner', v_xml),
        esc_state_id = _escalation.esc_state_id
        WHERE id = _escalation.id;
    --foreach aliasid, if it exists then set status to merged
    UPDATE cod.escalation 
        SET esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Merged'),
            resolved_at = now()
        WHERE ARRAY[rt_ticket]::integer[] <@ _aliases;
    RETURN '<Processed/>'::xml;
END;
$_$;


ALTER FUNCTION cod_v2.rt_process_escalation(integer, boolean, xml) OWNER TO postgres;

--
-- Name: FUNCTION rt_process_escalation(integer, boolean, xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION rt_process_escalation(integer, boolean, xml) IS 'DR: Process rt update on an escalation (2012-02-29)';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: spawn_item_from_alert(xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION spawn_item_from_alert(xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.spawn_item_from_alert(xml)
    Description:  Create an incident from an alert
    Affects:      Inserts Event and Item records
    Arguments:    xml: Event XML
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _row        record;
    _netid      varchar;
    _ticket     integer;
    _host       varchar;
    _comp       varchar;
    _model      varchar;
    _smid       integer;
    _contact    varchar;
    _hostpri    varchar;
    _hostalt    varchar;
    _msg        varchar;
    _lmsg       varchar;
    _source     varchar;
    _source_id  integer;
    _subject    varchar;
    _addtags    varchar;
    _cc         varchar;
    _nohelp     varchar;
    _helpurl    varchar;
    _starts     timestamptz;
    _severity   smallint;
    _item_id    integer;
    _event_id   integer;
BEGIN
    -- read event data
    
    _netid := xpath.get_varchar('/Event/Netid', v_xml);
    -- can this netid spawn?
    IF cod_v2.can_spawn(_netid) IS TRUE THEN
        -- if yes set uwit.uwnetid
        EXECUTE 'SET LOCAL uwit.uwnetid = ' || quote_literal(_netid);
    ELSE
        -- else return rejection
        RAISE EXCEPTION 'User is not authorized to create incidents via COD: %', _netid;
    END IF;

    _ticket := xpath.get_integer('/Event/Alert/Ticket', v_xml);         -- check
    -- IF ticket is active then return that ticket's info else continue.
    IF _ticket IS NOT NULL AND _ticket > 0 THEN
        SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate WHERE rt_ticket = _ticket LIMIT 1;
        IF _row.item_id IS NOT NULL THEN
            RETURN xmlelement(name "Incident",
                    xmlelement(name "Id", _row.item_id),
                    xmlelement(name "Ticket", _row.rt_ticket)
            );
        END IF;
    END IF;

    _host := xpath.get_varchar('/Event/Alert/ProblemHost', v_xml);      -- subject(item); (event)
    _comp := xpath.get_varchar('/Event/Alert/Component', v_xml);        -- subject(item); (event)
    _model := upper(xpath.get_varchar('/Event/SupportModel', v_xml));   -- (item); (event)
    _contact := xpath.get_varchar('/Event/Alert/Contact', v_xml);       -- (event)
    _hostpri := xpath.get_varchar('/Event/OnCall', v_xml);        -- (event)
    _hostalt := xpath.get_varchar('/Event/AltOnCall', v_xml);     -- (event)
    _msg := xpath.get_varchar('/Event/Alert/Msg', v_xml);               -- for ticket
    _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', v_xml);          -- for ticket

    _source := COALESCE(xpath.get_varchar('/Event/Source', v_xml), xpath.get_varchar('/Event/Alert/Flavor', v_xml));
    _source_id := COALESCE(standard.enum_value_id('cod', 'source', _source), 1);
    
    _subject := COALESCE(xpath.get_varchar('/Event/Subject', v_xml), _host || ': ' || _comp); -- subject(item)
    _addtags := xpath.get_varchar('/Event/AddTags', v_xml);             -- ticket
    _cc := xpath.get_varchar('/Event/Cc', v_xml);                       -- ticket
    _nohelp := xpath.get_varchar('/Event/Nohelp', v_xml);               -- if true don't prompt for help text
    _helpurl := xpath.get_varchar('/Event/Helpurl', v_xml);             -- (event)
    _starts := now() - (COALESCE(xpath.get_integer('/Event/VisTime', v_xml), 0)::varchar || ' seconds')::interval; -- (item)

    _smid = standard.enum_value_id('cod', 'support_model', _model);        -- (item); (event)
    _severity = 3;                                                      -- (item); (event)
    IF _model = 'A' OR _model = 'B' THEN
        _severity = 2;
    END IF;

    -- check to see if exact duplicate
    SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate 
        WHERE host = _host AND component = _comp ORDER BY item_id ASC LIMIT 1;
    IF _row.item_id IS NOT NULL THEN
        RETURN xmlelement(name "Incident",
                xmlelement(name "Id", _row.item_id),
                xmlelement(name "Ticket", _row.rt_ticket)
        );
    END IF;
    -- check to see if similar duplicate to append alert to the same ticket
/*
    SELECT * INTO _row FROM cod.item_event_duplicate WHERE host = _host AND contact = _contact ORDER BY item_id ASC LIMIT 1;
    IF _row.item_id IS NOT NULL THEN
        INSERT INTO cod.event (item_id, host, component, support_model_id, severity, contact, 
                               oncall_primary, oncall_alternate, content)
            VALUES (_row.item_id, _host, _comp, _smid, _severity, _contact, _hostpri, _hostalt, v_xml);
        RETURN xmlelement(name "Incident",
                xmlelement(name "Id", _row.item_id),
                xmlelement(name "Ticket", _row.rt_ticket)
        );
    END IF;
*/
    -- insert new (incident) item 
    _item_id := nextval('cod.item_id_seq'::regclass);
    INSERT INTO cod.item (id, subject, state_id, itil_type_id, support_model_id, severity, stage_id, started_at, workflow_lock) VALUES (
        _item_id,
        _subject,
        standard.enum_value_id('cod', 'state', 'Processing'),
        standard.enum_value_id('cod', 'itil_type', 'Incident'),
        _smid,
        _severity,
        standard.enum_value_id('cod', 'stage', 'Identification'),
        _starts,
        TRUE
    );
    -- create alert
    _event_id := nextval('cod.event_id_seq'::regclass);
    INSERT INTO cod.event (id, item_id, host, component, support_model_id, severity, contact, 
                           oncall_primary, oncall_alternate, source_id, start_at, content)
        VALUES (_event_id, _item_id, _host, _comp, _smid, _severity, _contact, 
                _hostpri, _hostalt, _source_id, _starts, replace(v_xml::text::varchar, E'<?xml version="1.0"?>\n', ''));
    -- get ticket # for item
    _ticket := cod.create_incident_ticket_from_event(_event_id); 
    -- update item for workflow
    UPDATE cod.item SET 
        rt_ticket     = _ticket, stage_id = standard.enum_value_id('cod', 'stage', 'Initial Diagnosis'), 
        workflow_lock = FALSE
        WHERE id  = _item_id;
    -- IW trigger should execute;
    RETURN xmlelement(name "Incident",
            xmlelement(name "Id", _item_id),
            xmlelement(name "Ticket", _ticket)
    );
END;
$_$;


ALTER FUNCTION cod_v2.spawn_item_from_alert(xml) OWNER TO postgres;

--
-- Name: FUNCTION spawn_item_from_alert(xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION spawn_item_from_alert(xml) IS 'DR: Create an incident from an alert (2012-02-26)';


--
-- PostgreSQL database dump complete
--



COMMIT;
