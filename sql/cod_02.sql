BEGIN;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.event_check() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.event_check()
    Description:  Ensure event is valid
    Affects:      cod.event row the trigger executes on
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    IF NOT hm_v1.valid_oncall(NEW.contact) THEN
        NEW.contact := NULL;
    END IF;
    IF NOT hm_v1.valid_oncall(NEW.oncall_primary) THEN
        NEW.oncall_primary := NULL;
    END IF;
    IF NOT hm_v1.valid_oncall(NEW.oncall_alternate) THEN
        NEW.oncall_alternate := NULL;
    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.event_check() IS 'DR: Ensure event is valid (2012-02-16)';

CREATE TRIGGER t_20_check
    BEFORE INSERT OR UPDATE ON cod.event
    FOR EACH ROW
    EXECUTE PROCEDURE cod.event_check();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod.incident_nag_check() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod.incident_nag_check()
    Description:  Ensure the nag_next time is properly set or unset
    Affects:      Active row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    IF (SELECT nag FROM cod.support_model WHERE id = NEW.support_model_id) AND
        EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id AND esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Owned'))
    THEN
        IF NEW.nag_next IS NULL THEN
            NEW.nag_next := now() + NEW.nag_interval::interval;
        END IF;
    ELSE
        NEW.nag_next := NULL;
    END IF;
    RETURN NEW;
END;
$_$;

COMMENT ON FUNCTION cod.incident_nag_check() IS 'DR: Ensure the nag_next time is properly set or unset (2012-02-22)';

CREATE TRIGGER t_28_nag_check
    BEFORE INSERT OR UPDATE ON cod.item
    FOR EACH ROW
    WHEN (NEW.workflow_lock IS FALSE)
    EXECUTE PROCEDURE cod.incident_nag_check();


COMMIT;