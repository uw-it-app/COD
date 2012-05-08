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
-- Name: support_model; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE support_model (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    sort integer NOT NULL,
    disabled boolean NOT NULL,
    reject boolean DEFAULT false NOT NULL,
    help_text boolean DEFAULT false NOT NULL,
    active_notification boolean DEFAULT false NOT NULL,
    nag boolean DEFAULT false NOT NULL,
    nag_owned_period text DEFAULT '24 hours BHO'::text
);


ALTER TABLE cod_history.support_model OWNER TO postgres;

--
-- Name: support_model_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY support_model
    ADD CONSTRAINT support_model_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: support_model; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE support_model FROM PUBLIC;
REVOKE ALL ON TABLE support_model FROM postgres;
GRANT ALL ON TABLE support_model TO postgres;
GRANT SELECT ON TABLE support_model TO PUBLIC;


--
-- PostgreSQL database dump complete
--

