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
-- Name: item_event_duplicate; Type: VIEW; Schema: cod; Owner: postgres
--

CREATE OR REPLACE VIEW item_event_duplicate AS
    SELECT e.id AS event_id, i.id AS item_id, e.host, e.component, e.contact, i.rt_ticket, s.name AS state FROM ((event e JOIN item i ON ((i.id = e.item_id))) JOIN state s ON ((s.id = i.state_id))) WHERE (s.sort < 90);


ALTER TABLE cod.item_event_duplicate OWNER TO postgres;

--
-- Name: VIEW item_event_duplicate; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON VIEW item_event_duplicate IS 'DR: View to find duplicate event/items to an incoming event (2011-10-20)';


--
-- Name: item_event_duplicate; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE item_event_duplicate FROM PUBLIC;
REVOKE ALL ON TABLE item_event_duplicate FROM postgres;
GRANT ALL ON TABLE item_event_duplicate TO postgres;
GRANT SELECT ON TABLE item_event_duplicate TO PUBLIC;


--
-- PostgreSQL database dump complete
--

