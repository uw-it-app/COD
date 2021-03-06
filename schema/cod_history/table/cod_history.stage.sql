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
-- Name: stage; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE stage (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    sort integer NOT NULL,
    disabled boolean NOT NULL
);


ALTER TABLE cod_history.stage OWNER TO postgres;

--
-- Name: stage_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: stage; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE stage FROM PUBLIC;
REVOKE ALL ON TABLE stage FROM postgres;
GRANT ALL ON TABLE stage TO postgres;
GRANT SELECT ON TABLE stage TO PUBLIC;


--
-- PostgreSQL database dump complete
--

