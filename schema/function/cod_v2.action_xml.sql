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
-- Name: action_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION action_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.action_xml(integer)
    Description:  XML Representation of an action
    Affects:      nothing
    Arguments:    integer: action id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Action",
        xmlelement(name "Id", action.id),
        xmlelement(name "Type", type.name),
        xmlelement(name "Successful", action.successful),
        xmlelement(name "Data", action.content::xml),
        xmlelement(name "Completed",
            xmlelement(name "At", date_trunc('second', action.completed_at)::timestamp::varchar),
            xmlelement(name "By", action.completed_by)
        ),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', action.modified_at)::timestamp::varchar),
            xmlelement(name "By", action.modified_by)
        )
    ) FROM cod.action AS action
      JOIN cod.action_type AS type ON (action.action_type_id = type.id)
     WHERE action.id = $1;
$_$;


ALTER FUNCTION cod_v2.action_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION action_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION action_xml(integer) IS 'DR: XML Representation of an action (2012-02-26)';


--
-- PostgreSQL database dump complete
--

