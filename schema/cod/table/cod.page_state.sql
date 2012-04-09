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
-- Name: page_state; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE page_state (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE cod.page_state OWNER TO postgres;

--
-- Name: TABLE page_state; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE page_state IS 'DR: Status of paging for an escalation (2012-02-28)';


--
-- Name: page_state_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE page_state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.page_state_id_seq OWNER TO postgres;

--
-- Name: page_state_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE page_state_id_seq OWNED BY page_state.id;


--
-- Name: page_state_id_seq; Type: SEQUENCE SET; Schema: cod; Owner: postgres
--

SELECT pg_catalog.setval('page_state_id_seq', 34, true);


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE page_state ALTER COLUMN id SET DEFAULT nextval('page_state_id_seq'::regclass);


--
-- Data for Name: page_state; Type: TABLE DATA; Schema: cod; Owner: postgres
--

INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 1, 'Passive', 'No paging', 0, false);
INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 2, 'Active', 'Paging to start', 10, false);
INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 3, 'Act', 'Action required -- make phone call', 20, false);
INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 4, 'Escalating', 'Paging happening in the background', 30, false);
INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 5, 'Closed', 'Found an owner', 40, false);
INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 6, 'Cancelled', 'Paging cancelled', 50, false);
INSERT INTO page_state (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 7, 'Failed', 'Paging failed to find an owner', 60, false);


--
-- Name: page_state_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY page_state
    ADD CONSTRAINT page_state_name_key UNIQUE (name);


--
-- Name: page_state_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY page_state
    ADD CONSTRAINT page_state_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO page_state DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON page_state FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON page_state FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON page_state FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON page_state FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: page_state; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE page_state FROM PUBLIC;
REVOKE ALL ON TABLE page_state FROM postgres;
GRANT ALL ON TABLE page_state TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE page_state TO PUBLIC;


--
-- Name: page_state_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE page_state_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE page_state_id_seq FROM postgres;
GRANT ALL ON SEQUENCE page_state_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE page_state_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

