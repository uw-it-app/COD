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
    SELECT modified_at, modified_by, id, item_id, escalation_id, action_type_id, started_at, completed_at, completed_by, skipped, successful, content
    FROM cod_history.action
    JOIN (SELECT id AS uid, max(modified_at) AS mod FROM cod_history.action GROUP BY id) AS uni ON (id = uid AND modified_at = mod);


ALTER TABLE cod_history.action_last OWNER TO postgres;

--
-- Name: TABLE action_last; Type: COMMENT; Schema: cod; Owner: postgres
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
