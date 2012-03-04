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
-- Name: comment_pre(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION comment_pre() RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
/*  Function:     cod_v2.comment_pre()
    Description:  Content to insert before comments
    Affects:      nothing
    Arguments:    none
    Returns:      varchar
*/
    SELECT E'COD\n'
        || E'-----------------------------------------\n';
$$;


ALTER FUNCTION cod_v2.comment_pre() OWNER TO postgres;

--
-- Name: FUNCTION comment_pre(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION comment_pre() IS 'DR: Content to insert before comments (2012-02-17)';


--
-- PostgreSQL database dump complete
--

