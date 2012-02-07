-- ONCALL
ALTER TABLE hm_oncall ADD COLUMN loop_count integer NOT NULL DEFAULT 2 CHECK(loop_count > 0);
ALTER TABLE hm_oncall ADD COLUMN active_members integer NOT NULL DEFAULT 0 CHECK(active_members >= 0);

-- ISSUE
ALTER TABLE hm_issue ALTER COLUMN active SET DEFAULT TRUE;
ALTER TABLE hm_issue ALTER COLUMN owner SET DEFAULT 'nobody';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION hm.forbid_duplicate_of_active() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     hm.forbid_duplicate_of_active()
    Description:  Prevent the creation of a issue that duplicates a currently active issue
    Affects:      Current row to insert
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
	IF EXISTS(SELECT NULL FROM hm_issue WHERE active IS TRUE AND oncall_id = NEW.oncall_id AND ticket is NOT DISTINCT FROM NEW.ticket) THEN
		RAISE EXCEPTION 'DuplicateIssue: An issue for that ticket/oncall group is already active';
	END IF;
END;
$_$;

COMMENT ON FUNCTION hm.forbid_duplicate_of_active() IS 'DR: Prevent the creation of a issue that duplicates a currently active issue (2012-02-07)';

CREATE TRIGGER t_10_prevent_duplicate
    BEFORE INSERT ON public.hm_issue
    FOR EACH ROW
    EXECUTE PROCEDURE hm.forbid_duplicate_of_active();

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION hm.issue_check() RETURNS trigger
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     hm.issue_check()
    Description:  Ensure new issues are properly created
    Affects:      Inserted Issue
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
	IF NEW.active = false THEN
		RAISE EXCEPTION 'Inactive issues may not be created';
	END IF;

	IF NEW.subject IS NULL OR NEW.message = '' THEN
		RAISE EXCEPTION 'Issues must have a subject';
	END IF;

	IF NEW.message IS NULL OR NEW.message = '' THEN
		NEW.message := NEW.subject;
	END IF;

	IF NEW.short_message IS NULL OR NEW.short_message = '' THEN
		IF NEW.subject IS DISTINCT FROM NEW.message THEN
			NEW.short_message := NEW.subject . '/' . NEW.message;
		ELSE
			NEW.short_message := NEW.subject;
		END IF;
	END IF;

	IF NEW.ticket IS NOT NULL THEN
		NEW.message := 'https://rt.cac.washington.edu/Ticket/Display.html?id=' || NEW.ticket || E'\n\n' || NEW.message;
		NEW.short_message := 'UW-IT #' || NEW.ticket || ' ' || NEW.message;
	ELSE
		NEW.message := 'https://shades.cac.washington.edu/issue/' || NEW.id || E'\n\n' || NEW.message;
		NEW.short_message := 'HM #' || NEW.id || ' ' || NEW.short_message;
	END IF;

	IF NEW.contact_xml IS NULL THEN
		new.contact_xml := hm.oncall_methods_xml(NEW.oncall_id);
	END IF;

	NEW.short_message := substr(NEW.short_message, 1, 113);
	RETURN NEW;
--EXCEPTION
--    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION hm.issue_check() IS 'DR: Ensure new issues are properly created (2012-02-06)';

CREATE TRIGGER t_20_check
    BEFORE INSERT ON TABLE
    FOR EACH ROW
    EXECUTE PROCEDURE hm.issue_check();
