BEGIN;



UPDATE cod.source SET description = 'Dash - Pilot' WHERE name = 'pilot';
UPDATE cod.source SET description = 'Dash - Accumulator' WHERE name = 'acc';
UPDATE cod.source SET description = 'Dash - Proxd' WHERE name = 'prox';
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
-- Name: incident_nag_check(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION incident_nag_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
/*  Function:     cod.incident_nag_check()
    Description:  Ensure the nag_next time is properly set or unset
    Affects:      Active row
    Arguments:    none
    Returns:      trigger
*/
DECLARE
    _interval   text;
    _next       timestamptz;
    _model      cod.support_model%ROWTYPE;
BEGIN
    SELECT * INTO _model FROM cod.support_model WHERE id = NEW.support_model_id;
    IF _model.nag IS TRUE AND EXISTS(SELECT NULL FROM cod.escalation JOIN cod.esc_state ON (cod.escalation.esc_state_id = cod.esc_state.id) WHERE cod.escalation.item_id = NEW.id AND cod.esc_state.name NOT IN ('Resolved', 'Rejected', 'Merged') )
    THEN

        IF NEW.nag_interval IS NOT NULL THEN
            -- use item specific interval if set
            _interval := NEW.nag_interval;
        ELSEIF EXISTS(SELECT NULL FROM cod.escalation WHERE item_id = NEW.id AND esc_state_id = standard.enum_value_id('cod', 'esc_state', 'Owned')) 
        THEN
            -- otherwise if there is an owned escalation use the Support Model nag_owned_period
            _interval := _model.nag_owned_period;
        END IF;

        -- if _interval is still null use the system default
        IF _interval IS NULL THEN
            _interval := appconfig.get('COD_DEFAULT_NAG');
        END IF;

        IF _interval ~* 'BHO$' THEN
            -- if the interval end with BHO then it should be during business hours only
            _interval = regexp_replace(_interval, 'BHO$', '');
            _next := hm_v1.get_business_timestamp(
                _interval::interval,
                appconfig.get('COD_NAG_BUSINESS_START')::time,
                appconfig.get('COD_NAG_BUSINESS_END')::time
            );
        ELSE
            -- otherwise just increment now
            _next := now() + _interval::interval;
        END IF;

        -- only update if nag_next is null or if _next is more recent
        IF NEW.nag_next IS NULL OR NEW.nag_next > _next THEN
            NEW.nag_next := _next;
        END IF;
    ELSE
        NEW.nag_next := NULL;
    END IF;
    RETURN NEW;
END;
$_$;


ALTER FUNCTION cod.incident_nag_check() OWNER TO postgres;

--
-- Name: FUNCTION incident_nag_check(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION incident_nag_check() IS 'DR: Ensure the nag_next time is properly set or unset (2012-02-22)';


--
-- PostgreSQL database dump complete
--

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
-- Name: event_xml(integer); Type: FUNCTION; Schema: cod_v2; Owner: postgres
--

CREATE OR REPLACE FUNCTION event_xml(integer) RETURNS xml
    LANGUAGE sql STABLE
    AS $_$
/*  Function:     cod_v2.event_xml(integer)
    Description:  XML Representation of an Event
    Affects:      nothing
    Arguments:    integer: event id
    Returns:      XML Representation
*/
    SELECT xmlelement(name "Event",
        xmlelement(name "Id", event.id),
        xmlelement(name "Host", event.host),
        xmlelement(name "Component", event.component),
        xmlelement(name "SupportModel", model.name),
        xmlelement(name "Severity", event.severity),
        xmlelement(name "Contact", event.contact),
        xmlelement(name "OncallPrimary", event.oncall_primary),
        xmlelement(name "OncallAlternate", event.oncall_alternate),
        xmlelement(name "HelpText", event.helptext),
        xmlelement(name "Subject", xpath.get_varchar('/Event/Subject', event.content::xml)),
        xmlelement(name "Message", xpath.get_varchar('/Event/Alert/Msg', event.content::xml)),
        xmlelement(name "LongMessage", xpath.get_varchar('/Event/Alert/LongMsg', event.content::xml)),
        xmlelement(name "Source", source.description),
        xmlelement(name "Content", event.content::xml),
        xmlelement(name "Modified",
            xmlelement(name "At", date_trunc('second', event.modified_at)::timestamp::varchar),
            xmlelement(name "By", event.modified_by)
        ),
        xmlelement(name "Times",
            xmlelement(name "Start", date_trunc('second', event.start_at)::timestamp::varchar),
            xmlelement(name "End", date_trunc('second', event.end_at)::timestamp::varchar)
        )
    ) FROM cod.event AS event
      JOIN cod.support_model AS model ON (event.support_model_id = model.id)
      JOIN cod.source AS source ON (event.source_id = source.id)
     WHERE event.id = $1;
$_$;


ALTER FUNCTION cod_v2.event_xml(integer) OWNER TO postgres;

--
-- Name: FUNCTION event_xml(integer); Type: COMMENT; Schema: cod_v2; Owner: postgres
--

COMMENT ON FUNCTION event_xml(integer) IS 'DR: XML Representation of an Event (2012-02-26)';


--
-- PostgreSQL database dump complete
--



COMMIT;
