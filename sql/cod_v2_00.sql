-- create schema

CREATE SCHEMA cod_v2;
GRANT ALL ON SCHEMA cod_v2 TO PUBLIC;

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
        xmlelement(name "Content", event.content),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', event.modified_at)::varchar),
            xmlelement(name "By", event.modified_by)
        )
    ) FROM cod.event AS event
      JOIN cod.support_model AS model ON (event.support_model_id = model.id)
     WHERE id = $1;
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
        xmlelement(name "Completed",
            xmlelement(name "At", date_trunc('second', action.completed_at)::varchar),
            xmlelement(name "By", action.completed_by)
        ),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', action.modified_at)::varchar),
            xmlelement(name "By", action.modified_by)
        )
    ) FROM cod.action AS action
      JOIN cod.action_type AS type ON (action.action_type_id = type.id)
     WHERE id = $1;
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
        xmlelement(name "OncallGroup", e.oncall_group),
        xmlelement(name "Queue", e.queue),
        xmlelement(name "Times", 
            xmlelement(name "Escalated", date_trunc('second', e.escalated_at)::varchar),
            xmlelement(name "Owned", date_trunc('second', e.owned_at)::varchar),
            xmlelement(name "Resolved", date_trunc('second', e.resolved_at)::varchar),
        ),
        xmlelement(name "Content", e.content),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', e.modified_at)::varchar),
            xmlelement(name "By", e.modified_by)
        )
    ) FROM cod.escalation AS e
      JOIN cod.esc_state AS state ON (e.esc_state_id = state.id)
     WHERE id = $1;
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
        xmlelement(name "RTTicket", item.rt_ticket),
        xmlelement(name "HMIssue", item.hm_issue),
        xmlelement(name "State", state.name),
        xmlelement(name "ITILType", itil.name),
        xmlelement(name "SupportModel", model.name),
        xmlelement(name "Severity", item.severity),
        xmlelement(name "Stage", stage.name),
        xmlelement(name "Times",
            xmlelement(name "Started", date_trunc('second', item.started_at)::varchar),
            xmlelement(name "Ended", date_trunc('second', item.ended_at)::varchar),
            xmlelement(name "Resolved", date_trunc('second', item.resolved_at)::varchar),
            xmlelement(name "Closed", date_trunc('second', item.closed_at)::varchar),
        ),
        xmlelement(name "Events",
            (SELECT xmlagg(cod_v2.event_xml(e.id) FROM
               (SELECT id FROM cod.event WHERE item_id = $1 ORDER BY id) AS e
            )  
        ),
        xmlelement(name "Actions",
            (SELECT xmlagg(cod_v2.action_xml(a.id) FROM
               (SELECT id FROM cod.action WHERE item_id = $1 ORDER BY id) AS a
            )  
        ),
        xmlelement(name "Escalations",
            (SELECT xmlagg(cod_v2.escalation_xml(x.id) FROM
               (SELECT id FROM cod.escalation WHERE item_id = $1 ORDER BY id) AS x
            )
        ),
        xmlelement(name "Content", item.content),
        xmlelement(name "Created",
            xmlelement(name "At", date_trunc('second', item.created_at)::varchar),
            xmlelement(name "By", item.created_by)
        ),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', item.modified_at)::varchar),
            xmlelement(name "By", item.modified_by)
        )
    ) FROM cod.item AS item
      JOIN cod.state AS state ON (item.state_id = state.id)
      JOIN cod.itil_type AS itil ON (item.itil_type_id = itil.id)
      JOIN cod.support_model AS model ON (item.support_model_id = model.id)
      LEFT JOIN cod.stage AS stage ON (item.stage_id = stage.id)
     WHERE id = $1;
$_$;

COMMENT ON FUNCTION cod_v2.item_xml(integer) IS 'DR: Retrive XML representation of an item (2011-10-17)';

-- REST PUTItem

-- REST get cached list (active, all)

-- REST spawn from alert

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
    WHEN OTHERS THEN FALSE;
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
BEGIN
    -- read event data
    
    _netid := xpath.get_varchar('/Event/Netid');
    -- can this netid spawn?
    IF cod_v2.can_spawn(_netid) IS TRUE THEN
        -- if yes set uwit.uwnetid
        EXECUTE 'SET LOCAL uwit.uwnetid = ' || quote_literal(_netid);
    ELSE
        -- else return rejection
        RAISE EXCEPTION 'User is not authorized to create incidents via COD: %', _netid;
    END IF

    _ticket := xpath.get_integer('/Event/Alert/Ticket', v_xml);         -- check
    -- IF ticket is active then return that ticket's info else continue.
    IF _ticket IS NOT NULL and _ticket > 0 THEN
        SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate WHERE rt_ticket = _ticket LIMIT 1;
        IF _row.id IS NOT NULL THEN
            RETURN xmlelement(name 'Incident',
                    xmlelement(name 'Id', _row.item_id),
                    xmlelement(name 'Ticket', _row.rt_ticket)
            );
        END IF;
    END IF;

    _host := xpath.get_varchar('/Event/Alert/ProblemHost', v_xml);      -- subject(item); (event)
    _comp := xpath.get_varchar('/Event/Alert/Component', v_xml);        -- subject(item); (event)
    _model := upper(xpath.get_varchar('/Event/SupportModel', v_xml));   -- (item); (event)
    _contact := xpath.get_varchar('/Event/Alert/Contact', v_xml);       -- (event)
    _hostpri := xpath.get_varchar('/Event/Event/OnCall', v_xml);        -- (event)
    _hostalt := xpath.get_varchar('/Event/Event/AltOnCall', v_xml);     -- (event)
    _msg := xpath.get_varchar('/Event/Alert/Msg', v_xml);               -- for ticket
    _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', v_xml);          -- for ticket
    _flavor := xpath.get_varchar('/Event/Alert/Flavor', v_xml);         -- for sending to prox, acc
    _source := xpath.get_varchar('/Event/Source', v_xml);               -- for sending to prox, acc

    _source := COALESCE(xpath.get_varchar('/Event/Source', v_xml), xpath.get_varchar('/Event/Alert/Flavor', v_xml));
    _source_id := COALESCE(standard.enum_value_id('cod.source', _source), 1);
    
    _subject := COALESCE(xpath.get_varchar('/Event/Subject', v_xml), _host || ': ' || _comp); -- subject(item)
    _addtags := xpath.get_varchar('/Event/AddTags', v_xml);             -- ticket
    _cc := xpath.get_varchar('/Event/Cc', v_xml);                       -- ticket
    _nohelp := xpath.get_varchar('/Event/Nohelp', v_xml);               -- if true don't prompt for help text
    _helpurl := xpath.get_varchar('/Event/Helpurl', v_xml);             -- (event)
    _starts := now() - (COALESCE(xpath.get_integer('/Event/VisTime', v_xml), 0)::varchar || ' seconds')::interval; -- (item)

    _smid = standard.enum_value_id('cod.support_model', _model);        -- (item); (event)
    _severity = 3;                                                      -- (item); (event)
    IF _model = 'A' OR _model = 'B' THEN
        _severity = 2;
    END IF;

    -- check to see if exact duplicate
    SELECT item_id, rt_ticket INTO _row FROM cod.item_event_duplicate WHERE host = _host AND component = _component ORDER BY i.id ASC LIMIT 1;
    IF _row.id IS NOT NULL THEN
        RETURN xmlelement(name 'Incident',
                xmlelement(name 'Id', _row.item_id),
                xmlelement(name 'Ticket', _row.rt_ticket)
        );
    END IF;
    -- check to see if similar duplicate to append alert to the same ticket
/*
    SELECT * INTO _row FROM cod.item_event_duplicate WHERE host = _host AND contact = _contact ORDER BY i.id ASC LIMIT 1;
    IF _row.id IS NOT NULL THEN
        INSERT INTO cod.event (item_id, host, component, support_model_id, severity, contact, 
                               oncall_primary, oncall_alternate, content)
            VALUES (_row.item_id, _host, _comp, _smid, _severity, _contact, _hostpri, _hostalt, v_xml);
        RETURN xmlelement(name 'Incident',
                xmlelement(name 'Id', i.id),
                xmlelement(name 'Ticket', i.rt_ticket)
        );
    END IF;
*/
    -- insert new (incident) item 
    _item_id := nexval('cod.item_id_seq'::text);
    INSERT INTO cod.item (id, state_id, itil_type_id, support_model_id, severity, stage_id, started_at, content) VALUES (
        _item_id,
        standard.enum_value_id('cod.state', 'Building'),
        standard.enum_value_id('cod.itil_type', 'Incident'),
        _smid,
        _severity,
        standard.enum_value_id('cod.stage', 'Identification'),
        _starts,
        v_xml
    );
    -- create alert
    _event_id := nexval('cod.event_id_seq'::text);
    INSERT INTO cod.event (id, item_id, host, component, support_model_id, severity, contact, 
                           oncall_primary, oncall_alternate, source_id, content)
        VALUES (_event_id, _item_id, _host, _comp, _smid, _severity, _contact, _hostpri, _hostalt, _source_id, v_xml);
    -- get ticket # for item
    _ticket := cod.create_incident_ticket(_event_id); -- TODO: needs function
    -- update item for workflow
    UPDATE cod.item SET rt_ticket = _ticket, stage_id = standard.enum_value_id('cod.stage', 'Initial Diagnosis'), state_id = something
        WHERE id = _id;
    -- IW trigger should execute;
    RETURN xmlelement(name 'Incident',
        xmlelement(name 'Id', _id),
        xmlelement(name 'Ticket', _ticket)
    );
END;
$_$;

COMMENT ON FUNCTION () IS '';


-- REST spawn from notification

