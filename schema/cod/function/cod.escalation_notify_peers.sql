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
-- Name: escalation_notify_peers(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_notify_peers() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.escalation_notify_peers()
    Description:  Updates peer escalations (subs) of new escalation
    Affects:      Peer Escalation RT tickets
    Arguments:
    Returns:      trigger
*/
DECLARE
    _sep            varchar := E'------------------------------------------\n';
    _payload        varchar;
BEGIN
    _payload := E'UpdateType: comment\n'
            || E'CONTENT: New escalation:\n'
            || E' -- Oncall Group: "' || NEW.oncall_group || E'"\n'
            || E' -- RT Queue: "' || NEW.queue || E'"\n'
            || E' -- RT Ticket #' || NEW.rt_ticket || E'\n' || _sep
            || COALESCE(xpath.get_varchar('/Escalation/Note', NEW.content::xml), '') || E'\n'
            || cod_v2.comment_post()
            || E'ENDOFCONTENT\n';
    PERFORM rt.update_ticket(rt_ticket, _payload) FROM cod.escalation
        WHERE item_id = NEW.item_id AND id <> NEW.id AND
            esc_state_id IN (SELECT id FROM cod.esc_state WHERE sort <= 60); -- Owned or Newer
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$_$;


ALTER FUNCTION cod.escalation_notify_peers() OWNER TO postgres;

--
-- Name: FUNCTION escalation_notify_peers(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_notify_peers() IS 'DR: Updates peer escalations (subs) of new escalation (2012-06-26)';


--
-- PostgreSQL database dump complete
--

