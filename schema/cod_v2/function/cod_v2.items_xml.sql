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
-- Name: items_xml(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION items_xml() RETURNS xml
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod_v2.items_xml()
    Description:  List of cod items
    Affects:      nothing
    Arguments:    none
    Returns:      XML list of items
*/
DECLARE
    _lastmod    timestamptz;
    _cache      xml;
BEGIN
    _lastmod := (SELECT max(modified_at) FROM cod.item);
    _cache   := (cod.dbcache_get('ITEMS', _lastmod))::xml;
    IF _cache IS NULL THEN
        _cache := xmlelement(name "Items",
            (SELECT xmlagg(cod_v2.item_xml(id)) FROM (
                SELECT i.id FROM cod.item i JOIN cod.state s ON (i.state_id=s.id) 
                    WHERE s.sort < 90 OR i.closed_at > now() - '1 hour'::interval ORDER BY s.sort ASC, i.rt_ticket DESC
            ) AS foo),
            xmlelement(name "ModifiedAt", _lastmod)
        );
        PERFORM cod.dbcache_update('ITEMS', _cache::varchar, _lastmod);
    END IF;
    RETURN _cache;
END;
$$;


ALTER FUNCTION cod_v2.items_xml() OWNER TO postgres;

--
-- Name: FUNCTION items_xml(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION items_xml() IS 'DR: List of cod items. Uses cod.dbacache (2012-02-26)';


--
-- PostgreSQL database dump complete
--

