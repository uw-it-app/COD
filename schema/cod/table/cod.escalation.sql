--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = cod, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: escalation; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE escalation (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    item_id integer NOT NULL,
    rt_ticket integer,
    hm_issue integer,
    esc_state_id integer DEFAULT 1 NOT NULL,
    page_state_id integer DEFAULT 1 NOT NULL,
    oncall_group character varying NOT NULL,
    queue character varying,
    owner character varying DEFAULT 'nobody'::character varying NOT NULL,
    escalated_at timestamp with time zone DEFAULT now() NOT NULL,
    owned_at timestamp with time zone,
    resolved_at timestamp with time zone,
    content character varying
);


ALTER TABLE cod.escalation OWNER TO postgres;

--
-- Name: TABLE escalation; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE escalation IS 'DR: Track Tickets (etc) for escalation to L2/3 oncall groups';


--
-- Name: escalation_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE escalation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.escalation_id_seq OWNER TO postgres;

--
-- Name: escalation_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE escalation_id_seq OWNED BY escalation.id;


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE escalation ALTER COLUMN id SET DEFAULT nextval('escalation_id_seq'::regclass);


--
-- Name: escalation_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY escalation
    ADD CONSTRAINT escalation_pkey PRIMARY KEY (id);


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON escalation FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_20_escalation_build; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_20_escalation_build BEFORE INSERT OR UPDATE ON escalation FOR EACH ROW WHEN ((new.esc_state_id = 1)) EXECUTE PROCEDURE escalation_build();


--
-- Name: t_30_check; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_check BEFORE INSERT OR UPDATE ON escalation FOR EACH ROW WHEN ((new.esc_state_id <> 1)) EXECUTE PROCEDURE escalation_check();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON escalation FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON escalation FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_escalation_workflow; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_escalation_workflow AFTER INSERT OR UPDATE ON escalation FOR EACH ROW WHEN ((new.esc_state_id <> 1)) EXECUTE PROCEDURE escalation_workflow();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON escalation FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: t_91_update_item; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_91_update_item AFTER INSERT OR UPDATE ON escalation FOR EACH ROW EXECUTE PROCEDURE update_item();


--
-- Name: escalation_esc_state_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY escalation
    ADD CONSTRAINT escalation_esc_state_id_fkey FOREIGN KEY (esc_state_id) REFERENCES esc_state(id) ON DELETE RESTRICT;


--
-- Name: escalation_item_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY escalation
    ADD CONSTRAINT escalation_item_id_fkey FOREIGN KEY (item_id) REFERENCES item(id) ON DELETE CASCADE;


--
-- Name: escalation_page_state_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY escalation
    ADD CONSTRAINT escalation_page_state_id_fkey FOREIGN KEY (page_state_id) REFERENCES page_state(id) ON DELETE RESTRICT;


--
-- Name: escalation; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE escalation FROM PUBLIC;
REVOKE ALL ON TABLE escalation FROM postgres;
GRANT ALL ON TABLE escalation TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE escalation TO PUBLIC;


--
-- Name: escalation_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE escalation_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE escalation_id_seq FROM postgres;
GRANT ALL ON SEQUENCE escalation_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE escalation_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

