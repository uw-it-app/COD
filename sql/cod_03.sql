BEGIN;

INSERT INTO cod.stage (sort, name, description) VALUES (0, '', '');

INSERT INTO cod.state (sort, name, description) VALUES (100, 'Merged', 'Merged into another Item');

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.lock_merged() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.lock_merged()
    Description:  Ensure that merged items are workflow_locked
    Affects:      
    Arguments:    
    Returns:      trigger
*/
DECLARE
BEGIN
    NEW.workflow_lock := TRUE;
    IF NEW.closed_at IS NULL THEN
        NEW.closed_at := now()
    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.lock_merged() IS 'DR: Ensure that merged items are workflow_locked (2012-03-01)';

CREATE TRIGGER t_10_lock_merged
    BEFORE INSERT OR UPDATE ON cod.item
    FOR EACH ROW
    WHEN (state_id = 9) -- 'Merged'
    EXECUTE PROCEDURE cod.lock_merged;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.item_merge(integer, integer, boolean) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.item_merge(integer, integer)
    Description:  Merge item id 2 into id 1
    Affects:      
    Arguments:    
    Returns:      boolean
*/
DECLARE
    v_root      ALIAS FOR $1;
    v_branch    ALIAS FOR $2;
    v_lock      ALIAS FOR $3;
    _mergeid    integer;
BEGIN
    IF v_lock THEN
        UPDATE cod.item SET workflow_lock = TRUE WHERE id = v_root;
    END IF;
    _mergeid := standard.enum_value_id('cod', 'state', 'Merged');
    UPDATE cod.item SET state_id = _mergeid WHERE id = v_branch AND state_id <> _mergeid;
    UPDATE cod.event SET item_id = v_root WHERE item_id = v_branch;
    UPDATE cod.escalation SET item_id = v_root WHERE item_id = v_branch;
    UPDATE cod.action SET item_id = v_root WHERE item_id = v_branch;
    IF v_lock THEN
        UPDATE cod.item SET workflow_lock = FALSE WHERE id = v_root;
    END IF;
    RETURN TRUE;
END;
$_$;

COMMENT ON FUNCTION cod.item_merge(integer, integer) IS 'DR: Merge item id 2 into id 1 (2012-03-01)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.item_rt_update() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.item_rt_update()
    Description:  Update rt with item metadata
    Affects:      
    Arguments:    
    Returns:      trigger
*/
DECLARE
    _payload    varchar  := '';
    _comment    varchar  := '';
    _string     varchar;
BEGIN
    IF OLD.itil_type_id IS DISTINCT FROM NEW.itil_type_id THEN
        _string  := standard.enum_id_value('cod', 'itil_type', NEW.itil_type_id);
        _comment := _comment
                 || 'ITIL Type: ' || _string || E'\n';
        IF _string ~ E'^\\(.*\\)$' THEN
            _string = '';
        END IF;
        _payload := _payload
                 || 'CF-TicketType: ' || _string || E'\n';
    END IF;
    IF OLD.support_model_id IS DISTINCT FROM NEW.support_model_id THEN
        _comment := _comment
                 || 'Support Model: ' || standard.enum_id_value('cod', 'support_model', NEW.support_model_id) || E'\n';
    END IF;
    IF OLD.severity IS DISTINCT FROM NEW.severity THEN
        _comment := _comment
                 || 'Severity: ' || NEW.severity::varchar || E'\n';
        _payload := _payload
                 || 'Severity: Sev' || NEW.severity::varchar || E'\n';
    END IF;
    IF OLD.reference_no IS DISTINCT FROM NEW.reference_no THEN
        IF NEW.reference_no IS NULL THEN
            _string := '';
        ELSE
            _string := NEW.reference_no;
        END IF;
        _comment := _comment
                 || 'Reference Number: ' || _string || E'\n';
    END IF;
    IF NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed') THEN
        _payload := _payload
                 || E'Status: resolved\n';

    END IF;
    IF OLD.subject IS DISTINCT FROM NEW.subject THEN
        _payload := _payload
                 || E'Subject: '|| New.subject || E'\n';

    END IF;
    IF _comment <> '' THEN
        _payload := E'UpdateType: comment\n'
                 || E'CONTENT: ' || _comment || cod_v2.comment_post()
                 || E'ENDOFCONTENT\n'
                 || _payload;
    END IF;
    IF _payload <> '' THEN
        PERFORM rt.update_ticket(NEW.rt_ticket, _payload);
    END IF;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION cod.item_rt_update() IS 'DR: Update rt with item metadata (2012-02-29)';

CREATE TRIGGER t_70_update_rt
    BEFORE UPDATE ON cod.item
    FOR EACH ROW
    WHEN (NEW.workflow_lock IS FALSE)
    EXECUTE PROCEDURE cod.item_rt_update();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.incident_workflow() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.incident_workflow()
    Description:  Workflow for incidents (and more for now)
    Affects:      Active Item record and associated elements
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _oncall     varchar;
    _row        record;
