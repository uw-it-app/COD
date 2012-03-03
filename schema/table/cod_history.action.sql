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
-- Name: action; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE action (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    item_id integer NOT NULL,
    escalation_id integer,
    action_type_id integer NOT NULL,
    started_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    completed_by character varying,
    skipped boolean,
    successful boolean,
    content character varying
);


ALTER TABLE cod_history.action OWNER TO postgres;

--
-- Name: action_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY action
    ADD CONSTRAINT action_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: action_type_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY action
    ADD CONSTRAINT action_type_exists FOREIGN KEY (action_type_id) REFERENCES cod.action_type(id) ON DELETE RESTRICT;


--
-- Name: action; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE action FROM PUBLIC;
REVOKE ALL ON TABLE action FROM postgres;
GRANT ALL ON TABLE action TO postgres;
GRANT SELECT ON TABLE action TO PUBLIC;


--
-- PostgreSQL database dump complete
--

