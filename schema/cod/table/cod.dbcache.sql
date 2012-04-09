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
-- Name: dbcache; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE dbcache (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    timekey timestamp with time zone NOT NULL,
    content character varying NOT NULL
);


ALTER TABLE cod.dbcache OWNER TO postgres;

--
-- Name: TABLE dbcache; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE dbcache IS 'DR: Cached XML for display (2011-10-10)';


--
-- Name: dbcache_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE dbcache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.dbcache_id_seq OWNER TO postgres;

--
-- Name: dbcache_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE dbcache_id_seq OWNED BY dbcache.id;


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE dbcache ALTER COLUMN id SET DEFAULT nextval('dbcache_id_seq'::regclass);


--
-- Name: dbcache_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dbcache
    ADD CONSTRAINT dbcache_name_key UNIQUE (name);


--
-- Name: dbcache_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dbcache
    ADD CONSTRAINT dbcache_pkey PRIMARY KEY (id);


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON dbcache FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_11_anchored_column; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_11_anchored_column BEFORE UPDATE ON dbcache FOR EACH ROW EXECUTE PROCEDURE standard.anchored_column('name');


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON dbcache FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON dbcache FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: dbcache; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE dbcache FROM PUBLIC;
REVOKE ALL ON TABLE dbcache FROM postgres;
GRANT ALL ON TABLE dbcache TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dbcache TO PUBLIC;


--
-- Name: dbcache_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE dbcache_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE dbcache_id_seq FROM postgres;
GRANT ALL ON SEQUENCE dbcache_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE dbcache_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

