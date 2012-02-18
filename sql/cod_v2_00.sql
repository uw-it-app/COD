BEGIN;
-- create schema

CREATE SCHEMA cod_v2;
GRANT ALL ON SCHEMA cod_v2 TO PUBLIC;

COMMENT ON SCHEMA cod_v2 IS 'DR: COD REST API v2 (2011-11-16)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.event_xml(integer) RETURNS xml
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
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
        xmlelement(name "Message", xpath.get_varchar('/Event/Alert/Msg', event.content::xml)),
        xmlelement(name "LongMessage", xpath.get_varchar('/Event/Alert/LongMsg', event.content::xml)),
        xmlelement(name "Content", event.content),
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

COMMENT ON FUNCTION cod_v2.event_xml(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.action_xml(integer) RETURNS xml
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
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

COMMENT ON FUNCTION cod_v2.action_xml(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.escalation_xml(integer) RETURNS xml
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
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

COMMENT ON FUNCTION cod_v2.escalation_xml(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.item_xml(integer) RETURNS xml
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
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

COMMENT ON FUNCTION cod_v2.item_xml(integer) IS 'DR: Retrive XML representation of an item (2011-10-17)';

-- REST PUTItem
/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.item_do_xml(integer, xml) RETURNS xml
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
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
    _msgToSubs  boolean     := TRUE;
    _msgStatus  varchar;
    _success    boolean;
    _payload    varchar;
    _owner      varchar;
    _page       varchar;
    _oncall     varchar;
    _row        cod.item%ROWTYPE;
BEGIN
    SELECT * INTO _row FROM cod.item WHERE id = v_id;
    IF _row.id IS NULL THEN
        RETURN NULL;
    END IF;
    _id      := xpath.get_integer('/Item/Do/Id', v_xml);
    _type    := xpath.get_varchar('/Item/Do/Type', v_xml);
    _message := xpath.get_varchar('/Item/Do/Message', v_xml);
    IF _type = 'RefNumber' THEN
        UPDATE cod.item SET reference_no = xpath.get_varchar('/Item/Do/Value', v_xml) WHERE id = v_id;
        _message   := 'Reference Number set: ' || xpath.get_varchar('/Item/Do/Value', v_xml);
        _msgToSubs := FALSE;
    ELSEIF _type = 'Close' THEN
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_id;
        UPDATE cod.action SET completed_at = now(), successful = TRUE
            WHERE item_id = v_id AND completed_at IS NULL AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close');
        UPDATE cod.item SET workflow_lock = FALSE, closed_at = now() WHERE id = v_id;
        _msgType   := 'correspond';
        _msgToSubs := FALSE;
        _msgStatus := 'resovled';
    ELSEIF _type = 'Clear' THEN
        UPDATE cod.event SET end_at = now() WHERE item_id = v_id;
    ELSEIF _type = 'Reactivate' THEN
        UPDATE cod.event SET end_at = NULL WHERE item_id = v_id;
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
        _msgToSubs := FALSE;
    ELSEIF _type = 'Message' THEN
        _msgType := xpath.get_varchar_check('/Item/Do/MsgType', v_xml, _msgType);
        IF xpath.get_varchar('/Item/Do/ToSubs', v_xml) = 'no' THEN
            _msgToSubs := FALSE;
        END IF;
    ELSEIF _type = 'SetOwner' THEN
        _owner := xpath.get_varchar('/Item/Do/Owner', v_xml);
        IF _owner IS NOT NULL THEN
            UPDATE cod.escalation SET owner = _owner WHERE item_id = v_id AND id = xpath.get_integer('/Item/Do/EscId', v_xml);
        END IF;
    ELSEIF _type = 'Escalate' THEN
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
        INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (v_id, _oncall, standard.enum_value_id('cod', 'page_state', _page));
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Failed to create and escalation to the oncall group %', _oncall;
        END IF;
    ELSEIF _type = 'Nag' THEN
        RAISE NOTICE 'Reset nag times';
    ELSEIF _type = 'SetNag' THEN
        RAISE NOTICE 'Set Nag time';
    END IF;
    IF _message IS NOT NULL THEN
        -- send to rt
        _payload := E'UpdateType: ' || _msgType || E'\n'
                 || E'CONTENT: ' || _message || E'\n'
                 || E'ENDOFCONTENT\n';
        IF _msgStatus is NOT NULL THEN
            _payload := _payload || 'Status: ' || _msgStatus || E'\n';
        END IF;
        PERFORM rt.update_ticket(_row.rt_ticket, _payload);
        IF _msgToSubs IS TRUE THEN
            PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation WHERE item_id = _row.id;
        END IF;
    END IF;
    RETURN cod_v2.item_xml(v_id);
END;
$_$;

COMMENT ON FUNCTION cod_v2.item_do_xml(integer, xml) IS 'DR: Perform actions on an item (2012-02-13)';



/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.items_xml() RETURNS xml
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod_v2.items_xml()
    Description:  List of cod items
    Affects:      nothing
    Arguments:    none
    Returns:      XML list of items
*/
SELECT xmlelement(name "Items",
    (SELECT xmlagg(cod_v2.item_xml(id)) FROM (SELECT i.id FROM cod.item i JOIN cod.state s ON (i.state_id=s.id) WHERE s.sort < 90 OR i.closed_at > now() - '1 hour'::interval ORDER BY s.sort ASC, i.rt_ticket DESC) AS foo),
    xmlelement(name "ModifiedAt", (SELECT max(modified_at) FROM cod.item))
);
$_$;

COMMENT ON FUNCTION cod_v2.items_xml() IS 'DR: List of cod items (2011-11-30)';

-- REST get cached list (active, all)

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.can_spawn(varchar) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
*/
DECLARE
BEGIN
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;

COMMENT ON FUNCTION cod_v2.can_spawn(varchar) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.spawn_item_from_alert(xml) RETURNS xml
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
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
    SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate WHERE host = _host AND component = _comp ORDER BY item_id ASC LIMIT 1;
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
        VALUES (_event_id, _item_id, _host, _comp, _smid, _severity, _contact, _hostpri, _hostalt, _source_id, _starts, v_xml::text::varchar);
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

COMMENT ON FUNCTION cod_v2.spawn_item_from_alert(xml) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.process_hm_update(xml) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod_v2.process_hm_update(xml)
    Description:  Process HM Issues state for COD
    Affects:      COD.item/escalation/action associated with this H&M notification
    Arguments:    
    Returns:      xml
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _hm_id      integer;
    _ticket     integer;
    _activity   varchar;
    _content    varchar;
    _row        record;
    _action     cod.action%ROWTYPE;
BEGIN
    _hm_id    := xpath.get_integer('/Issue/Id', v_xml);
    _ticket   := xpath.get_integer('/Issue/Ticket', v_xml);
    _activity := xpath.get_varchar('/Issue/Activity', v_xml);
    SELECT * INTO _row FROM cod.escalation WHERE rt_ticket = _ticket AND (hm_issue IS NULL OR hm_issue = _hm_id);
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
            _content := xpath('/Issue/CurrentSquawk', v_xml)::text::varchar;
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
    IF _row.id IS NOT NULL THEN
        --RAISE NOTICE 'H&M direct interaction with Item';
        RETURN TRUE;
    END IF;

    --RAISE NOTICE 'Create item for this H&M notification';
    RETURN TRUE;
--EXCEPTION
--    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;

COMMENT ON FUNCTION cod_v2.process_hm_update(xml) IS 'DR: Process HM Issues state for COD (2012-02-07)';

COMMIT;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.inject(varchar, varchar) RETURNS xml
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.inject(varchar, varchar)
    Description:  Inject a faux alert
    Affects:      
    Arguments:    
    Returns:      xml
*/
SELECT cod_v2.spawn_item_from_alert(('<Event><Netid>joby</Netid><Operator>AIE-AE</Operator><OnCall>ssg_oncall</OnCall><AltOnCall>uwnetid_joby</AltOnCall><SupportModel>' || $2 || '</SupportModel><LifeCycle>deployed</LifeCycle><Source>prox</Source><VisTime>500</VisTime><Alert><ProblemHost>' || $1 || '</ProblemHost><Flavor>prox</Flavor><Origin/><Component>joby-test</Component><Msg>Test</Msg><LongMsg>Just a test by joby</LongMsg><Contact>uwnetid_joby</Contact><Owner/><Ticket/><IssueNum/><ItemNum/><Severity>10</Severity><Count>1</Count><Increment>false</Increment><StartTime>1283699633122</StartTime><AutoClear>true</AutoClear><Action>Upd</Action></Alert></Event>')::xml);
$_$;

COMMENT ON FUNCTION cod.inject(varchar, varchar) IS 'DR: Inject a faux alert (2012-02-15)';


--select cod_v2.spawn_item_from_alert('<Event><Netid>joby</Netid><Operator>AIE-AE</Operator><OnCall>ssg_oncall</OnCall><AltOnCall>uwnetid_joby</AltOnCall><SupportModel>C</SupportModel><LifeCycle>deployed</LifeCycle><Source>prox</Source><VisTime>500</VisTime><Alert><ProblemHost>ssgdev.cac.washington.edu</ProblemHost><Flavor>prox</Flavor><Origin/><Component>joby-test</Component><Msg>Test</Msg><LongMsg>Just a test by joby</LongMsg><Contact>uwnetid_joby</Contact><Owner/><Ticket/><IssueNum/><ItemNum/><Severity>10</Severity><Count>1</Count><Increment>false</Increment><StartTime>1283699633122</StartTime><AutoClear>true</AutoClear><Action>Upd</Action></Alert></Event>'::xml);
--select cod_v2.spawn_item_from_alert('<Event><Netid>joby</Netid><Operator>AIE-AE</Operator><OnCall>ssg_oncall</OnCall><AltOnCall>uwnetid_joby</AltOnCall><SupportModel>A</SupportModel><LifeCycle>deployed</LifeCycle><Source>prox</Source><VisTime>500</VisTime><Alert><ProblemHost>ssgdev5.cac.washington.edu</ProblemHost><Flavor>prox</Flavor><Origin/><Component>joby-test</Component><Msg>Test</Msg><LongMsg>Just a test by joby</LongMsg><Contact>uwnetid_joby</Contact><Owner/><Ticket/><IssueNum/><ItemNum/><Severity>10</Severity><Count>1</Count><Increment>false</Increment><StartTime>1283699633122</StartTime><AutoClear>true</AutoClear><Action>Upd</Action></Alert></Event>'::xml);