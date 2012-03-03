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
-- Name: source; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE source (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL
);


ALTER TABLE cod.source OWNER TO postgres;

--
-- Name: TABLE source; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE source IS 'DR: Event sources (2012-02-28)';


--
-- Name: source_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.source_id_seq OWNER TO postgres;

--
-- Name: source_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE source_id_seq OWNED BY source.id;


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE source ALTER COLUMN id SET DEFAULT nextval('source_id_seq'::regclass);


--
-- Name: source_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY source
    ADD CONSTRAINT source_name_key UNIQUE (name);


--
-- Name: source_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY source
    ADD CONSTRAINT source_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO source DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON source FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON source FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON source FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON source FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: source; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE source FROM PUBLIC;
REVOKE ALL ON TABLE source FROM postgres;
GRANT ALL ON TABLE source TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE source TO PUBLIC;


--
-- Name: source_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE source_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE source_id_seq FROM postgres;
GRANT ALL ON SEQUENCE source_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE source_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

