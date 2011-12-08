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

    _tags := regexp_split_to_array(_addtags, E'[, ]+', 'g');
    _tags := array2.ucat(_tags, 'COD-DEV'::varchar);

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
                E'Queue: SSG::Test\n' ||
                'Severity: ' || _row.severity::varchar ||  E'\n' ||
                'Tags: ' || array_to_string(_tags, ' ') || E'\n' ||
                'Starts: ' || _row.start_at::varchar || E'\n' ||
                'Cc: ' || _cc  || E'\n' ||
                'Content: ' || _message ||
                E'ENDOFCONTENT\n';

    RETURN rt.create_ticket(_payload);
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
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
    _oncall     varchar;
    _row        record;
BEGIN
    -- need to create ticket?
        -- TODO: request new ticket
    -- if  cleared
    IF standard.enum_value_id('cod', 'state', 'Cleared') = NEW.state_id THEN
        -- if just set to cleared
        IF NEW.state_id IS DISTINCT FROM OLD.state_id THEN
            -- TODO: set message to RT (push to children)
            -- TODO: cancel H&M active notifications
        END IF;
        -- If no escalations are unresolved prompt operator to resolve ticket
        IF NOT cod.has_open_escalation(NEW.id) THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Resolve'));
        END IF;
        -- exit
        RETURN NULL;
    END IF;

    -- if support model calls for helptext and no unsatisfied helptext action
    IF NOT cod.has_helptext_action(NEW.id) THEN
        IF (SELECT help_text FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
            -- create action to prompt for acting on helptext
            INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'));
            -- cod.action trigger should do something
        ELSE
            INSERT INTO cod.action (item.id, action_type_id, completed_at, completed_by, skipped, sucessful) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'), now(), 'ssg-cod', true, false);
        END IF;
    END IF;
    -- if not helptexting or requesting oncall group or have an escalation, escalate
    IF NOT EXISTS (SELECT NULL FROM cod.action AS a JOIN cod.action_type AS t ON (a.action_type_id=t.id) 
            WHERE a.item_id = NEW.id AND (t.name = 'HelpText' OR t.name = 'SetOncallGroup') AND completed_at IS NULL) AND
       NOT EXISTS (SELECT NULL FROM cod.escalation WHERE item_id = NEW.id)
    THEN
        SELECT * INTO _row FROM cod.event WHERE item_id = NEW.id ORDER BY id DESC LIMIT 1;
        _oncall := COALESCE(_row.contact, _row.oncall_primary, _row.oncall_alternate);
        -- if no valid oncall group 
        IF _oncall IS NULL THEN
            -- create action to prompt to correct oncall group
            INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'SetOncallGroup'));
        ELSE
            -- create escalation (see escalation_workflow)
            INSERT INTO cod.escalation (item_id, oncall_group) VALUES (NEW.id, _oncall);
        END IF;
    END IF;
    -- if not cleared and esclalations resolved -- do something
    RETURN NULL;
--EXCEPTION
--    WHEN OTHERS THEN RETURN NULL;
END;
$_$;

COMMENT ON FUNCTION cod.incident_workflow() IS '';

CREATE TRIGGER t_90_incident_workflow
    AFTER INSERT OR UPDATE ON cod.item
    FOR EACH ROW
    WHEN (NEW.state_id <> 1 AND NEW.itil_type_id = 1)
    EXECUTE PROCEDURE cod.incident_workflow();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.escalation_build() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  trigger to run on Building escalations
    Affects:      
    Arguments:    
    Returns:      
*/
DECLARE
    _sep        varchar := E'------------------------------------------\n';
    _item       cod.item%ROWTYPE;
    _event      cod.event%ROWTYPE;
    _payload    varchar;
    _content    xml;
    _tags       varchar[];
