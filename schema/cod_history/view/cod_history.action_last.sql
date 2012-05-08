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
-- Name: action_last; Type: VIEW; Schema: cod_history; Owner: postgres
--

CREATE OR REPLACE VIEW action_last AS
    SELECT action.modified_at, action.modified_by, action.id, action.item_id, action.escalation_id, action.action_type_id, action.started_at, action.completed_at, action.completed_by, action.skipped, action.successful, action.content FROM (action JOIN (SELECT action.id AS uid, max(action.modified_at) AS mod FROM action GROUP BY action.id) uni ON (((action.id = uni.uid) AND (action.modified_at = uni.mod))));


ALTER TABLE cod_history.action_last OWNER TO postgres;

--
-- Name: VIEW action_last; Type: COMMENT; Schema: cod_history; Owner: postgres
--

COMMENT ON VIEW action_last IS 'DR: Show the last state of an action (2012-04-16)';


--
-- Name: action_last; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE action_last FROM PUBLIC;
REVOKE ALL ON TABLE action_last FROM postgres;
GRANT ALL ON TABLE action_last TO postgres;
GRANT SELECT ON TABLE action_last TO PUBLIC;


--
-- PostgreSQL database dump complete
--

