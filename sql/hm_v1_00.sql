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
