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

