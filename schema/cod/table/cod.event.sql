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
-- Name: event; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE event (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    item_id integer,
    host character varying,
    component character varying,
    support_model_id integer NOT NULL,
    severity smallint DEFAULT 3 NOT NULL,
    contact character varying,
    oncall_primary character varying,
    oncall_alternate character varying,
    helptext character varying,
    source_id integer DEFAULT 1 NOT NULL,
    start_at timestamp with time zone DEFAULT now() NOT NULL,
    end_at timestamp with time zone,
    content character varying,
    CONSTRAINT event_severity_check CHECK (((severity >= 1) AND (severity <= 5)))
);


ALTER TABLE cod.event OWNER TO postgres;

--
-- Name: TABLE event; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE event IS 'DR: Event associated with an item (incident) (2011-10-12)';


--
-- Name: event_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.event_id_seq OWNER TO postgres;

--
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE event_id_seq OWNED BY event.id;


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY event ALTER COLUMN id SET DEFAULT nextval('event_id_seq'::regclass);


--
-- Name: event_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON event FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_12_check_helptext; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_12_check_helptext BEFORE INSERT ON event FOR EACH ROW EXECUTE PROCEDURE event_check_helptext();


--
-- Name: t_20_check; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_20_check BEFORE INSERT OR UPDATE ON event FOR EACH ROW EXECUTE PROCEDURE event_check();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON event FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON event FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON event FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: t_91_update_item; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_91_update_item AFTER INSERT OR UPDATE ON event FOR EACH ROW EXECUTE PROCEDURE update_item();


--
-- Name: event_item_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_item_id_fkey FOREIGN KEY (item_id) REFERENCES item(id) ON DELETE CASCADE;


--
-- Name: event_source_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_source_id_fkey FOREIGN KEY (source_id) REFERENCES source(id) ON DELETE RESTRICT;


--
-- Name: event_support_model_id_fkey; Type: FK CONSTRAINT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_support_model_id_fkey FOREIGN KEY (support_model_id) REFERENCES support_model(id) ON DELETE RESTRICT;


--
-- Name: event; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE event FROM PUBLIC;
REVOKE ALL ON TABLE event FROM postgres;
GRANT ALL ON TABLE event TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE event TO PUBLIC;


--
-- Name: event_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE event_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE event_id_seq FROM postgres;
GRANT ALL ON SEQUENCE event_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE event_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