BEGIN
    -- get queue from H&M
    IF NEW.queue IS NULL THEN
        NEW.queue := hm_v1.get_oncall_queue(NEW.oncall_group);
    END IF;
    IF NEW.rt_ticket IS NULL THEN
        -- RAISE NOTICE 'CREATE ESCALATION TICKET';
        -- create ticket
        SELECT * INTO _item FROM cod.item WHERE id = NEW.item_id;
        SELECT * INTO _event FROM cod.event WHERE item_id = NEW.item_id ORDER BY id ASC LIMIT 1;
       _content = _event.content::xml;

        _msg := xpath.get_varchar('/Event/Alert/Msg', _content);
        _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', _content);

        _tags := array2.ucat(_tags, 'COD-DEV'::varchar);

        _message := '';
        IF _row.host IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.host);
            _message := _message || 'Hostname: ' || _row.host || E'\n';
        END IF;
        IF _row.component IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.component);
            _message := _message || 'Component: ' || _row.component || E'\n';
        END IF;
        IF _msg IS NOT NULL THEN
            _message := _message || _sep || _msg || E'\n';
        END IF;
        IF _lmsg IS NOT NULL OR _lmsg <> _msg THEN
            _message := _message || _sep || _lmsg || E'\n';
        END IF;

        _payload := 'Subject: ' || _item.subject || E'\n' ||
                    'Queue: ' || _NEW.queue || E'\n' ||
                    'Severity: ' || _item.severity::varchar ||  E'\n' ||
                    'Tags: ' || array_to_string(_tags, ' ') || E'\n' ||
                    -- 'Starts: ' || _row.start_at::varchar || E'\n' ||
                    'Content: ' || _message || E'\n' ||
                    E'ENDOFCONTENT\n';
        
        NEW.rt_ticket := rt.create_ticket(_payload);
    END IF;
    RETURN NEW;
--EXCEPTION
--    WHEN OTHERS THEN RETURN NULL;
END;
$_$;

COMMENT ON FUNCTION cod.escalation_build() IS '';

CREATE TRIGGER t_40_escalation_build
    BEFORE INSERT OR UPDATE ON cod.escalation
    FOR EACH ROW
    WHEN (NEW.esc_state_id = 1)
    EXECUTE PROCEDURE cod.escalation_build();


/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.escalation_workflow() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  trigger to run on !Building escalations
    Affects:      
    Arguments:    
    Returns:      
*/
DECLARE
    _payload        varchar;
BEGIN
    -- active escalation & owner = nobody & no H&M?
    IF NEW.hm_issue IS NULL AND NEW.owner = 'nobody' AND 
       (SELECT sm.active_notification FROM cod.support_model AS sm JOIN cod.item AS i ON (i.support_model_id = sm.id) WHERE i.id = NEW.item_id) IS TRUE 
    THEN
        RAISE NOTICE 'PROMPT H&M to start notification';
        -- prompt H&M
    END IF;
    IF OLD.owner <> NEW.owner AND NEW.owner <> 'nobody' THEN
        IF NEW.hm_issue IS NOT NULL THEN
            RAISE NOTICE 'Tell H&M to stop notification';
            -- flag H&M to stop escalation with owner
        ELSE
            RAISE NOTICE 'Tell RT the new owner';
        END IF;
    END IF;
    RETURN NULL;
--EXCEPTION
--    WHEN OTHERS THEN RETURN NULL;
END;
$_$;

COMMENT ON FUNCTION cod.escalation_workflow() IS '';

CREATE TRIGGER t_90_escalation_workflow
    AFTER INSERT OR UPDATE ON cod.escalation
    FOR EACH ROW
    WHEN (NEW.esc_state_id <> 1)
    EXECUTE PROCEDURE cod.escalation_workflow();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.update_item() RETURNS trigger
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
    UPDATE cod.item SET modified_at = now() WHERE id = NEW.item_id;
    RETURN NULL;
--EXCEPTION
--    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION () IS '';

CREATE TRIGGER t_91_update_item
    AFTER INSERT OR UPDATE ON cod.action
    FOR EACH ROW
    EXECUTE PROCEDURE cod.update_item();

