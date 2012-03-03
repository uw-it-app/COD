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
-- Name: itil_type; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE itil_type (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    sort integer NOT NULL,
    disabled boolean NOT NULL
);


ALTER TABLE cod_history.itil_type OWNER TO postgres;

--
-- Name: itil_type_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY itil_type
    ADD CONSTRAINT itil_type_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: itil_type; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE itil_type FROM PUBLIC;
REVOKE ALL ON TABLE itil_type FROM postgres;
GRANT ALL ON TABLE itil_type TO postgres;
GRANT SELECT ON TABLE itil_type TO PUBLIC;


--
-- PostgreSQL database dump complete
--

