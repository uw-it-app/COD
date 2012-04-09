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
-- Name: can_spawn(character varying); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION can_spawn(character varying) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
/*  Function:     cod_v2.can_spawn(varchar)
    Description:  True if the uwnetid is premitted to spawn incidents from events
    Affects:      nothing
    Arguments:    varchar: uwnetid
    Returns:      boolean
*/
DECLARE
    v_netid     ALIAS FOR $1;
BEGIN
    IF ARRAY[v_netid] <@ '{alexc,areed,blakjack,cil5,ddiehl,guerrero,ljahed,lyns,mhouli,rliesik,schrud,tblood,tynand,wizofoz,joby,kkurth,ldugan,kenm}'::varchar[] 
    THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;


ALTER FUNCTION cod_v2.can_spawn(character varying) OWNER TO postgres;

--
-- Name: FUNCTION can_spawn(character varying); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION can_spawn(character varying) IS 'DR: True if the uwnetid is premitted to spawn incidents from events (2012-02-26)';


--
-- PostgreSQL database dump complete
--

