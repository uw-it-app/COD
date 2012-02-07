/**********************************************************************************************/

CREATE OR REPLACE FUNCTION hm_v1.get_oncall_queue(varchar) RETURNS varchar
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    STRICT
    AS $_$
/*  Function:     hm_v1.get_oncall_queue(varchar)
    Description:  Retrieve the RT queue associated with an oncall group
    Affects:      nothing
    Arguments:    varchar: Oncall group name
    Returns:      varchar: RT Queue name
*/
    SELECT queue.rtq FROM public.hm_queue AS queue JOIN public.hm_oncall AS oncall ON (queue.id = oncall.queue_id) 
        WHERE oncall.name = $1;
$_$;

COMMENT ON FUNCTION hm_v1.get_oncall_queue(varchar) IS 'DR: Retrieve the RT queue associated with an oncall group (2011-11-16)';

-- create issue fn
    -- create issue
    -- create first squawk
    -- notify RT
/**********************************************************************************************/

CREATE OR REPLACE FUNCTION hm_v1.create_issue(xml) RETURNS integer
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     hm_v1.create_issue(xml)
    Description:  Function to create a notification
    Affects:      Inserts hm_issue and associated sqawk
    Arguments:    xml: XML document describing the new Issue
    Returns:      integer
*/
DECLARE
    v_xml       ALIAS FOR $1;
    _id         integer;
BEGIN
    -- oncall group
    -- ticket
    -- subject
    -- message
    -- shortmessage
    -- owner = 'nobody'
    -- switch -- ignore for now
    -- comment
    -- origin
    _id := nextval('hm_issue_seq'::text);
    INSERT INTO hm_issue (id, oncall_id, ticket, subject, message, short_message, origin) VALUES (
        _id,
        xpath.get_integer('/Issue/Ticket'),
    );


    -- createSquawk or done by cleanup in hm's Act???
    -- Rotage Each Issue OCG
    -- NOTIFY RT
    -- return id of issue
--EXCEPTION
--    WHEN OTHERS THEN null;
END;
$_$;

COMMENT ON FUNCTION hm_v1.create_issue(xml) IS 'DR: Function to create a notification (2012-02-06)';


--
-- update COD
--

-- on issue update COD via trigger with:
    -- state
    -- owner
    -- current squawk (name, contact data)

    -- just generate XML of Issue & current and push to cod_v2 function.


-- new version of hm.oncall_methods_xml that grabs active and loops from oncall group definition.
/**********************************************************************************************/

CREATE OR REPLACE FUNCTION hm_v1.oncall_methods_xml(integer) RETURNS xml
    LANGUAGE plpgsql
    STABLE
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
    _ocg        public.hm_oncall%ROWTYPE;
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


CREATE OR REPLACE FUNCTION hm_v1.oncall_methods_xml(integer, integer, boolean) RETURNS xml
    LANGUAGE SQL
    STABLE
    SECURITY INVOKER
    AS $_$
SELECT hm_v1.oncall_methods_xml($1);
$_$;
   
