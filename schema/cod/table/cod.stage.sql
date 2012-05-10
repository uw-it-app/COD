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
-- Name: stage; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE stage (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE cod.stage OWNER TO postgres;

--
-- Name: TABLE stage; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE stage IS 'DR: Stage in the ITIL Incident Process (2012-02-28)';


--
-- Name: stage_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.stage_id_seq OWNER TO postgres;

--
-- Name: stage_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE stage_id_seq OWNED BY stage.id;


--
-- Name: stage_id_seq; Type: SEQUENCE SET; Schema: cod; Owner: postgres
--

SELECT pg_catalog.setval('stage_id_seq', 12, true);


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY stage ALTER COLUMN id SET DEFAULT nextval('stage_id_seq'::regclass);


--
-- Data for Name: stage; Type: TABLE DATA; Schema: cod; Owner: postgres
--

INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 1, 'Identification', '', 10, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 2, 'Logging', '', 20, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 3, 'Categorization', '', 30, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 4, 'Prioritization', '', 40, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 5, 'Initial Diagnosis', '', 50, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 6, 'Functional Escalation', '', 60, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 7, 'Management Escalation', '', 70, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 8, 'Investigation and Diagnosis', '', 80, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 9, 'Resolution and Recovery', '', 90, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 10, 'Closure', '', 99, false);
INSERT INTO stage (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-03-01 17:04:26.591756-08', 'postgres', 11, '', '', 0, false);


--
-- Name: stage_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_name_key UNIQUE (name);


--
-- Name: stage_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stage
    ADD CONSTRAINT stage_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO stage DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON stage FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON stage FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON stage FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON stage FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: stage; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE stage FROM PUBLIC;
REVOKE ALL ON TABLE stage FROM postgres;
GRANT ALL ON TABLE stage TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE stage TO PUBLIC;


--
-- Name: stage_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE stage_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE stage_id_seq FROM postgres;
GRANT ALL ON SEQUENCE stage_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE stage_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

