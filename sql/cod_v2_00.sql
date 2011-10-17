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
        xmlelement(name "ReferenceApplication", app.name),
        xmlelement(name "Reference", e.reference),
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
      JOIN cod.ref_app AS app ON (e.ref_app_id = app.id)
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
        xmlelement(name "ReferenceApplication", app.name),
        xmlelement(name "Reference", item.reference),
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
      JOIN cod.ref_app AS app ON (item.ref_app_id = app.id)
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

-- REST spawn from notification

