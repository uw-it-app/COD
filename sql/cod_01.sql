BEGIN;

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
    IF NEW.rt_ticket IS NULL THEN
        RAISE NOTICE 'Try to create an ticket again or try to find';
        -- RETURN NEW;
    END IF;

    -- IF closed THEN
        -- clear actions
        -- unset nag
        -- RETURN NULL;
    -- END IF;

    -- if  cleared
    IF NEW.started_at IS NOT NULL AND NEW.ended_at IS NOT NULL THEN
        -- if just set to cleared
        IF NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN
            RAISE NOTICE 'Send message to RT';
            RAISE NOTICE 'Cancel H&M active notification';
        END IF;
        -- If no escalations are unresolved prompt operator to resolve ticket
        IF ((NEW.escalated_at IS NOT NULL AND NEW.resolved_at IS NOT NULL) OR
            (NEW.escalated_at IS NULL AND NEW.resolved_at IS NULL)) THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Resolve'));
        END IF;
        -- exit
        RETURN NULL;
    END IF;

    -- IF resolved (all esc resolved) THEN
        -- create action to clear or re-escalate to resolve
    -- END IF;

    -- if support model calls for helptext and no unsatisfied helptext action
    IF NOT cod.has_helptext_action(NEW.id) THEN
        IF (SELECT help_text FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
            -- create action to prompt for acting on helptext
            INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'));
            -- cod.action trigger should do something
        ELSE
            INSERT INTO cod.action (item_id, action_type_id, completed_at, completed_by, skipped, successful) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'), now(), 'ssg-cod', true, false);
        END IF;
    END IF;

    -- if not helptexting or requesting oncall group or have an escalation, escalate
    IF NOT EXISTS (SELECT NULL FROM cod.action AS a JOIN cod.action_type AS t ON (a.action_type_id=t.id) 
            WHERE a.item_id = NEW.id AND (t.name = 'HelpText' OR t.name = 'Escalate') AND completed_at IS NULL) AND
       NOT EXISTS (SELECT NULL FROM cod.escalation WHERE item_id = NEW.id)
    THEN
        SELECT * INTO _row FROM cod.event WHERE item_id = NEW.id ORDER BY id DESC LIMIT 1;
        _oncall := COALESCE(_row.contact, _row.oncall_primary, _row.oncall_alternate);
        -- if no valid oncall group 
        IF _oncall IS NULL THEN
            -- create action to prompt to correct oncall group
            INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'));
        ELSE
            -- create escalation (see escalation_workflow)
            INSERT INTO cod.escalation (item_id, oncall_group) VALUES (NEW.id, _oncall);
        END IF;
    END IF;
    RETURN NEW;
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
    _msg        varchar;
    _lmsg       varchar;
    _message    varchar;
    _tags       varchar[];
BEGIN
    -- get queue from H&M
    IF NEW.queue IS NULL THEN
        NEW.queue := hm_v1.get_oncall_queue(NEW.oncall_group);
    END IF;
    IF NEW.rt_ticket IS NULL THEN
        -- create ticket
        SELECT * INTO _item FROM cod.item WHERE id = NEW.item_id;
        SELECT * INTO _event FROM cod.event WHERE item_id = NEW.item_id ORDER BY id ASC LIMIT 1;
       _content = _event.content::xml;

        _msg  := xpath.get_varchar('/Event/Alert/Msg', _content);
        _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', _content);

        _tags := array2.ucat(_tags, 'COD-DEV'::varchar);

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
                    -- 'Starts: ' || _row.start_at::varchar || E'\n' ||
                    'Super: ' || _item.rt_ticket || E'\n' ||
                    'Content: ' || _message || E'\n' ||
                    E'ENDOFCONTENT\n';
        
        NEW.rt_ticket    := rt.create_ticket(_payload);
    END IF;
    IF (SELECT active_notification FROM cod.support_model WHERE id = _item.support_model_id) IS TRUE THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Active');
        NEW.page_state_id := standard.enum_value_id('cod', 'page_state', 'Active');
    ELSE
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Passive');
        NEW.page_state_id := standard.enum_value_id('cod', 'page_state', 'Passive');
    END IF;
    RETURN NEW;
--EXCEPTION
--    WHEN OTHERS THEN RETURN NULL;
END;
$_$;

COMMENT ON FUNCTION cod.escalation_build() IS '';

CREATE TRIGGER t_20_escalation_build
    BEFORE INSERT OR UPDATE ON cod.escalation
    FOR EACH ROW
    WHEN (NEW.esc_state_id = 1)
    EXECUTE PROCEDURE cod.escalation_build();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.escalation_check() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.escalation_check()
    Description:  Ensures escalation data is consistent
    Affects:      Single cod.escalation row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    
    IF NEW.resolved_at IS NOT NULL THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Resolved');
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
    ELSEIF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Cancelled') OR
        NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Passive')
    THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Passive');
    ELSE
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Active');
    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.escalation_check() IS 'DR: Ensures escalation data is consistent (2012-02-04)';

CREATE TRIGGER t_30_check
    BEFORE INSERT OR UPDATE ON cod.escalation
    FOR EACH ROW
    WHEN (NEW.esc_state_id <> 1)
    EXECUTE PROCEDURE cod.escalation_check();


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
    _payload        xml;
BEGIN
    IF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Resolved')) THEN
        IF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') OR
            NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating')
        THEN
            RAISE NOTICE 'Inform H&M of owner or cancel';
        END IF;
        PERFORM cod.remove_esc_actions(NEW.id);
        IF NEW.owner <> OLD.owner THEN
            PERFORM rt.update_ticket(NEW.rt_ticket, 'Owner: ' || NEW.owner || E'\n');
        END IF;
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Owned')) THEN
        IF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Act') OR
            NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Escalating')
        THEN
            RAISE NOTICE 'Inform H&M of owner or cancel';
        END IF;
        PERFORM cod.remove_esc_actions(NEW.id);
        IF NEW.owner <> OLD.owner THEN
            PERFORM rt.update_ticket(NEW.rt_ticket, 'Owner: ' || NEW.owner || E'\n');
        END IF;
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Passive')) THEN
        PERFORM cod.remove_esc_actions(NEW.id);
    ELSEIF (NEW.esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Failed')) THEN
        PERFORM cod.remove_esc_actions(NEW.id);
        RAISE NOTICE 'Create duty manager escalation if it does not exist';
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

CREATE OR REPLACE FUNCTION cod.remove_esc_actions(integer) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
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

COMMENT ON FUNCTION cod.remove_esc_actions(integer) IS 'DR: Remove any actions associated with the provided escalation id (2012-02-09)';


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

COMMENT ON FUNCTION cod.update_item() IS '';

CREATE TRIGGER t_91_update_item
    AFTER INSERT OR UPDATE ON cod.action
    FOR EACH ROW
    EXECUTE PROCEDURE cod.update_item();

CREATE TRIGGER t_91_update_item
    AFTER INSERT OR UPDATE ON cod.escalation
    FOR EACH ROW
    EXECUTE PROCEDURE cod.update_item();

CREATE TRIGGER t_91_update_item
    AFTER INSERT OR UPDATE ON cod.event
    FOR EACH ROW
    EXECUTE PROCEDURE cod.update_item();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.incident_time_check() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
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
-- EXCEPTION
--     WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION cod.incident_time_check() IS 'DR: Set time fields based on related objects (2012-02-02)';

CREATE TRIGGER t_15_update_times
    BEFORE INSERT OR UPDATE ON cod.item
    FOR EACH ROW
    EXECUTE PROCEDURE cod.incident_time_check();

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
    ELSEIF (NEW.closed_at IS NOT NULL) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved');
    ELSEIF (NEW.started_at IS NOT NULL AND NEW.ended_at IS NOT NULL) THEN
        NEW.state_id = standard.enum_value_id('cod', 'state', 'Cleared');
    ELSEIF (NEW.escalated_at IS NOT NULL AND NEW.resolved_at IS NULL) THEN
        IF (cod.has_active_escalation(NEW.id)) THEN
            NEW.state_id = standard.enum_value_id('cod', 'state', 'Escalating');
        ELSE
            NEW.state_id = standard.enum_value_id('cod', 'state', 'T2-3');
        END IF;
    ELSE
        -- else set to processing (no open escalations/actions and not cleared means something needs to happen)
    END IF;
    RETURN NEW;
--EXCEPTION
--    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION cod.incident_state_check() IS '';

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
        ELSEIF (cod.has_open_unowned_escalation(NEW.id)) THEN -- unowned escalation
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Functional Escalation');
        ELSE -- owned escalation
            NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Investigation and Diagnosis');
        END IF;
    ELSEIF NEW.ended_at IS NOT NULL THEN -- No escalation, closed event
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Closure');
    ELSEIF cod.has_active_helptext(NEW.id) THEN -- active helptext action
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Investigation and Diagnosis');
    ELSEIF NEW.rt_ticket IS NULL THEN
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Logging');
    ELSE
        NEW.stage_id = standard.enum_value_id('cod', 'stage', 'Initial Diagnosis');
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
        SELECT NULL FROM cod.escalation WHERE item_id = $1 AND resolved_at IS NULL 
    );
$_$;

COMMENT ON FUNCTION cod.has_open_escalation(integer) IS '';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.has_open_unowned_escalation(integer) RETURNS boolean
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
        SELECT NULL FROM cod.escalation WHERE item_id = $1 AND resolved_at IS NULL AND owned_at IS NULL
    );
$_$;

COMMENT ON FUNCTION cod.has_open_unowned_escalation(integer) IS '';

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

COMMIT;