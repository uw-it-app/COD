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
-- Name: state; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE state (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE cod.state OWNER TO postgres;

--
-- Name: TABLE state; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE state IS 'DR: COD Item Activity State (2012-02-28)';


--
-- Name: state_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.state_id_seq OWNER TO postgres;

--
-- Name: state_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE state_id_seq OWNED BY state.id;


--
-- Name: state_id_seq; Type: SEQUENCE SET; Schema: cod; Owner: postgres
--

SELECT pg_catalog.setval('state_id_seq', 41, true);


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE state ALTER COLUMN id SET DEFAULT nextval('state_id_seq'::regclass);


--
-- Data for Name: state; Type: TABLE DATA; Schema: cod; Owner: postgres
--

INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 1, 'Building', 'Underconstruction', 0, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 2, 'Act', 'COPS has an action to perform', 10, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 3, 'Processing', 'COD is updating data in the background', 20, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 4, 'Escalating', 'Active contact to Level 2/3 support', 30, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 5, 'Tier2', 'Escalated to Tier 2', 60, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 6, 'Cleared', 'Impact cleared but not resolved', 80, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 7, 'Resolved', 'All work completed', 90, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 8, 'Closed', 'Closure Complete', 99, false);
INSERT INTO state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-03-01 17:04:26.60117-08', 'postgres', 9, 'Merged', 'Merged into another Item', 100, false);


--
-- Name: state_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY state
    ADD CONSTRAINT state_name_key UNIQUE (name);


--
-- Name: state_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY state
    ADD CONSTRAINT state_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO state DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON state FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON state FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON state FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON state FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: state; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE state FROM PUBLIC;
REVOKE ALL ON TABLE state FROM postgres;
GRANT ALL ON TABLE state TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE state TO PUBLIC;


--
-- Name: state_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE state_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE state_id_seq FROM postgres;
GRANT ALL ON SEQUENCE state_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE state_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

