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
-- Name: escalation_last; Type: VIEW; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE VIEW escalation_last AS
    SELECT escalation.modified_at, escalation.modified_by, escalation.id, escalation.item_id, escalation.rt_ticket, escalation.hm_issue, escalation.esc_state_id, escalation.page_state_id, escalation.oncall_group, escalation.queue, escalation.owner, escalation.escalated_at, escalation.owned_at, escalation.resolved_at, escalation.content FROM (escalation JOIN (SELECT escalation.id AS uid, max(escalation.modified_at) AS mod FROM escalation GROUP BY escalation.id) uni ON (((escalation.id = uni.uid) AND (escalation.modified_at = uni.mod))));


ALTER TABLE cod_history.escalation_last OWNER TO postgres;

--
-- Name: VIEW escalation_last; Type: COMMENT; Schema: cod_history; Owner: postgres
--

COMMENT ON VIEW escalation_last IS 'DR: Show the last state of an escalation (2012-04-16)';


--
-- Name: escalation_last; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE escalation_last FROM PUBLIC;
REVOKE ALL ON TABLE escalation_last FROM postgres;
GRANT ALL ON TABLE escalation_last TO postgres;
GRANT SELECT ON TABLE escalation_last TO PUBLIC;


--
-- PostgreSQL database dump complete
--

