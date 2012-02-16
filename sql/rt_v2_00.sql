BEGIN;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION rt_v2.escalation_xml(integer) RETURNS xml
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     rt_v2.escalation_xml(integer)
    Description:  Description of an incident escalation
    Affects:      nothing
    Arguments:    integer: id of ticket to describe
    Returns:      xml
*/
    SELECT xmlelement(name "Escalation",
        xmlelement(name "Id", ticket.id),
        xmlelement(name "Type", type.content),
        xmlelement(name "Subject", ticket.subject),
        xmlelement(name "Queue", queue.name),
        xmlelement(name "Status", ticket.status),
        xmlelement(name "Owner", lower(users.name))
    ) FROM public.tickets_active AS ticket
      JOIN public.objectcustomfieldvalues AS type ON (type.customfield = 270 AND type.objecttype = 'RT::Ticket' AND type.content = 'Incident' AND type.objectid = ticket.id)
      JOIN public.queues AS queue ON (ticket.queue = queue.id)
      JOIN public.users AS users ON (ticket.owner = users.id)
     WHERE ticket.id = $1;
$_$;

COMMENT ON FUNCTION rt_v2.escalation_xml(integer) IS 'DR: Description of an incident escalation (2012-02-15)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION rt_v2.incident_xml(integer) RETURNS xml
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     rt_v2.incident_xml(integer)
    Description:  Description of this incident including subs
    Affects:      nothing
    Arguments:    integer: id of the incident ticket
    Returns:      xml
*/
    SELECT xmlelement(name "Incident",
        xmlelement(name "Id", ticket.id),
        xmlelement(name "Type", type.content),
        xmlelement(name "Subject", ticket.subject),
        xmlelement(name "Queue", queue.name),
        xmlelement(name "Status", ticket.status),
        xmlelement(name "Escalations",
            (SELECT xmlagg(rt_v2.escalation_xml(link.localbase))
             FROM public.links AS link
            WHERE link.localtarget = $1 AND link.type= 'Super')
        )
    ) FROM public.tickets_active AS ticket
      JOIN public.objectcustomfieldvalues AS type ON (type.customfield = 270 AND type.objecttype = 'RT::Ticket' AND type.content = 'Incident' AND type.objectid = ticket.id)
      JOIN public.queues AS queue ON (ticket.queue = queue.id)
     WHERE ticket.id = $1;
$_$;

COMMENT ON FUNCTION rt_v2.incident_xml(integer) IS 'DR: Description of this incident including subs (2012-02-15)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION rt_v2.incidents_xml(varchar) RETURNS xml
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     rt_v2.incidents_xml(varchar)
    Description:  Retrieve XML Representation of the Incidents
                  in the provided queue and their subs
    Affects:      nothing
    Arguments:    varchar: queue
    Returns:      xml
*/
DECLARE
    v_queue     ALIAS FOR $1;
    _queueid    integer;
BEGIN
    _queueid := (SELECT id FROM queues WHERE name = v_queue);
    RETURN xmlelement(name "Incidents",
        (SELECT xmlagg(rt_v2.incident_xml(id)) FROM (
            SELECT t.id 
                FROM tickets_active AS t 
                JOIN objectcustomfieldvalues AS o ON (
                    t.id = o.objectid AND 
                    o.objecttype = 'RT::Ticket' AND 
                    o.customfield = 270 AND 
                    o.content = 'Incident'
                ) 
                WHERE queue = _queueid AND
                    (
                        t.status IN ('new', 'open', 'stalled') OR 
                        (t.lastupdated::varchar||'+0')::timestamptz > now() - '1 hour'::interval
                    ) AND
                    NOT EXISTS(
                        SELECT NULL FROM links AS l 
                            JOIN objectcustomfieldvalues AS cf ON (
                                l.localbase = cf.objectid AND 
                                cf.objecttype = 'RT::Ticket' AND 
                                cf.customfield = 270 AND 
                                o.content = 'Incident'
                            )
                            JOIN tickets_active AS a ON (
                                l.localtarget = a.id AND
                                queue=_queueid
                            )
                            WHERE l.localbase = t.id AND l.type= 'Super'
                    ) order by t.id desc
        ) as foo)
    );
END;
$_$;

COMMENT ON FUNCTION rt_v2.incidents_xml(varchar) IS 'DR: Retrieve XML Representation of the Incidents
 (2012-02-15)';

 COMMIT;
