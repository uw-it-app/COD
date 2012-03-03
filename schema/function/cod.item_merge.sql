--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod, pg_catalog;

--
-- Name: item_merge(integer, integer, boolean); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_merge(integer, integer, boolean) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.item_merge(integer, integer, boolean)
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


ALTER FUNCTION cod.item_merge(integer, integer, boolean) OWNER TO postgres;

--
-- Name: FUNCTION item_merge(integer, integer, boolean); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION item_merge(integer, integer, boolean) IS 'DR: Merge item id 2 into id 1 (2012-03-01)';


--
-- PostgreSQL database dump complete
--

