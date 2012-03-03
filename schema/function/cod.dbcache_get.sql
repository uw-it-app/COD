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
-- Name: dbcache_get(character varying, timestamp with time zone); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dbcache_get(character varying, timestamp with time zone) RETURNS character varying
    LANGUAGE sql
    AS $_$
/*  Function:     cod.dbcache_get(varchar, timestamptz)
    Description:  Get dbcache record with the provided name and at or after the provided time
    Affects:      nothing
    Arguments:    varchar: name of record
                  timestamptz: time <= timekey of record
    Returns:      varchar
*/
    SELECT content FROM cod.dbcache WHERE name = $1 and timekey >= $2;
$_$;


ALTER FUNCTION cod.dbcache_get(character varying, timestamp with time zone) OWNER TO postgres;

--
-- Name: FUNCTION dbcache_get(character varying, timestamp with time zone); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dbcache_get(character varying, timestamp with time zone) IS 'DR: Get dbcache record with the provided name and at or after the provided time (DATE)';


--
-- PostgreSQL database dump complete
--

