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
-- Name: nag_check(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION nag_check() RETURNS xml
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod_v2.nag_check()
    Description:  Update items where nag may be needed
    Affects:      cod.item where nag may be needed
    Arguments:    none
    Returns:      xml
*/
DECLARE
    _count      integer;
BEGIN
    UPDATE cod.item AS item SET modified_at = now() WHERE nag_next < now() AND NOT EXISTS(SELECT NULL FROM cod.action WHERE action_type_id = standard.enum_value_id('cod', 'action_type', 'Nag') AND completed_at IS NULL AND item_id = item.id);
    GET DIAGNOSTICS _count = ROW_COUNT;
    RETURN ('<Updated>' || _count::varchar || '</Updated>')::xml;
EXCEPTION
    WHEN OTHERS THEN null;
END;
$$;


ALTER FUNCTION cod_v2.nag_check() OWNER TO postgres;

--
-- Name: FUNCTION nag_check(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION nag_check() IS 'DR: Update items where nag may be needed (2012-02-23)';


--
-- PostgreSQL database dump complete
--

