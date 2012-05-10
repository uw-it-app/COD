--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: cod; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA cod;


ALTER SCHEMA cod OWNER TO postgres;

--
-- Name: cod; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA cod FROM PUBLIC;
REVOKE ALL ON SCHEMA cod FROM postgres;
GRANT ALL ON SCHEMA cod TO postgres;
GRANT ALL ON SCHEMA cod TO PUBLIC;


--
-- PostgreSQL database dump complete
--

