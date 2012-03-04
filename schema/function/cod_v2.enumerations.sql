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
-- Name: enumerations(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION enumerations() RETURNS xml
    LANGUAGE sql STABLE
    AS $$
/*  Function:     cod_v2.enumerations()
    Description:  Return lists of enumeration data for selects
    Affects:      nothing
    Arguments:    none
    Returns:      xml
*/
SELECT xmlelement(name "Enumerations"
    , rest_v1.enum_to_xml('cod', 'support_model', 'SupportModels', 'SupportModel', false)
    , rest_v1.enum_to_xml('cod', 'itil_type', 'ITILTypes', 'ITILType', false)
    , xmlelement(name "Severities"
        , xmlelement(name "Severity", 1)
        , xmlelement(name "Severity", 2)
        , xmlelement(name "Severity", 3)
        , xmlelement(name "Severity", 4)
        , xmlelement(name "Severity", 5)
    )
);
$$;


ALTER FUNCTION cod_v2.enumerations() OWNER TO postgres;

--
-- Name: FUNCTION enumerations(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION enumerations() IS 'DR: Return lists of enumeration data for selects (2012-02-25)';


--
-- PostgreSQL database dump complete
--

