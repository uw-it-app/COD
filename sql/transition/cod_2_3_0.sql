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
-- Name: dash_update_event(integer); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dash_update_event(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.dash_update_event(integer)
    Description:  Update Dash with Ticket/Owner data
    Affects:      nothing in the database
    Arguments:    integer: event id
    Returns:      boolean
*/
DECLARE
    v_id        ALIAS FOR $1;
    _row        cod.event%ROWTYPE;
    _source     varchar;
    _tickets    text;
    _payload    varchar;
BEGIN
    SELECT * into _row FROM cod.event WHERE id = v_id;
    IF NOT FOUND THEN
        RETURN FALSE;
    ELSEIF _row.host IS NULL OR _row.component IS NULL THEN
        RETURN FALSE;
    END IF;

    _source := (SELECT name FROM cod.source WHERE id = _row.source_id);
    IF _source = 'acc' THEN
        _tickets := (SELECT rt_ticket || ':COD' FROM cod.item where id = _row.item_id) || COALESCE( ',' ||
            (SELECT string_agg(rt_ticket || ':' || owner, ',') FROM cod.escalation WHERE item_id = _row.item_id), '');
        _payload := (xmlelement(name "Alert",
                xmlelement(name "Action", 'Updonly'),
                xmlelement(name "ProblemHost", _row.host),
                xmlelement(name "Component", _row.component),
                xmlelement(name "Ticket", _tickets)
            ))::varchar;
        RETURN dash_v1.injector(
            _payload
        );
    END IF;
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod.dash_update_event(integer) OWNER TO postgres;

--
-- Name: FUNCTION dash_update_event(integer); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dash_update_event(integer) IS 'DR: Update Dash with Ticket/Owner data (2012-06-28)';


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
    _ln         varchar := E'\n';
    _item       cod.item%ROWTYPE;
    _event      cod.event%ROWTYPE;
    _payload    varchar;
    _content    xml;
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

        _content := _event.content::xml;

        _tags := array2.ucat(_tags, appconfig.get('COD_TAG', ''));

        _message := '';
        IF _event.host IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.host);
            _message := _message || 'Hostname: ' || _event.host || _ln;
        END IF;
        IF _event.component IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.component);
            _message := _message || 'Component: ' || _event.component || _ln;
        END IF;
        _message := _message
            || COALESCE(_sep || xpath.get_varchar('/Event/Alert/Msg', _content) ||  _ln, '')
            || COALESCE(_sep || xpath.get_varchar('/Event/Alert/LongMsg', _content) || _ln, '')
            || COALESCE(_sep || E'Operations Performed Actions:\n'
            || xpath.get_varchar('/Action/Note',
                (SELECT content::xml FROM cod.action WHERE item_id = NEW.item_id AND
                    action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText') ORDER BY id DESC LIMIT 1)) || _ln, '')
            || COALESCE(_sep || E'Escalation Note:\n' || xpath.get_varchar('/Escalation/Note', NEW.content::xml) || _ln, '')
            || cod_v2.comment_post();
        _payload := ''
            || 'Subject: ' || _item.subject || _ln
            || 'Queue: ' || NEW.queue || _ln
            || 'Severity: ' || _item.severity::varchar ||  _ln
            || 'Tags: ' || array_to_string(_tags, ' ') || _ln
            || 'Super: ' || _item.rt_ticket || _ln
            || 'Content: ' || _message
            || E'ENDOFCONTENT\nCF-TicketType: Incident\n';

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
-- Name: escalation_dash_update(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_dash_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.escalation_dash_update()
    Description:  Update dash with escalation ownership
    Affects:      Sends data to Dash
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    PERFORM cod.dash_update_event(id) FROM cod.event WHERE item_id = NEW.item_id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN RETURN NEW;
END;
$_$;


ALTER FUNCTION cod.escalation_dash_update() OWNER TO postgres;

--
-- Name: FUNCTION escalation_dash_update(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_dash_update() IS 'DR: Update dash with escalation ownership (2012-06-28)';


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
-- Name: escalation_notify_peers(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_notify_peers() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.escalation_notify_peers()
    Description:  Updates peer escalations (subs) of new escalation
    Affects:      Peer Escalation RT tickets
    Arguments:
    Returns:      trigger
*/
DECLARE
    _sep            varchar := E'------------------------------------------\n';
    _payload        varchar;
BEGIN
    _payload := E'UpdateType: comment\n'
            || E'CONTENT: New escalation:\n'
            || E' -- Oncall Group: "' || NEW.oncall_group || E'"\n'
            || E' -- RT Queue: "' || NEW.queue || E'"\n'
            || E' -- RT Ticket #' || NEW.rt_ticket || E'\n' || _sep
            || COALESCE(xpath.get_varchar('/Escalation/Note', NEW.content::xml), '') || E'\n'
            || cod_v2.comment_post()
            || E'ENDOFCONTENT\n';
    PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation
        WHERE item_id = NEW.item_id AND id <> NEW.id AND
            esc_state_id IN (SELECT id FROM cod.esc_state WHERE sort <= 60); -- Owned or Newer
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$_$;


ALTER FUNCTION cod.escalation_notify_peers() OWNER TO postgres;

--
-- Name: FUNCTION escalation_notify_peers(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_notify_peers() IS 'DR: Updates peer escalations (subs) of new escalation (2012-06-26)';


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
    _sep            varchar := E'------------------------------------------\n';
    _ln             varchar := E'\n';
    _content        xml;
    _message        varchar;
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
            _content := (SELECT content::xml FROM cod.event WHERE item_id = NEW.item_id ORDER BY id ASC LIMIT 1);
            _message := ''
                || COALESCE(_sep || xpath.get_varchar('/Event/Alert/Msg', _content) ||  _ln, '')
                || COALESCE(_sep || xpath.get_varchar('/Event/Alert/LongMsg', _content) || _ln, '')
                || COALESCE(_sep || E'Operations Performed Actions:\n'
                || xpath.get_varchar('/Action/Note',
                    (SELECT content::xml FROM cod.action WHERE item_id = NEW.item_id
                        AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText') ORDER BY id DESC LIMIT 1)) || _ln, '')
                || COALESCE(_sep || E'Escalation Note:\n' || xpath.get_varchar('/Escalation/Note', NEW.content::xml) || _ln, '')
                || cod_v2.comment_post();
            _payload := xmlelement(name "Issue",
                xmlforest(
                    NEW.oncall_group AS "Oncall",
                    NEW.rt_ticket AS "Ticket",
                    (SELECT subject FROM cod.item WHERE id = NEW.item_id) AS "Subject",
                    _message AS "Message",
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
-- Name: incident_nag_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_nag_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.incident_nag_check()
    Description:  Ensure the nag_next time is properly set or unset
    Affects:      Active row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _interval   text;
    _next       timestamptz;
    _model      cod.support_model%ROWTYPE;
BEGIN
    SELECT * INTO _model FROM cod.support_model WHERE id = NEW.support_model_id;
    IF _model.nag IS TRUE AND EXISTS(SELECT NULL FROM cod.escalation JOIN cod.esc_state ON (cod.escalation.esc_state_id = cod.esc_state.id) WHERE cod.escalation.item_id = NEW.id AND cod.esc_state.name NOT IN ('Resolved', 'Rejected', 'Merged') )
    THEN

        IF NEW.nag_interval IS NOT NULL THEN
            -- use item specific interval if set
            _interval := NEW.nag_interval;
        ELSEIF EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id AND esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Owned'))
        THEN
            -- otherwise if there is an owned escalation use the Support Model nag_owned_period
            _interval := _model.nag_owned_period;
        END IF;

        -- if _interval is still null use the system default
        IF _interval IS NULL THEN
            _interval := appconfig.get('COD_DEFAULT_NAG');
        END IF;

        IF _interval ~* 'BHO$' THEN
            -- if the interval end with BHO then it should be during business hours only
            _interval := regexp_replace(_interval, 'BHO$', '');
            _next := hm_v1.get_business_timestamp(
                _interval::interval,
                appconfig.get('COD_NAG_BUSINESS_START')::time,
                appconfig.get('COD_NAG_BUSINESS_END')::time
            );
        ELSE
            -- otherwise just increment now
            _next := now() + _interval::interval;
        END IF;

        -- only update if nag_next is null or if _next is more recent
        IF NEW.nag_next IS NULL OR NEW.nag_next > _next THEN
            NEW.nag_next := _next;
        END IF;
    ELSE
        NEW.nag_next := NULL;
    END IF;
    RETURN NEW;
END;
$_$;


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
    _msgToSuper boolean     := true;
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
        IF _row.reference_no IS DISTINCT FROM xpath.get_varchar('/Item/Do/RefNo', v_xml) THEN
            _msgToSuper := false;
            _message := 'Reference Number: ' || COALESCE(xpath.get_varchar('/Item/Do/RefNo', v_xml), '') || E'\n';
        END IF;
        UPDATE cod.item
            SET subject = xpath.get_varchar('/Item/Do/Subject', v_xml),
                reference_no = xpath.get_varchar('/Item/Do/RefNo', v_xml),
                severity = xpath.get_integer('/Item/Do/Severity', v_xml),
                support_model_id = standard.enum_value_id('cod', 'support_model', xpath.get_varchar('/Item/Do/SupportModel', v_xml))
            WHERE id = v_id;
        --  itil_type_id = standard.enum_value_id('cod', 'itil_type', xpath.get_varchar('/Item/Do/ITILType', v_xml))
    ELSEIF _type = 'Close' THEN
        UPDATE cod.item SET workflow_lock = TRUE, severity = xpath.get_integer('/Item/Do/Severity', v_xml) WHERE id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = TRUE
            WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close');
        UPDATE cod.item SET workflow_lock = FALSE, closed_at = now() WHERE id = v_id;
        _msgType   := 'correspond';
        _msgToSubs := 'none';
        _payload   := E'Status: resolved\nSeverity: Sev' || xpath.get_varchar('/Item/Do/Severity', v_xml);
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
            UPDATE cod.action SET completed_at = now(), successful = FALSE,
                    content = xmlelement(name "Action", xmlelement(name "Note", _message))
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText');
            _message := NULL;
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
            INSERT INTO cod.escalation (item_id, oncall_group, page_state_id, content)
                VALUES (
                    v_id,
                    _oncall,
                    standard.enum_value_id('cod', 'page_state', _page),
                    xmlelement(name "Escalation", xmlelement(name "Note", _message))::varchar
                );
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Failed to create and escalation to the oncall group %', _oncall;
            ELSE
                UPDATE cod.action SET completed_at = now(), successful = TRUE
                    WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
                _message := NULL;
            END IF;
        ELSE
            UPDATE cod.action SET completed_at = now(), successful = TRUE
                WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Escalate');
        END IF;
    ELSEIF _type = 'Nag' THEN
        IF xpath.get_varchar('/Item/Do/Submit', v_xml) = 'Cancel' THEN
            _message := NULL;
        END IF;
        _msgToSuper := FALSE;
        _msgType    := 'correspond';
        _msgToSubs  := 'open';
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
    ELSEIF _type = 'ActivateNotification' THEN
        UPDATE cod.escalation
            SET hm_issue = NULL,
                esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Active'),
                page_state_id = standard.enum_value_id('cod', 'page_state', 'Active'),
                content = xmlelement(name "Escalation", xmlelement(name "Note", _message))
            WHERE item_id = v_id AND id = xpath.get_integer('/Item/Do/EscId', v_xml);
        _message := NULL;
    ELSEIF _type = 'CancelNotification' THEN
        PERFORM hm_v1.close_issue(
            (SELECT hm_issue FROM cod.escalation WHERE item_id = v_id AND id = xpath.get_integer('/Item/Do/EscId', v_xml)),
            'nobody',
            _message
        );
        _message := NULL;
    END IF;

    IF _message IS NOT NULL THEN
        _payload := E'UpdateType: ' || _msgType || E'\n'
                 || E'CONTENT: ' || _message || cod_v2.comment_post()
                 || E'ENDOFCONTENT\n'
                 || _payload;
    END IF;
    IF _payload <> '' THEN
        IF _msgToSuper THEN
            PERFORM rt.update_ticket(_row.rt_ticket, _payload);
        END IF;
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

COMMENT ON FUNCTION item_do_xml(integer, xml) IS 'DR: Perform actions on an item (2012-06-27)';


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
    _subsev     integer;
    _setsev     integer;
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
        _setsev := NULL;
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
        --IF _item.workflow_lock IS FALSE THEN
        --    UPDATE cod.item SET workflow_lock = TRUE WHERE id = _item.id;
        --END IF;
        -- Merge in other tickets
        -- get count of ticket to merge (that haven't been merged)
        -- if >0 then lock and perform merge
        PERFORM cod.item_merge(_item.id, id, FALSE) FROM cod.item WHERE ARRAY[rt_ticket]::integer[] <@ _aliases;
        -- endif
        -- check status (?reset closed if closed?)
        _escs   := xpath('/Incident/Escalations/Escalation', _incident);
        _count2 := array_upper(_escs, 1);
        IF _count2 IS NOT NULL THEN
            -- foreach escalation
            FOR _j in 1.._count2 LOOP
                PERFORM cod_v2.rt_process_escalation(_item.id, _new, _escs[_j]);
                _subsev := xpath.get_integer('/Escalation/Severity', _escs[_j]);
                IF _subsev IS NOT NULL AND (_subsev > _setsev OR _setsev IS NULL) THEN
                    _setsev := _subsev;
                END IF;
            END LOOP;
        END IF;
        IF _setsev IS NOT NULL AND _item.state_id IN (SELECT id FROM cod.state WHERE sort < 99) THEN
            UPDATE cod.item SET workflow_lock = FALSE, severity = _setsev WHERE id = _item.id;
        ELSE
            UPDATE cod.item SET workflow_lock = FALSE WHERE id = _item.id;
        END IF;
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
    --RAISE NOTICE 'ESCALATION, %', v_xml::varchar;
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
                v_item_id,
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
        WHERE ARRAY[rt_ticket]::integer[] <@ _aliases
            AND esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Merged');
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
    _supsev     varchar;
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
    _model := upper(xpath.get_varchar('/Event/Finalized/SupportModel', v_xml));   -- (item); (event)

    -- TODO: remove after transition
    IF _model IS NULL OR _model = 'NULL' THEN
        _model := upper(xpath.get_varchar('/Event/Alert/SupportModel', v_xml));
        IF _model IS NULL OR _model = 'NULL' THEN
            _model := upper(xpath.get_varchar('/Event/SupportModel', v_xml));
        END IF;
    END IF;

    _supsev := xpath.get_varchar('/Event/Finalized/SupportSeverity', v_xml);         -- (item); (event)

    _contact := xpath.get_varchar('/Event/Finalized/Contact', v_xml);       -- (event)

    -- TODO: remove after transition
    IF _contact IS NULL or _contact = 'NULL' THEN
        _contact := xpath.get_varchar('/Event/Alert/Contact', v_xml);       -- (event)
    END IF;

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

    CASE _supsev
        WHEN 'Sev1' THEN _severity := 1;
        WHEN 'Sev2' THEN _severity := 2;
        WHEN 'Sev3' THEN _severity := 3;
        WHEN 'Sev4' THEN _severity := 4;
        WHEN 'Sev5' THEN _severity := 5;
        ELSE
            IF _model IN ('A', 'B') THEN
                _severity := 2;
            ELSE
                _severity := 3;
            END IF;
    END CASE;

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

CREATE TRIGGER t_93_dash_on_insert
    AFTER INSERT ON cod.escalation
    FOR EACH ROW
    EXECUTE PROCEDURE cod.escalation_dash_update();

CREATE TRIGGER t_93_dash_on_update
    AFTER UPDATE ON cod.escalation
    FOR EACH ROW WHEN (OLD.owner <> NEW.owner)
    EXECUTE PROCEDURE cod.escalation_dash_update();


CREATE TRIGGER t_95_notify_peers
    AFTER INSERT ON cod.escalation
    FOR EACH ROW
    EXECUTE PROCEDURE cod.escalation_notify_peers();


COMMIT;
