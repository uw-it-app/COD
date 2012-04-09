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
-- Name: state; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE state (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    sort integer NOT NULL,
    disabled boolean NOT NULL
);


ALTER TABLE cod_history.state OWNER TO postgres;

--
-- Name: state_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY state
    ADD CONSTRAINT state_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: state; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE state FROM PUBLIC;
REVOKE ALL ON TABLE state FROM postgres;
GRANT ALL ON TABLE state TO postgres;
GRANT SELECT ON TABLE state TO PUBLIC;


--
-- PostgreSQL database dump complete
--

