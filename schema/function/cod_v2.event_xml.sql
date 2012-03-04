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
-- Name: event_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION event_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.event_xml(integer)
    Description:  XML Representation of an Event
    Affects:      nothing
    Arguments:    integer: event id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Event",
        xmlelement(name "Id", event.id),
        xmlelement(name "Host", event.host),
        xmlelement(name "Component", event.component),
        xmlelement(name "SupportModel", model.name),
        xmlelement(name "Severity", event.severity),
        xmlelement(name "Contact", event.contact),
        xmlelement(name "OncallPrimary", event.oncall_primary),
        xmlelement(name "OncallAlternate", event.oncall_alternate),
        xmlelement(name "HelpText", event.helptext),
        xmlelement(name "Subject", xpath.get_varchar('/Event/Subject', event.content::xml)),
        xmlelement(name "Message", xpath.get_varchar('/Event/Alert/Msg', event.content::xml)),
        xmlelement(name "LongMessage", xpath.get_varchar('/Event/Alert/LongMsg', event.content::xml)),
        xmlelement(name "Content", event.content::xml),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', event.modified_at)::timestamp::varchar),
            xmlelement(name "By", event.modified_by)
        ),
        xmlelement(name "Times",
            xmlelement(name "Start", date_trunc('second', event.start_at)::timestamp::varchar),
            xmlelement(name "End", date_trunc('second', event.end_at)::timestamp::varchar)
        )
    ) FROM cod.event AS event
      JOIN cod.support_model AS model ON (event.support_model_id = model.id)
     WHERE event.id = $1;
$_$;


ALTER FUNCTION cod_v2.event_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION event_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION event_xml(integer) IS 'DR: XML Representation of an Event (2012-02-26)';


--
-- PostgreSQL database dump complete
--

