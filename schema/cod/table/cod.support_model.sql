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
-- Name: support_model; Type: TABLE; Schema: cod; Owner: postgres; Tablespace: 
--

CREATE TABLE support_model (
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT standard.get_uwnetid() NOT NULL,
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL,
    reject boolean DEFAULT false NOT NULL,
    help_text boolean DEFAULT false NOT NULL,
    active_notification boolean DEFAULT false NOT NULL,
    nag boolean DEFAULT false NOT NULL,
    nag_owned_period text DEFAULT '24 hours BHO'::text
);


ALTER TABLE cod.support_model OWNER TO postgres;

--
-- Name: TABLE support_model; Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON TABLE support_model IS 'DR: Support Model -- determines workflow (2012-02-28)';


--
-- Name: support_model_id_seq; Type: SEQUENCE; Schema: cod; Owner: postgres
--

CREATE SEQUENCE support_model_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cod.support_model_id_seq OWNER TO postgres;

--
-- Name: support_model_id_seq; Type: SEQUENCE OWNED BY; Schema: cod; Owner: postgres
--

ALTER SEQUENCE support_model_id_seq OWNED BY support_model.id;


--
-- Name: support_model_id_seq; Type: SEQUENCE SET; Schema: cod; Owner: postgres
--

SELECT pg_catalog.setval('support_model_id_seq', 5, true);


--
-- Name: id; Type: DEFAULT; Schema: cod; Owner: postgres
--

ALTER TABLE ONLY support_model ALTER COLUMN id SET DEFAULT nextval('support_model_id_seq'::regclass);


--
-- Data for Name: support_model; Type: TABLE DATA; Schema: cod; Owner: postgres
--

INSERT INTO support_model (modified_at, modified_by, id, name, description, sort, disabled, reject, help_text, active_notification, nag, nag_owned_period) VALUES ('2012-05-10 10:03:42.818374-07', 'postgres', 2, 'A', 'Immediate escalation with active notification', 10, false, false, false, true, true, '00:30:00');
INSERT INTO support_model (modified_at, modified_by, id, name, description, sort, disabled, reject, help_text, active_notification, nag, nag_owned_period) VALUES ('2012-05-10 10:03:42.818374-07', 'postgres', 3, 'B', 'L1 works help text then escalation with active notification', 20, false, false, true, true, true, '00:30:00');
INSERT INTO support_model (modified_at, modified_by, id, name, description, sort, disabled, reject, help_text, active_notification, nag, nag_owned_period) VALUES ('2012-05-10 10:03:42.818374-07', 'postgres', 1, '', 'No Model', 99, false, false, false, false, true, '24 hours BHO');
INSERT INTO support_model (modified_at, modified_by, id, name, description, sort, disabled, reject, help_text, active_notification, nag, nag_owned_period) VALUES ('2012-05-10 10:03:42.818374-07', 'postgres', 4, 'C', 'L1 works help text then escalation with passive notification', 30, false, false, true, false, true, '24 hours BHO');
INSERT INTO support_model (modified_at, modified_by, id, name, description, sort, disabled, reject, help_text, active_notification, nag, nag_owned_period) VALUES ('2012-05-10 10:03:42.818374-07', 'postgres', 5, 'D', 'No support', 40, false, true, false, false, true, '24 hours BHO');


--
-- Name: support_model_name_key; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY support_model
    ADD CONSTRAINT support_model_name_key UNIQUE (name);


--
-- Name: support_model_pkey; Type: CONSTRAINT; Schema: cod; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY support_model
    ADD CONSTRAINT support_model_pkey PRIMARY KEY (id);


--
-- Name: forbid_delete; Type: RULE; Schema: cod; Owner: postgres
--

CREATE RULE forbid_delete AS ON DELETE TO support_model DO INSTEAD NOTHING;


--
-- Name: t_10_anchored_id; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_10_anchored_id BEFORE UPDATE ON support_model FOR EACH ROW EXECUTE PROCEDURE standard.anchored_id();


--
-- Name: t_30_distinct_update; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_30_distinct_update BEFORE UPDATE ON support_model FOR EACH ROW EXECUTE PROCEDURE standard.distinct_update_nm();


--
-- Name: t_50_modified; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_50_modified BEFORE INSERT OR UPDATE ON support_model FOR EACH ROW EXECUTE PROCEDURE standard.modified();


--
-- Name: t_90_saver; Type: TRIGGER; Schema: cod; Owner: postgres
--

CREATE TRIGGER t_90_saver AFTER INSERT OR DELETE OR UPDATE ON support_model FOR EACH ROW EXECUTE PROCEDURE standard.history_trigger();


--
-- Name: support_model; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON TABLE support_model FROM PUBLIC;
REVOKE ALL ON TABLE support_model FROM postgres;
GRANT ALL ON TABLE support_model TO postgres;
GRANT SELECT,INSERT,UPDATE ON TABLE support_model TO PUBLIC;


--
-- Name: support_model_id_seq; Type: ACL; Schema: cod; Owner: postgres
--

REVOKE ALL ON SEQUENCE support_model_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE support_model_id_seq FROM postgres;
GRANT ALL ON SEQUENCE support_model_id_seq TO postgres;
GRANT SELECT,USAGE ON SEQUENCE support_model_id_seq TO PUBLIC;


--
-- PostgreSQL database dump complete
--

