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
-- Name: escalation_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.escalation_xml(integer)
    Description:  XML Representation of an Escalation
    Affects:      nothing
    Arguments:    integer: escalation id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Escalation", 
        xmlelement(name "Id", e.id),
        xmlelement(name "RTTicket", e.rt_ticket),
        xmlelement(name "HMIssue", e.hm_issue),
        xmlelement(name "State", state.name),
        xmlelement(name "PageState", page.name),
        xmlelement(name "OncallGroup", e.oncall_group),
        xmlelement(name "Queue", e.queue),
        xmlelement(name "Owner", e.owner),
        xmlelement(name "Times", 
            xmlelement(name "Escalated", date_trunc('second', e.escalated_at)::timestamp::varchar),
            xmlelement(name "Owned", date_trunc('second', e.owned_at)::timestamp::varchar),
            xmlelement(name "Resolved", date_trunc('second', e.resolved_at)::timestamp::varchar)
        ),
        xmlelement(name "Content", e.content),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', e.modified_at)::timestamp::varchar),
            xmlelement(name "By", e.modified_by)
        )
    ) FROM cod.escalation AS e
      JOIN cod.esc_state AS state ON (e.esc_state_id = state.id)
      JOIN cod.page_state AS page ON (e.page_state_id = page.id)
     WHERE e.id = $1;
$_$;


ALTER FUNCTION cod_v2.escalation_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION escalation_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION escalation_xml(integer) IS 'DR: XML Representation of an Escalation (2012-02-26)';


--
-- PostgreSQL database dump complete
--

