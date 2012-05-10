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
-- Name: item; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE item (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    rt_ticket integer,
    hm_issue integer,
    subject character varying NOT NULL,
    state_id integer DEFAULT 1 NOT NULL,
    itil_type_id integer DEFAULT 1 NOT NULL,
    support_model_id integer DEFAULT 1 NOT NULL,
    severity smallint DEFAULT 3 NOT NULL,
    stage_id integer DEFAULT 1,
    reference_no character varying,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    escalated_at timestamp with time zone,
    resolved_at timestamp with time zone,
    closed_at timestamp with time zone,
    content character varying,
    workflow_lock boolean DEFAULT false NOT NULL,
    nag_interval character varying,
    nag_next timestamp with time zone,
    CONSTRAINT item_severity_check CHECK (((severity >= 1) AND (severity <= 5)))
);


ALTER TABLE cod.item OWNER TO postgres;

--
-- Name: TABLE item; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE item IS 'DR: COD Line items -- incidents, notifications, etc (2011-10-10)';


--
-- Name: item_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.item_id_seq OWNER TO postgres;

--
-- Name: item_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE item_id_seq OWNED BY item.id;


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY item ALTER COLUMN id SET DEFAULT nextval('item_id_seq'::regclass);


--
-- Name: item_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON item FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_10_lock_merged; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_lock_merged BEFORE INSERT OR UPDATE ON item FOR EACH ROW WHEN ((new.state_id = 9)) EXECUTE PROCEDURE lock_merged();


--
-- Name: t_15_update_times; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_15_update_times BEFORE INSERT OR UPDATE ON item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE)) EXECUTE PROCEDURE incident_time_check();


--
-- Name: t_20_incident_state_check; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_20_incident_state_check BEFORE INSERT OR UPDATE ON item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE)) EXECUTE PROCEDURE incident_state_check();


--
-- Name: t_25_incident_stage_check; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_25_incident_stage_check BEFORE INSERT OR UPDATE ON item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE)) EXECUTE PROCEDURE incident_stage_check();


--
-- Name: t_28_nag_check; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_28_nag_check BEFORE INSERT OR UPDATE ON item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE)) EXECUTE PROCEDURE incident_nag_check();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON item FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON item FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_70_update_rt; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_70_update_rt BEFORE UPDATE ON item FOR EACH ROW WHEN (((new.workflow_lock IS FALSE) AND (new.rt_ticket IS NOT NULL))) EXECUTE PROCEDURE item_rt_update();


--
-- Name: t_90_incident_workflow; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_incident_workflow AFTER INSERT OR UPDATE ON item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE)) EXECUTE PROCEDURE incident_workflow();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON item FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: item_itil_type_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_itil_type_id_fkey FOREIGN KEY (itil_type_id) REFERENCES itil_type(id) ON DELETE RESTRICT;


--
-- Name: item_stage_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES stage(id) ON DELETE RESTRICT;


--
-- Name: item_state_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_state_id_fkey FOREIGN KEY (state_id) REFERENCES state(id) ON DELETE RESTRICT;


--
-- Name: item_support_model_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_support_model_id_fkey FOREIGN KEY (support_model_id) REFERENCES support_model(id) ON DELETE RESTRICT;


--
-- Name: item; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE item FROM PUBLIC;
REVOKE ALL ON TABLE item FROM postgres;
GRANT ALL ON TABLE item TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE item TO PUBLIC;


--
-- Name: item_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE item_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE item_id_seq FROM postgres;
GRANT ALL ON SEQUENCE item_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE item_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

