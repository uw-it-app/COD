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
    SELECT event.modified_at, event.modified_by, event.id, event.item_id, event.host, event.component, event.support_model_id, event.severity, event.contact, event.oncall_primary, event.oncall_alternate, event.helptext, event.source_id, event.start_at, event.end_at, event.content FROM (event JOIN (SELECT event.id AS uid, max(event.modified_at) AS mod FROM event GROUP BY event.id) uni ON (((event.id = uni.uid) AND (event.modified_at = uni.mod))));


ALTER TABLE cod_history.event_last OWNER TO postgres;

--
-- Name: VIEW event_last; Type: COMMENT; Schema: cod_history; Owner: postgres
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

