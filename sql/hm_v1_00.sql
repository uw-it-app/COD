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
    -- Active = true
    -- comment
    -- origin


    -- createSquawk or done by cleanup in hm's Act???
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

-- have squawk update update modtime of issue
-- on issue update COD via trigger with:
    -- state
    -- owner
    -- current squawk (name, contact data)

-- failed notification
    -- prompt operator to contact duty manageer

-- current method so 
    -- if phone call create action to perform phone call
    -- else cancel phone call action

-- success -- set owner
