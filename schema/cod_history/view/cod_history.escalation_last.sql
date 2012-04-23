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
    SELECT modified_at, modified_by, id, item_id, rt_ticket, hm_issue, esc_state_id, page_state_id, oncall_group, queue, owner, escalated_at, owned_at, resolved_at, content 
    FROM cod_history.escalation
    JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.escalation GROUP BY id) AS uni ON (id = uid AND modified_at = mod);


ALTER TABLE cod_history.escalation_last OWNER TO postgres;

--
-- Name: TABLE escalation_last; Type: COMMENT; Schema: cod; Owner: postgres
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
