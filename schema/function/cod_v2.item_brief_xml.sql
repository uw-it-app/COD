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
-- Name: item_brief_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_brief_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.item_brief_xml(integer)
    Description:  Retrive XML representation of an item
    Affects:      nothing
    Arguments:    integer: id of the item
    Returns:      xml: XML representation of the item
*/
    SELECT xmlelement(name "Item",
        xmlelement(name "Id", item.id),
        xmlelement(name "Subject", item.subject),
        xmlelement(name "RTTicket", item.rt_ticket),
        xmlelement(name "HMIssue", item.hm_issue),
        xmlelement(name "State", state.name),
        xmlelement(name "ITILType", itil.name),
        xmlelement(name "SupportModel", model.name),
        xmlelement(name "Severity", item.severity),
        xmlelement(name "Stage", stage.name),
        xmlelement(name "ReferenceNumber", item.reference_no),
        xmlelement(name "Times",
            xmlelement(name "Started", date_trunc('second', item.started_at)::timestamp::varchar),
            xmlelement(name "Ended", date_trunc('second', item.ended_at)::timestamp::varchar),
            xmlelement(name "Escalated", date_trunc('second', item.escalated_at)::timestamp::varchar),
            xmlelement(name "Resolved", date_trunc('second', item.resolved_at)::timestamp::varchar),
            xmlelement(name "Nag", date_trunc('second', item.nag_next)::timestamp::varchar),
            xmlelement(name "Closed", date_trunc('second', item.closed_at)::timestamp::varchar)
        ),
        xmlelement(name "Escalations",
            (SELECT xmlagg(cod_v2.escalation_xml(x.id)) FROM
               (SELECT id FROM cod.escalation WHERE item_id = $1 ORDER BY id DESC) AS x
            )
        ),
        xmlelement(name "Created",
            xmlelement(name "At", date_trunc('second', item.created_at)::timestamp::varchar),
            xmlelement(name "By", item.created_by)
        ),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', item.modified_at)::timestamp::varchar),
            xmlelement(name "By", item.modified_by)
        )
    ) FROM cod.item AS item
      JOIN cod.state AS state ON (item.state_id = state.id)
      JOIN cod.itil_type AS itil ON (item.itil_type_id = itil.id)
      JOIN cod.support_model AS model ON (item.support_model_id = model.id)
      LEFT JOIN cod.stage AS stage ON (item.stage_id = stage.id)
     WHERE item.id = $1;
$_$;


ALTER FUNCTION cod_v2.item_brief_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION item_brief_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION item_brief_xml(integer) IS 'DR: Retrive Brief XML representation of an item (2011-10-17)';


--
-- PostgreSQL database dump complete
--

