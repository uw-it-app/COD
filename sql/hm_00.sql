-- ONCALL
-- add repeat to oncall -- # of times to repeat attempts to contact oncall group
ALTER TABLE hm_oncall ADD COLUMN loop_count integer NOT NULL DEFAULT 2 CHECK(loop_count > 0);
ALTER TABLE hm_oncall ADD COLUMN active_members integer NOT NULL DEFAULT 0 CHECK(active_members >= 0);
ALTER TABLE hm_issue ALTER COLUMN active SET DEFAULT TRUE;
ALTER TABLE hm_issue ALTER COLUMN owner SET DEFAULT 'nobody';

-- ISSUE
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

	-- rotate 'Each Issue' OCG

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

-- add trigger on hm_issue to forbid insert with the same ticket/oncall group as an active issue
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


-- new version of hm.oncall_methods_xml that grabs active and loops from oncall group definition.
/**********************************************************************************************/

CREATE OR REPLACE FUNCTION hm_v1.oncall_methods_xml(integer) RETURNS xml
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     hm_v1.oncall_methods_xml(integer)
    Description:  Generate XML list of contact methods for an Issue
    Affects:      nothing
    Arguments:    integer: Oncall group create the list from
    Returns:      xml
*/
DECLARE
    _id         ALIAS FOR $1;
    _ocg		public.hm_oncall%ROWTYPE;
    _users      integer[];
    _count      integer;
    _cm         hm_contact_method%ROWTYPE;
    _xml        xml;
    _xml_out    xml;
BEGIN
	_ocg := SELECT * INTO _row FROM hm_oncall WHERE id = _id;
    -- Get Array of Current Users
    IF _ocg.active_members > 0 THEN
        _users := ARRAY(
            SELECT user_id FROM (
                SELECT hm_v1.user_or_substitute(user_id) AS user_id FROM hm_member 
                WHERE oncall_id = _id ORDER BY sort ASC
            ) AS subed WHERE hm_v1.user_available(user_id) IS TRUE Limit _ocg.active_members
        );
    ELSE
        _users := ARRAY(SELECT hm_v1.user_or_substitute(user_id) AS user_id FROM hm_member WHERE oncall_id = _id ORDER BY sort ASC);
    END IF;
    -- Append Manager if Appropriate
    IF (_ocg.append_manager) THEN
        _users := array2.cat(
            _users, 
            hm_v1.user_or_substitute((SELECT hm_queue.manager FROM hm_queue JOIN hm_oncall ON (hm_queue.id=hm_oncall.queue_id) WHERE hm_oncall.id=_id))
        );
    END IF;

    _count := array_length(_users, 1);
    IF _count IS NULL THEN
        RETURN '<Contacts/>'::xml;
    END IF;
    -- Loop through list of Users 
    FOR i in 1.._count LOOP
        --  append contact method xml
        FOR _cm IN SELECT id FROM hm_contact_method WHERE user_id=_users[i] AND sort > 0 ORDER BY sort ASC LOOP
            _xml := xmlconcat(_xml, xmlelement(name "Contact", xmlattributes(_cm.id AS "method", 'false' AS "used")));
        END LOOP;
    END LOOP;
    -- loop through the list x times
    FOR i in 1.._ocg.loop_count LOOP
    	_xml_out := xmlconcat(_xml_out, _xml);
    END LOOP;
    -- RETURN xml
    RETURN xmlelement(name "Contacts", _xml_out);
END;
$_$;

COMMENT ON FUNCTION hm_v1.oncall_methods_xml(integer) IS 'DR: Generate XML list of contact methods for an Issue (2012-02-07)';



--