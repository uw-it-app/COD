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
-- Name: action; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE action (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    item_id integer NOT NULL,
    escalation_id integer,
    action_type_id integer NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    completed_by character varying,
    skipped boolean,
    successful boolean,
    content character varying
);


ALTER TABLE cod.action OWNER TO postgres;

--
-- Name: TABLE action; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE action IS 'DR: Prompted actions to perform (2011-10-12)';


--
-- Name: action_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.action_id_seq OWNER TO postgres;

--
-- Name: action_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE action_id_seq OWNED BY action.id;


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE action ALTER COLUMN id SET DEFAULT nextval('action_id_seq'::regclass);


--
-- Name: action_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY action
    ADD CONSTRAINT action_pkey PRIMARY KEY (id);


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON action FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_20_action_check; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_20_action_check BEFORE INSERT OR UPDATE ON action FOR EACH ROW EXECUTE PROCEDURE action_check();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON action FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON action FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON action FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: t_91_update_item; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_91_update_item AFTER INSERT OR UPDATE ON action FOR EACH ROW EXECUTE PROCEDURE update_item();


--
-- Name: action_action_type_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY action
    ADD CONSTRAINT action_action_type_id_fkey FOREIGN KEY (action_type_id) REFERENCES action_type(id) ON DELETE RESTRICT;


--
-- Name: action_escalation_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY action
    ADD CONSTRAINT action_escalation_id_fkey FOREIGN KEY (escalation_id) REFERENCES escalation(id) ON DELETE CASCADE;


--
-- Name: action_item_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY action
    ADD CONSTRAINT action_item_id_fkey FOREIGN KEY (item_id) REFERENCES item(id) ON DELETE CASCADE;


--
-- Name: action; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE action FROM PUBLIC;
REVOKE ALL ON TABLE action FROM postgres;
GRANT ALL ON TABLE action TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE action TO PUBLIC;


--
-- Name: action_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE action_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE action_id_seq FROM postgres;
GRANT ALL ON SEQUENCE action_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE action_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

