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
-- Name: item_rt_update(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION item_rt_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.item_rt_update()
    Description:  Update rt with item metadata
    Affects:
    Arguments:
    Returns:      trigger
*/
DECLARE
    _payload    varchar  := '';
    _comment    varchar  := '';
    _string     varchar;
BEGIN
    IF OLD.itil_type_id IS DISTINCT FROM NEW.itil_type_id THEN
        _string  := standard.enum_id_value('cod', 'itil_type', NEW.itil_type_id);
        _comment := _comment
                 || 'ITIL Type: ' || _string || E'\n';
        IF _string ~ E'^\\(.*\\)$' THEN
            _string = '';
        END IF;
        _payload := _payload
                 || 'CF-TicketType: ' || _string || E'\n';
    END IF;
    IF OLD.support_model_id IS DISTINCT FROM NEW.support_model_id THEN
        _comment := _comment
                 || 'Support Model: ' || standard.enum_id_value('cod', 'support_model', NEW.support_model_id) || E'\n';
    END IF;
    IF OLD.severity IS DISTINCT FROM NEW.severity THEN
        _comment := _comment
                 || 'Severity: ' || NEW.severity::varchar || E'\n';
        _payload := _payload
                 || 'Severity: ' || NEW.severity::varchar || E'\n';
    END IF;
    IF OLD.reference_no IS DISTINCT FROM NEW.reference_no THEN
        IF NEW.reference_no IS NULL THEN
            _string := '';
        ELSE
            _string := NEW.reference_no;
        END IF;
        _comment := _comment
                 || 'Reference Number: ' || _string || E'\n';
    END IF;
    IF NEW.state_id = standard.enum_value_id('cod', 'state', 'Closed') THEN
        _payload := _payload
                 || E'Status: resolved\n';

    END IF;
    IF NEW.state_id <> OLD.state_id AND
        OLD.state_id IN (SELECT id FROM cod.state WHERE name IN ('Closed', 'Merged')) AND
        NEW.state_id NOT IN (SELECT id FROM cod.state WHERE name IN ('Closed', 'Merged'))
    THEN
        _payload := _payload
                 || E'Status: open\n';
    END IF;
    IF OLD.subject IS DISTINCT FROM NEW.subject THEN
        _payload := _payload
                 || E'Subject: '|| New.subject || E'\n';

    END IF;
    IF _comment <> '' THEN
        _payload := E'UpdateType: comment\n'
                 || E'CONTENT: ' || _comment || cod_v2.comment_post()
                 || E'ENDOFCONTENT\n'
                 || _payload;
    END IF;
    IF _payload <> '' THEN
        PERFORM rt.update_ticket(NEW.rt_ticket, _payload);
    END IF;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN RETURN NEW;
END;
$_$;


ALTER FUNCTION cod.item_rt_update() OWNER TO postgres;

--
-- Name: FUNCTION item_rt_update(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION item_rt_update() IS 'DR: Update rt with item metadata (2012-02-29)';


--
-- PostgreSQL database dump complete
--

