--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod_history, pg_catalog;

--
-- Name: event_last; Type: VIEW; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE VIEW event_last AS
    SELECT modified_at, modified_by, id, item_id, host, component, support_model_id, severity, contact, oncall_primary, oncall_alternate, helptext, source_id, start_at, end_at, content 
    FROM cod_history.event 
    JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.event GROUP BY id) AS uni ON (id = uid AND modified_at = mod);


ALTER TABLE cod_history.event_last OWNER TO postgres;

--
-- Name: TABLE event_last; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON VIEW event_last IS 'DR: Most recent state of an event (2012-04-16)';


--
-- Name: event_last; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE event_last FROM PUBLIC;
REVOKE ALL ON TABLE event_last FROM postgres;
GRANT ALL ON TABLE event_last TO postgres;
GRANT SELECT ON TABLE event_last TO PUBLIC;


--
-- PostgreSQL database dump complete
--