CREATE TRIGGER t_91_update_item
    AFTER INSERT OR UPDATE ON cod.escalation
    FOR EACH ROW
    EXECUTE PROCEDURE cod.update_item();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.incident_state_check() RETURNS trigger
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
    If (cod.has_active_action(NEW.id)) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Act');
    ELSEIF (NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved')) THEN
        -- do nothing
    ELSEIF (cod.has_uncleared_event(New.id) IS FALSE) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Cleared');
    ELSEIF (cod.has_open_escalation(NEW.id)) THEN
        IF (cod.has_active_escalation(NEW.id)) THEN
            NEW.state_id = standard.enum_value_id('cod', 'state', 'Escalating');
        ELSE
            NEW.state_id = standard.enum_value_id('cod', 'state', 'L2-3');
        END IF;
    ELSE
        -- else set to processing (no open escalations/actions and not cleared means something needs to happen)
    END IF;
    RETURN NEW;
--EXCEPTION
--    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION () IS '';

CREATE TRIGGER t_20_incident_state_check
    BEFORE INSERT OR UPDATE ON cod.item
    FOR EACH ROW
    WHEN (NEW.state_id <> 1 AND NEW.itil_type_id = 1)
    EXECUTE PROCEDURE cod.incident_state_check();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.incident_stage_check() RETURNS trigger
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
    IF NEW.state_id = standard.enum_value_id('cod', 'stage', 'Cleared') THEN
        IF (cod.has_open_escalation(NEW.id)) THEN
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Resolution and Recovery');
        ELSE
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Closure');
        END IF;
    ELSEIF (cod.has_unowned_escalation(NEW.id)) THEN
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Functional Escalation');
    ELSEIF (cod.has_active_helptext(NEW.id) OR cod.has_open_escalation(NEW.id)) THEN
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Investigation and Diagnosis');
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Building') THEN
        IF NEW.rt_ticket IS NULL THEN
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Logging');
        ELSE
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Initial Diagnosis');
        END IF;
    ELSE 
        -- what to do?
    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.incident_stage_check() IS '';

CREATE TRIGGER t_25_incident_stage_check
    BEFORE INSERT OR UPDATE ON cod.item
    FOR EACH ROW
    WHEN (NEW.itil_type_id = 1)
    EXECUTE PROCEDURE cod.incident_stage_check();


/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_open_escalation(integer) RETURNS boolean
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
    SELECT EXISTS(
        SELECT NULL FROM cod.escalation WHERE item_id = $1 AND 
            esc_state_id <> standard.enum_value_id('cod', 'esc_state', 'Resolved')
    );
$_$;

COMMENT ON FUNCTION cod.has_open_escalation(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_unowned_escalation(integer) RETURNS boolean
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
    SELECT EXISTS(
        SELECT NULL FROM cod.escalation WHERE item_id = $1 AND 
            standard.enum_id_name_compare('cod', 'esc_state', esc_state_id, 'Owned', '<')
    );
$_$;

COMMENT ON FUNCTION cod.has_unowned_escalation(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_active_escalation(integer) RETURNS boolean
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
*/
    SELECT EXISTS(
        SELECT NULL FROM cod.escalation WHERE item_id = $1 AND 
            esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Active')
    );
$_$;

COMMENT ON FUNCTION cod.has_active_escalation(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_active_helptext(integer) RETURNS boolean
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
*/
    SELECT EXISTS(
        SELECT NULL FROM cod.action WHERE item_id = $1 AND completed_at IS NULL AND
            action_type_id = standard.enum_value_id('cod', 'state', 'HelpText')
    );
$_$;

COMMENT ON FUNCTION cod.has_active_helptext(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_helptext_action(integer) RETURNS boolean
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
*/
    SELECT EXISTS(
        SELECT NULL FROM cod.action WHERE item_id = $1 AND
            action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText')
    );
$_$;

COMMENT ON FUNCTION cod.has_helptext_action(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_active_action(integer) RETURNS boolean
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
*/
    SELECT EXISTS(
        SELECT NULL FROM cod.action WHERE item_id = $1 AND completed_at IS NULL
    );
$_$;

COMMENT ON FUNCTION cod.has_active_action(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_uncleared_event(integer) RETURNS boolean
    LANGUAGE sql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     
    Description:  
    Affects:      
    Arguments:    
    Returns:      
*/
    SELECT EXISTS(
        SELECT NULL FROM cod.event WHERE item_id = $1 AND end_at IS NULL
    );
$_$;

COMMENT ON FUNCTION cod.has_uncleared_event(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION standard.enum_id_name_compare_sort(varchar, varchar, integer, varchar, varchar) RETURNS boolean
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
    v_schema        ALIAS FOR $1;
    v_table         ALIAS FOR $2;
    v_id            ALIAS FOR $3;
    v_name          ALIAS FOR $4;
    v_comp          ALIAS FOR $5;
    _table          varchar := quote_ident(v_schema) || '.' || quote_ident(v_table);
    _output         boolean;
BEGIN
    IF v_comp NOT IN ('=', '<>', '!=', '<', '<=', '>=', '>') THEN
        RAISE EXCEPTION 'Invalid Comparison, "%"', v_comp;
    END IF;
    EXECUTE 'SELECT a.sort ' || v_comp || ' b.sort FROM ' || _table || ' AS a, ' || _table || ' AS b WHERE a.id = ' || quote_literal(v_id) || ' AND b.name = ' || quote_literal(v_name) INTO _output;
    RETURN _output;
END;
$_$;

COMMENT ON FUNCTION standard.enum_id_name_compare_sort(varchar, varchar, integer, varchar, varchar) IS '';
