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

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: escalation; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE escalation (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    item_id integer NOT NULL,
    rt_ticket integer,
    hm_issue integer,
    esc_state_id integer NOT NULL,
    page_state_id integer NOT NULL,
    oncall_group character varying NOT NULL,
    queue character varying,
    owner character varying NOT NULL,
    escalated_at timestamp with time zone NOT NULL,
    owned_at timestamp with time zone,
    resolved_at timestamp with time zone,
    content character varying
);


ALTER TABLE cod_history.escalation OWNER TO postgres;

--
-- Name: escalation_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY escalation
    ADD CONSTRAINT escalation_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: esc_state_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY escalation
    ADD CONSTRAINT esc_state_exists FOREIGN KEY (esc_state_id) REFERENCES cod.esc_state(id) ON DELETE RESTRICT;


--
-- Name: escalation; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE escalation FROM PUBLIC;
REVOKE ALL ON TABLE escalation FROM postgres;
GRANT ALL ON TABLE escalation TO postgres;
GRANT SELECT ON TABLE escalation TO PUBLIC;


--
-- PostgreSQL database dump complete
--

