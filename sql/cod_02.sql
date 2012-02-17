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



COMMIT;