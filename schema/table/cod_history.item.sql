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
-- Name: item; Type: TABLE; Schema: cod_history; Owner: postgres; Tablespace: 
--

CREATE TABLE item (
    deleted boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    modified_by character varying NOT NULL,
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by character varying NOT NULL,
    rt_ticket integer,
    hm_issue integer,
    subject character varying NOT NULL,
    state_id integer NOT NULL,
    itil_type_id integer NOT NULL,
    support_model_id integer NOT NULL,
    severity smallint NOT NULL,
    stage_id integer,
    reference_no character varying,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    escalated_at timestamp with time zone,
    resolved_at timestamp with time zone,
    closed_at timestamp with time zone,
    content character varying,
    workflow_lock boolean NOT NULL,
    nag_interval character varying NOT NULL,
    nag_next timestamp with time zone
);


ALTER TABLE cod_history.item OWNER TO postgres;

--
-- Name: item_id_modified_at_key; Type: CONSTRAINT; Schema: cod_history; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_id_modified_at_key UNIQUE (id, modified_at);


--
-- Name: itil_type_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT itil_type_exists FOREIGN KEY (itil_type_id) REFERENCES cod.itil_type(id) ON DELETE RESTRICT;


--
-- Name: stage_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT stage_exists FOREIGN KEY (stage_id) REFERENCES cod.stage(id) ON DELETE RESTRICT;


--
-- Name: state_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT state_exists FOREIGN KEY (state_id) REFERENCES cod.state(id) ON DELETE RESTRICT;


--
-- Name: support_model_exists; Type: FK CONSTRAINT; Schema: cod_history; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT support_model_exists FOREIGN KEY (support_model_id) REFERENCES cod.support_model(id) ON DELETE CASCADE;


--
-- Name: item; Type: ACL; Schema: cod_history; Owner: postgres
--

REVOKE ALL ON TABLE item FROM PUBLIC;
REVOKE ALL ON TABLE item FROM postgres;
GRANT ALL ON TABLE item TO postgres;
GRANT SELECT ON TABLE item TO PUBLIC;


--
-- PostgreSQL database dump complete
--

