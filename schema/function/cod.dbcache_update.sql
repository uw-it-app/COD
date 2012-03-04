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
-- Name: dbcache_update(character varying, character varying, timestamp with time zone); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION dbcache_update(character varying, character varying, timestamp with time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.dbcache_update(varchar, varchar, timestamptz)
    Description:  Update or insert a dbcache record
    Affects:      Updates or Inserts a dbcache record
    Arguments:    varchar: name of the record
                  varchar: content of the record
                  timestamptz: timekey of the record
    Returns:      boolean
*/
DECLARE
    v_name      ALIAS FOR $1;
    v_content   ALIAS FOR $2;
    v_timekey   ALIAS FOR $3;
    _timekey    timestamptz;
BEGIN
    IF v_timekey IS NULL THEN
        _timekey := now();
    ELSE
        _timekey := v_timekey;
    END IF;

    UPDATE cod.dbcache SET content = v_content, timekey = _timekey WHERE name = v_name and timekey < _timekey;
    IF NOT FOUND AND NOT EXISTS (SELECT NULL FROM cod.dbcache WHERE name = v_name) THEN
        INSERT INTO cod.dbcache (name, content, timekey) VALUES (v_name, v_content, _timekey);
    ELSE 
        RETURN FALSE;
    END IF;
    RETURN TRUE;
END;
$_$;


ALTER FUNCTION cod.dbcache_update(character varying, character varying, timestamp with time zone) OWNER TO postgres;

--
-- Name: FUNCTION dbcache_update(character varying, character varying, timestamp with time zone); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION dbcache_update(character varying, character varying, timestamp with time zone) IS 'DR: Update or insert a dbcache record (2012-02-26)';


--
-- PostgreSQL database dump complete
--

