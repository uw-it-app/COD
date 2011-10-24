/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.create_incident_ticket_from_event(integer) RETURNS integer
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.create_incident_ticket_from_event(integer)
    Description:  Create an RT Ticket from an event
    Affects:      Creates an RT ticket
    Arguments:    integer: alert id to base the incident ticket on
    Returns:      integer: RT ticket number
*/
    -- needs subject (host: component), message, queue (COPS), severity, tags, CCs, creator
DECLARE
    v_event_id  integer;
    _sep        varchar := E'------------------------------------------\n';
    _row        record;
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
    SELECT * INTO _row FROM cod.event WHERE id = v_id;
    IF _row.id IS NULL THEN
        RAISE EXCEPTION 'InternalError: Event does not exist to create indicent ticket: %', v_id;
    END IF;

    _msg := xpath.get_varchar('/Event/Alert/Msg', _row.content);
    _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', _row.content);
    _subject := COALESCE(xpath.get_varchar('/Event/Subject', _row.content), _row.host || ': ' || _row.component);
    _addtags := xpath.get_varchar('/Event/AddTags', _row.content);
    _cc := xpath.get_varchar('/Event/Cc', _row.content);

    _tags := regexp_split_to_array(_addtags, E'[, ]+', 'g');
    _tags := array2.ucat(_tags, _row.host);
    _tags := array2.ucat(_tags, _row.componenet);
    _tags := array2.ucat(_tags, 'COD');

    _message := ''
    IF _row.host IS NOT NULL THEN
        _message := _message || 'Hostname: ' || _row.host || E'\n';
    END IF;
    IF _row.component IS NOT NULL THEN
        _message := _message || 'Component: ' || _row.component || E'\n';
    END IF;
    IF _msg IS NOT NULL THEN
        _message || _sep || _msg || E'\n';
    END IF;
    IF _lmsg IS NOT NULL OR _lmsg <> _msg THEN
        _message || _sep || _lmsg || E'\n';
    END IF;
    _message := _message || _sep ||
        'Created By: ' || _row.modified_by || E'\n' ||
        E'UW Information Technology - Computer Operations\n' ||
        E'Email: copstaff@uw.edu\n' ||
        E'Phone: 206-685-1270\n';
        
    _payload := 'Subject: ' || _subject || E'\n' ||
                E'Queue: COPS\n' ||
                'Severity: ' || _row.severity::varchar ||  E'\n' ||
                'Tags: ' || array_to_string(_tags, ' ') || E'\n' ||
                'Starts: ' || _row.start_at::varchar || E'\n' ||
                'Cc: ' || _cc  || E'\n' ||
                'Content: ' || _message ||
                E'ENDOFCONTENT\n'
    RETURN rt.create_ticket(_payload);
EXCEPTION
    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION cod.create_incident_ticket_from_event(integer) IS 'DR: Create an RT Ticket from an event (2011-10-21)';

-- Incident workflow manager

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.incident_workflow() RETURNS trigger
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
    -- need to create ticket?
        -- request new ticket
    IF NEW.rt_ticket IS NULL THEN
        NEW.rt_ticket := rt.create_ticket_from_oncall(
    END IF;
    -- if  cleared
        -- if just set to cleared
            -- set message to RT (push to children)
            -- cancel H&M active notifications
        -- If all escalations resolved prompt operator to resolve ticket
        -- exit

    -- if support model calls for helptext and no unsatisfied helptext action
        -- create action to prompt for acting on helptext
        -- exit
    -- if not helptexting, escalate
        -- if no valid oncall group 
            -- if and no outstanding action to set one then 
                -- create action to prompt to correct oncall group
            -- else exit
        -- create escalation (see escalation_workflow)
END;
$_$;

COMMENT ON FUNCTION () IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.escalation_workflow() RETURNS trigger
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
    -- active & no H&M?
        -- prompt H&M
    -- 
EXCEPTION
    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION () IS '';
