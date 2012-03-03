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
-- Name: esc_state; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE esc_state (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE cod.esc_state OWNER TO postgres;

--
-- Name: TABLE esc_state; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE esc_state IS 'DR: COD escalation state (2012-02-28)';


--
-- Name: esc_state_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE esc_state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.esc_state_id_seq OWNER TO postgres;

--
-- Name: esc_state_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE esc_state_id_seq OWNED BY esc_state.id;


--
-- Name: esc_state_id_seq; Type: SEQUENCE SET; Schema: cod; Owner: postgres
--

SELECT pg_catalog.setval('esc_state_id_seq', 34, true);


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE esc_state ALTER COLUMN id SET DEFAULT nextval('esc_state_id_seq'::regclass);


--
-- Data for Name: esc_state; Type: TABLE DATA; Schema: cod; Owner: postgres
--

INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 1, 'Building', 'Underconstruction', 0, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 2, 'Active', 'Active contact to Tier 2/3 support', 30, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 3, 'Failed', 'Failed notification to Tier 2/3 support', 33, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 4, 'Passive', 'Passive contact to Tier 2/3 support', 40, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 5, 'Owned', 'Tier 2/3 acknowedged issue', 60, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 6, 'Resolved', 'All work completed', 90, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 7, 'Rejected', 'Escalation misrouted', 91, false);
INSERT INTO esc_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 8, 'Merged', 'Escalation merged into another ticket', 92, false);


--
-- Name: esc_state_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY esc_state
    ADD CONSTRAINT esc_state_name_key UNIQUE (name);


--
-- Name: esc_state_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY esc_state
    ADD CONSTRAINT esc_state_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO esc_state DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON esc_state FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON esc_state FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON esc_state FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON esc_state FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: esc_state; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE esc_state FROM PUBLIC;
REVOKE ALL ON TABLE esc_state FROM postgres;
GRANT ALL ON TABLE esc_state TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE esc_state TO PUBLIC;


--
-- Name: esc_state_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE esc_state_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE esc_state_id_seq FROM postgres;
GRANT ALL ON SEQUENCE esc_state_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE esc_state_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

