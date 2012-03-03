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
-- Name: inject(character varying, character varying); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION inject(character varying, character varying) RETURNS xml
    LANGUAGE sql
    AS $_$
/*  Function:     cod.inject(varchar, varchar)
    Description:  Inject a faux alert
    Affects:      Creates and incident
    Arguments:    varchar: hostname
                  varchar: support model
    Returns:      xml
*/
SELECT cod_v2.spawn_item_from_alert(('<Event><Netid>joby</Netid><Operator>AIE-AE</Operator><OnCall>ssg_oncall</OnCall><AltOnCall>uwnetid_joby</AltOnCall><SupportModel>' || $2 || '</SupportModel><LifeCycle>deployed</LifeCycle><Source>prox</Source><VisTime>500</VisTime><Alert><ProblemHost>' || $1 || '</ProblemHost><Flavor>prox</Flavor><Origin/><Component>joby-test</Component><Msg>Test</Msg><LongMsg>Just a test by joby</LongMsg><Contact>uwnetid_joby</Contact><Owner/><Ticket/><IssueNum/><ItemNum/><Severity>10</Severity><Count>1</Count><Increment>false</Increment><StartTime>1283699633122</StartTime><AutoClear>true</AutoClear><Action>Upd</Action></Alert></Event>')::xml);
$_$;


ALTER FUNCTION cod.inject(character varying, character varying) OWNER TO postgres;

--
-- Name: FUNCTION inject(character varying, character varying); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION inject(character varying, character varying) IS 'DR: Inject a faux alert (2012-02-15)';


--
-- PostgreSQL database dump complete
--

