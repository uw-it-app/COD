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
-- Name: event; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE event (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    item_id integer,
    host character varying,
    component character varying,
    support_model_id integer NOT NULL,
    severity smallint NOT NULL,
    contact character varying,
    oncall_primary character varying,
    oncall_alternate character varying,
    helptext character varying,
    source_id integer NOT NULL,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone,
    content character varying
);


ALTER TABLE cod_history.event OWNER TO postgres;

--
-- Name: event_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: support_model_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY event
    ADD CONSTRAINT support_model_exists FOREIGN KEY (support_model_id) REFERENCES cod.support_model(id) ON DELETE CASCADE;


--
-- Name: event; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE event FROM PUBLIC;
REVOKE ALL ON TABLE event FROM postgres;
GRANT ALL ON TABLE event TO postgres;
GRANT SELECT ON TABLE event TO PUBLIC;


--
-- PostgreSQL database dump complete
--

