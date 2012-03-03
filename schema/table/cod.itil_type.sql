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
-- Name: itil_type; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE itil_type (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE cod.itil_type OWNER TO postgres;

--
-- Name: TABLE itil_type; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE itil_type IS 'DR: ITIL classification of the record (2012-02-28)';


--
-- Name: itil_type_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE itil_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.itil_type_id_seq OWNER TO postgres;

--
-- Name: itil_type_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE itil_type_id_seq OWNED BY itil_type.id;


--
-- Name: itil_type_id_seq; Type: SEQUENCE SET; Schema: cod; Owner: postgres
--

SELECT pg_catalog.setval('itil_type_id_seq', 34, true);


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE itil_type ALTER COLUMN id SET DEFAULT nextval('itil_type_id_seq'::regclass);


--
-- Data for Name: itil_type; Type: TABLE DATA; Schema: cod; Owner: postgres
--

INSERT INTO itil_type (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 1, 'Incident', '', 10, false);
INSERT INTO itil_type (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 2, 'Request', '', 30, false);
INSERT INTO itil_type (modified_at, modified_by, id, name, description, sort, disabled) VALUES ('2012-02-28 08:32:20.677493-08', 'postgres', 3, '(Notification)', '', 99, false);


--
-- Name: itil_type_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY itil_type
    ADD CONSTRAINT itil_type_name_key UNIQUE (name);


--
-- Name: itil_type_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY itil_type
    ADD CONSTRAINT itil_type_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO itil_type DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON itil_type FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON itil_type FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON itil_type FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON itil_type FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: itil_type; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE itil_type FROM PUBLIC;
REVOKE ALL ON TABLE itil_type FROM postgres;
GRANT ALL ON TABLE itil_type TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE itil_type TO PUBLIC;


--
-- Name: itil_type_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE itil_type_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE itil_type_id_seq FROM postgres;
GRANT ALL ON SEQUENCE itil_type_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE itil_type_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