BEGIN
    IF NEW.rt_ticket IS NULL THEN
        NEW.rt_ticket := cod.create_incident_ticket_from_event((SELECT id FROM cod.event WHERE item_id = NEW.id ORDER BY id LIMIT 1));
        IF NEW.rt_ticket IS NOT NULL THEN
            UPDATE cod.item SET rt_ticket = NEW.rt_ticket WHERE id = NEW.id;
            RETURN NEW;
        END IF;
    END IF;

    --IF NEW.state_id = standard.enum_value_id('cod', 'state', 'Merged') THEN
    --    RETURN NEW;
    --END IF;

    IF NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN
        IF NEW.ended_at IS NOT NULL THEN
            -- cancel all active escalations
            PERFORM hm_v1.close_issue(hm_issue, owner, ' ') FROM cod.escalation WHERE item_id = NEW.id;
        END IF;
    END IF;

    IF NEW.nag_next IS NULL THEN
        UPDATE cod.action SET completed_at = now(), successful = FALSE 
            WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag') AND completed_at IS NULL;
        IF FOUND IS TRUE THEN
            RETURN NEW;
        END IF;
    ELSEIF NEW.nag_next <= now() AND 
        NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND completed_at IS NULL 
            AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag')) 
    THEN
        INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Nag'));
        RETURN NEW;
    END IF;

    IF NEW.state_id = standard.enum_value_id('cod', 'state', 'ACT') THEN
        IF EXISTS (SELECT NULL FROM cod.escalation WHERE standard.enum_id_value('cod', 'esc_state', esc_state_id) NOT IN ('Resolved', 'Rejected', 'Merged')) 
        THEN
            UPDATE cod.action SET completed_at = now(), successful = FALSE 
                WHERE item_id = NEW.id AND escalation_id IS NULL AND completed_at IS NULL 
                AND standard.enum_value_id('cod', 'action_type', 'Escalate');
            RETURN NEW;
        END IF;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed') THEN
        PERFORM cod.dash_delete_event(id) FROM cod.event WHERE item_id = NEW.id;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Resolved') THEN
        IF NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close') AND completed_at IS NULL)
        THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Close'));
        END IF;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Cleared') THEN
        -- If no escalations are unresolved prompt operator to resolve ticket
        IF ((NEW.escalated_at IS NOT NULL AND NEW.resolved_at IS NOT NULL) OR
            (NEW.escalated_at IS NULL AND NEW.resolved_at IS NULL)) AND
            NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'Close') AND completed_at IS NULL)
        THEN
            INSERT INTO cod.action (item_id, action_type_id) VALUES 
                (NEW.id, standard.enum_value_id('cod', 'action_type', 'Close'));
        END IF;
        RETURN NEW;
    ELSEIF NEW.state_id = standard.enum_value_id('cod', 'state', 'Processing') THEN
        IF NEW.ended_at IS NULL AND NEW.started_at IS NOT NULL AND NEW.resolved_at IS NOT NULL THEN
            INSERT INTO cod.action (item_id, action_type_id, content) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>All Escalations resolved but the alert is not cleared, clear the alert or Escalate</Note>');
        END IF;
    END IF;

    -- if have not escalated
    IF NEW.escalated_at IS NULL THEN
        -- if no helptext action
        IF NOT EXISTS(SELECT NULL FROM cod.action WHERE item_id = NEW.id AND action_type_id = standard.enum_value_id('cod', 'action_type', 'HelpText'))
        THEN
            IF (SELECT help_text FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
                -- create action to prompt for acting on helptext
                INSERT INTO cod.action (item_id, action_type_id) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'));
            ELSE
                INSERT INTO cod.action (item_id, action_type_id, completed_at, completed_by, skipped, successful) VALUES 
                    (NEW.id, standard.enum_value_id('cod', 'action_type', 'HelpText'), now(), 'ssg-cod', true, false);
            END IF;
        END IF;

        -- if no active (or successful) helptext and unclosed event (and not escalated)
        IF NEW.ended_at is NULL AND
            NOT EXISTS (SELECT NULL FROM cod.action AS a JOIN cod.action_type AS t ON (a.action_type_id=t.id) 
                WHERE a.item_id = NEW.id AND (t.name = 'HelpText' OR t.name = 'Escalate') AND (completed_at IS NULL OR successful IS TRUE))
        THEN
            SELECT * INTO _row FROM cod.event WHERE item_id = NEW.id ORDER BY id DESC LIMIT 1;
            _oncall := COALESCE(_row.contact, _row.oncall_primary, _row.oncall_alternate);
            IF _oncall IS NOT NULL THEN
                -- create escalation (see escalation_workflow)
                IF (SELECT active_notification FROM cod.support_model WHERE id = NEW.support_model_id) IS TRUE THEN
                    INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (NEW.id, _oncall, standard.enum_value_id('cod', 'page_state', 'Active'));
                ELSE
                    INSERT INTO cod.escalation (item_id, oncall_group, page_state_id) VALUES (NEW.id, _oncall, standard.enum_value_id('cod', 'page_state', 'Passive'));
                END IF;
            END IF;
            -- if no valid oncall group or failed to insert escalation
            IF _oncall IS NULL OR FOUND IS FALSE THEN
                -- create action to prompt to correct oncall group
                INSERT INTO cod.action (item_id, action_type_id, content) VALUES (NEW.id, standard.enum_value_id('cod', 'action_type', 'Escalate'), '<Note>No valid oncall group in the event, manual escalation required.</Note>');
            END IF;
        END IF;

    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.incident_workflow() IS 'DR: Workflow for incidents (and more for now) (2012-02-29)';

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
        IF standard.enum_id_value('cod', 'esc_state', NEW.esc_state_id) NOT IN ('Resolved', 'Rejected', 'Merged') THEN
            NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Resolved');
        END IF;
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
    ELSEIF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Closed') OR
        NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Cancelled') OR
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

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.escalation_workflow() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.escalation_workflow()
    Description:  Workflow trigger to run on !Building escalations
    Affects:      NEW escalation record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
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
END;
$_$;

COMMENT ON FUNCTION cod.escalation_workflow() IS 'DR: Workflow trigger to run on !Building escalations (2012-02-26)';


COMMIT;