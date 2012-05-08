BEGIN;


ALTER TABLE cod_history.support_model ADD COLUMN nag_owned_period text DEFAULT '24 hours BHO';
ALTER TABLE cod.support_model ADD COLUMN nag_owned_period text DEFAULT '24 hours BHO';

ALTER TABLE cod_history.item ALTER COLUMN nag_interval DROP NOT NULL;
ALTER TABLE cod_history.item ALTER COLUMN nag_interval DROP DEFAULT;
ALTER TABLE cod.item ALTER COLUMN nag_interval DROP NOT NULL;
ALTER TABLE cod.item ALTER COLUMN nag_interval DROP DEFAULT;


UPDATE cod.support_model SET nag_owned_period = ('00:30:00'::interval)::text WHERE active_notification IS TRUE;
UPDATE cod.support_model SET nag = TRUE;

INSERT INTO appconfig.setting (key, data) VALUES 
    ('COD_DEFAULT_NAG', '24 hours BHO'),
    ('COD_NAG_BUSINESS_START', '09:30:00'),
    ('COD_NAG_BUSINESS_END', '17:00:00');
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
    IF _model.nag IS TRUE AND EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id) THEN

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
            _interval = regexp_replace(_interval, 'BHO$', '');
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

SET search_path = cod_history, pg_catalog;

--
-- Name: restore_item(integer); Type: FUNCTION; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE FUNCTION restore_item(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_history.restore_item(integer)
    Description:  Restore a cod.item and associated records that have been deleted
    Affects:      Inserts cod.item and associated records
    Arguments:    integer: ID of the item to restore.
    Returns:      boolean
*/
DECLARE
    v_item_id       ALIAS FOR $1;
BEGIN
    -- is a deleted item?
    IF EXISTS(SELECT NULL FROM cod.item WHERE id = v_item_id) THEN
        RAISE EXCEPTION 'Item ID currently exists: %', v_item_id;
    END IF;

    IF NOT EXISTS(SELECT NULL FROM cod_history.item WHERE id = v_item_id) THEN
        RAISE EXCEPTION 'Item ID never existed: %', v_item_id;
    END IF;
    -- disable modified updating
    ALTER TABLE cod.item disable trigger ALL;
    -- restore item with workflow disabled
    INSERT INTO cod.item (workflow_lock, modified_at, modified_by, id, created_at, created_by, rt_ticket, hm_issue, subject, state_id, itil_type_id, support_model_id, severity, stage_id, reference_no, started_at, ended_at, escalated_at, resolved_at, closed_at, content, nag_interval, nag_next) SELECT true, modified_at, modified_by, id, created_at, created_by, rt_ticket, hm_issue, subject, state_id, itil_type_id, support_model_id, severity, stage_id, reference_no, started_at, ended_at, escalated_at, resolved_at, closed_at, content, nag_interval, nag_next FROM cod_history.item WHERE id = v_item_id AND deleted = true ORDER BY modified_at DESC LIMIT 1;
    -- restore events
    ALTER TABLE cod.event disable trigger ALL;
    INSERT INTO cod.event (modified_at, modified_by, id, item_id, host, component, support_model_id, severity, contact, oncall_primary, oncall_alternate, helptext, source_id, start_at, end_at, content) 
        SELECT modified_at, modified_by, id, item_id, host, component, support_model_id, severity, contact, oncall_primary, oncall_alternate, helptext, source_id, start_at, end_at, content 
        FROM cod_history.event 
        JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.event GROUP BY id) AS uni ON (id = uid AND modified_at = mod)
        WHERE item_id = v_item_id;
    ALTER TABLE cod.event enable trigger ALL;
    -- restore actions
    ALTER TABLE cod.action disable trigger ALL;
    INSERT INTO cod.action (modified_at, modified_by, id, item_id, escalation_id, action_type_id, started_at, completed_at, completed_by, skipped, successful, content)
        SELECT modified_at, modified_by, id, item_id, escalation_id, action_type_id, started_at, completed_at, completed_by, skipped, successful, content
        FROM cod_history.action
        JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.action GROUP BY id) AS uni ON (id = uid AND modified_at = mod)
        WHERE item_id = v_item_id;
    ALTER TABLE cod.action enable trigger ALL;
    -- restore escalations
    ALTER TABLE cod.escalation disable trigger ALL;
    INSERT INTO cod.escalation (modified_at, modified_by, id, item_id, rt_ticket, hm_issue, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at, owned_at, resolved_at, content)
        SELECT modified_at, modified_by, id, item_id, rt_ticket, hm_issue, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at, owned_at, resolved_at, content 
        FROM cod_history.escalation
        JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.escalation GROUP BY id) AS uni ON (id = uid AND modified_at = mod)
        WHERE item_id = v_item_id;
    ALTER TABLE cod.escalation enable trigger ALL;
    -- update item to allow workflow
    UPDATE cod.item SET workflow_lock = false WHERE id = v_item_id;
    -- enable modified updating
    ALTER TABLE cod.item enable trigger ALL;
    RETURN TRUE;
