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
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE state ALTER COLUMN id SET DEFAULT nextval('state_id_seq'::regclass);


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

