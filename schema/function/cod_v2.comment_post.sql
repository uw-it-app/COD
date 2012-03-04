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
-- Name: comment_post(); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION comment_post() RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
/*  Function:     cod_v2.comment_post()
    Description:  Content to insert after comments
    Affects:      nothing
    Arguments:    none
    Returns:      varchar
*/
    SELECT E'\n-----------------------------------------\n'
        || E'By ' || standard.get_uwnetid() || E' via COD\n';
$$;


ALTER FUNCTION cod_v2.comment_post() OWNER TO postgres;

--
-- Name: FUNCTION comment_post(); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION comment_post() IS 'DR: Content to insert after comments (2012-02-17)';


--
-- PostgreSQL database dump complete
--