END;
$_$;

-- 144, 411

ALTER FUNCTION cod_history.restore_item(integer) OWNER TO postgres;

--
-- Name: FUNCTION restore_item(integer); Type: COMMENT; Schema: cod_history; Owner: postgres
--

COMMENT ON FUNCTION restore_item(integer) IS 'DR: Restore a cod.item and associated records that have been deleted (2012-04-16)';


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
-- Name: item_brief_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_brief_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.item_brief_xml(integer)
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
        xmlelement(name "Escalations",
            (SELECT xmlagg(cod_v2.escalation_xml(x.id)) FROM
               (SELECT id FROM cod.escalation WHERE item_id = $1 ORDER BY id DESC) AS x
            )
        ),
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


ALTER FUNCTION cod_v2.item_brief_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION item_brief_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION item_brief_xml(integer) IS 'DR: Retrive Brief XML representation of an item (2011-10-17)';


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
            (SELECT xmlagg(cod_v2.item_brief_xml(id)) FROM (
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

SET search_path = cod_history, pg_catalog;

--
-- Name: action_last; Type: VIEW; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE VIEW action_last AS
    SELECT modified_at, modified_by, id, item_id, escalation_id, action_type_id, started_at, completed_at, completed_by, skipped, successful, content
    FROM cod_history.action
    JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.action GROUP BY id) AS uni ON (id = uid AND modified_at = mod);


ALTER TABLE cod_history.action_last OWNER TO postgres;

--
-- Name: TABLE action_last; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON VIEW action_last IS 'DR: Show the last state of an action (2012-04-16)';


--
-- Name: action_last; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE action_last FROM PUBLIC;
REVOKE ALL ON TABLE action_last FROM postgres;
GRANT ALL ON TABLE action_last TO postgres;
GRANT SELECT ON TABLE action_last TO PUBLIC;


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

SET search_path = cod_history, pg_catalog;

--
-- Name: escalation_last; Type: VIEW; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE VIEW escalation_last AS
    SELECT modified_at, modified_by, id, item_id, rt_ticket, hm_issue, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at, owned_at, resolved_at, content 
    FROM cod_history.escalation
    JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.escalation GROUP BY id) AS uni ON (id = uid AND modified_at = mod);


ALTER TABLE cod_history.escalation_last OWNER TO postgres;

--
-- Name: TABLE escalation_last; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON VIEW escalation_last IS 'DR: Show the last state of an escalation (2012-04-16)';


--
-- Name: escalation_last; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE escalation_last FROM PUBLIC;
REVOKE ALL ON TABLE escalation_last FROM postgres;
GRANT ALL ON TABLE escalation_last TO postgres;
GRANT SELECT ON TABLE escalation_last TO PUBLIC;


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

SET search_path = cod_history, pg_catalog;

--
-- Name: event_last; Type: VIEW; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE VIEW event_last AS
    SELECT modified_at, modified_by, id, item_id, host, component, support_model_id, severity, contact, oncall_primary, oncall_alternate, helptext, source_id, start_at, end_at, content 
    FROM cod_history.event 
    JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.event GROUP BY id) AS uni ON (id = uid AND modified_at = mod);


ALTER TABLE cod_history.event_last OWNER TO postgres;

--
-- Name: TABLE event_last; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON VIEW event_last IS 'DR: Most recent state of an event (2012-04-16)';


--
-- Name: event_last; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE event_last FROM PUBLIC;
REVOKE ALL ON TABLE event_last FROM postgres;
GRANT ALL ON TABLE event_last TO postgres;
GRANT SELECT ON TABLE event_last TO PUBLIC;


--
-- PostgreSQL database dump complete
--


-- update cod.item to set nat_inteval to null where default and not closed
UPDATE cod.item SET nag_interval = NULL WHERE nag_interval = ('00:30:00'::interval)::varchar AND state_id IN (SELECT id FROM cod.state WHERE name NOT IN ('Closed', 'Merged'));



COMMIT;
