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
-- Name: escalation_build(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION escalation_build() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.escalation_build()
    Description:  trigger to run on Building escalations
    Affects:      NEW escalation record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _sep        varchar := E'------------------------------------------\n';
    _item       cod.item%ROWTYPE;
    _event      cod.event%ROWTYPE;
    _payload    varchar;
    _content    xml;
    _msg        varchar;
    _lmsg       varchar;
    _message    varchar;
    _tags       varchar[];
BEGIN
    -- get queue from H&M
    IF NEW.queue IS NULL THEN
        NEW.queue := hm_v1.get_oncall_queue(NEW.oncall_group);
        IF NEW.queue IS NULL THEN
            RETURN NULL;
        END IF;
    END IF;
    IF NEW.rt_ticket IS NULL THEN
        -- create ticket
        SELECT * INTO _item FROM cod.item WHERE id = NEW.item_id;
        SELECT * INTO _event FROM cod.event WHERE item_id = NEW.item_id ORDER BY id ASC LIMIT 1;
       _content = _event.content::xml;

        _msg  := xpath.get_varchar('/Event/Alert/Msg', _content);
        _lmsg := xpath.get_varchar('/Event/Alert/LongMsg', _content);

        _tags := array2.ucat(_tags, appconfig.get('COD_TAG', ''));

        _message := '';
        IF _event.host IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.host);
            _message := _message || 'Hostname: ' || _event.host || E'\n';
        END IF;
        IF _event.component IS NOT NULL THEN
            _tags := array2.ucat(_tags, _event.component);
            _message := _message || 'Component: ' || _event.component || E'\n';
        END IF;
        IF _msg IS NOT NULL THEN
            _message := _message || _sep || _msg || E'\n';
        END IF;
        IF _lmsg IS NOT NULL OR _lmsg <> _msg THEN
            _message := _message || _sep || _lmsg || E'\n';
        END IF;

        _payload := 'Subject: ' || _item.subject || E'\n' ||
                    'Queue: ' || NEW.queue || E'\n' ||
                    'Severity: ' || _item.severity::varchar ||  E'\n' ||
                    'Tags: ' || array_to_string(_tags, ' ') || E'\n' ||
                    'Super: ' || _item.rt_ticket || E'\n' ||
                    'Content: ' || _message || E'\n' ||
                    E'ENDOFCONTENT\nCF-TicketType: Incident\n';
        
        NEW.rt_ticket    := rt.create_ticket(_payload);
    END IF;
    IF NEW.page_state_id = standard.enum_value_id('cod', 'page_state', 'Passive') THEN
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Passive');
    ELSE
        NEW.esc_state_id := standard.enum_value_id('cod', 'esc_state', 'Active');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.escalation_build() OWNER TO postgres;

--
-- Name: FUNCTION escalation_build(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION escalation_build() IS 'DR: trigger to run on Building escalations (2012-02-26)';


--
-- PostgreSQL database dump complete
--

