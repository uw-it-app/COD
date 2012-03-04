BEGIN;


DROP TRIGGER IF EXISTS t_70_update_rt ON cod.item;

CREATE TRIGGER t_70_update_rt BEFORE UPDATE ON cod.item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE AND new.rt_ticket IS NOT NULL)) EXECUTE PROCEDURE cod.item_rt_update();

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
    Affects:      Both items and records associated with item 2
    Arguments:    integer: Id of Item to merge into
                  integer: ID of Item to merge
                  boolean: Lock and unlock root item
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
--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_v2, pg_catalog;

--
-- Name: rt_process_escalation(integer, boolean, xml); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION rt_process_escalation(integer, boolean, xml) RETURNS xml
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod_v2.rt_process_escalation(integer, boolean, xml)
    Description:  Process rt update on an escalation
    Affects:      
    Arguments:    integer: Item Id
                  boolean: If true do not wait a minute after created time to create
                  xml: Escalation XML Representation
    Returns:      xml
*/
DECLARE
    v_item_id       ALIAS FOR $1;
    v_new           ALIAS FOR $2;
    v_xml           ALIAS FOR $3;
    _aliases        integer[];
    _status         varchar;
    _escalation     cod.escalation%ROWTYPE;
BEGIN
    _aliases := xpath.get_varchar_array('/Escalation/AliasIds/AliasId', v_xml)::integer[];
    RAISE NOTICE 'ESCALATION, %', v_xml::varchar;
    SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', v_xml);
    IF _escalation.id IS NULL THEN
        RAISE NOTICE 'ESCALATION does not exist';
        --Check to see if under an alias
        SELECT * INTO _escalation FROM cod.escalation WHERE ARRAY[rt_ticket]::integer[] <@ _aliases LIMIT 1;
        IF _escalation.id IS NOT NULL THEN
            UPDATE cod.escalation SET rt_ticket = xpath.get_integer('/Escalation/Id', v_xml) WHERE id = _escalation.id;
        ELSEIF xpath.get_varchar('/Escalation/Type', v_xml) <> 'Incident' THEN
            RETURN '<Skipped/>'::xml;
        ELSEIF v_new OR xpath.get_timestamptz('/Escalation/Created', v_xml) < now() - '1 minute'::interval THEN
            RAISE NOTICE 'ESCALATION creating';
            INSERT INTO cod.escalation (item_id, rt_ticket, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at) VALUES (
                v_item_id,
                xpath.get_integer('/Escalation/Id', v_xml),
                standard.enum_value_id('cod', 'esc_state', 'Passive'),
                standard.enum_value_id('cod', 'page_state', 'Passive'),
                'n/a',
                xpath.get_varchar('/Escalation/Queue', v_xml),
                xpath.get_varchar('/Escalation/Owner', v_xml),
                xpath.get_timestamptz('/Escalation/Created', v_xml)
            );
            SELECT * INTO _escalation FROM cod.escalation WHERE rt_ticket = xpath.get_integer('/Escalation/Id', v_xml);
            IF NOT FOUND THEN
                RAISE NOTICE 'ESCALATION creation failed';
                RETURN '<FailedToCreate/>'::xml;
            END IF;
        ELSE
            RAISE NOTICE 'ESCALATION skipping creation, %, %', xpath.get_timestamptz('/Escalation/Created', _incident), xpath.get_timestamptz('/Escalation/Created', _incident) < now() - '1 minute'::interval;
            RETURN '<Skipped/>'::xml;
        END IF;
    END IF;
    -- set severity from RT???
    _status := xpath.get_varchar('/Escalation/Status', v_xml);
    IF ARRAY['new', 'open', 'stalled']::varchar[] @> ARRAY[_status] THEN
        _escalation.resolved_at := NULL;
    ELSE
        IF _escalation.resolved_at IS NULL THEN
            _escalation.resolved_at  := now();
        END IF;
        IF _status = 'rejected' THEN
            _escalation.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Rejected');
        ELSE
            _escalation.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Resolved');
        END IF;
    END IF;
    UPDATE cod.escalation SET 
        resolved_at = _escalation.resolved_at,
        queue = xpath.get_varchar('/Escalation/Queue', v_xml),
        owner = xpath.get_varchar('/Escalation/Owner', v_xml),
        esc_state_id = _escalation.esc_state_id
        WHERE id = _escalation.id;
    --foreach aliasid, if it exists then set status to merged
    UPDATE cod.escalation 
        SET esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Merged'),
            resolved_at = now()
        WHERE ARRAY[rt_ticket]::integer[] <@ _aliases;
    RETURN '<Processed/>'::xml;
END;
$_$;


ALTER FUNCTION cod_v2.rt_process_escalation(integer, boolean, xml) OWNER TO postgres;

--
-- Name: FUNCTION rt_process_escalation(integer, boolean, xml); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION rt_process_escalation(integer, boolean, xml) IS 'DR: Process rt update on an escalation (2012-02-29)';


--
-- PostgreSQL database dump complete
--




COMMIT;
