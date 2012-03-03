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

--
-- Name: update_item(); Type: FUNCTION; Schema: cod; Owner: postgres
--

CREATE OR REPLACE FUNCTION update_item() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/*  Function:     cod.update_item()
    Description:  Update the item associated with this record
    Affects:      Item associated with this record
    Arguments:    none
    Returns:      trigger
*/
DECLARE
BEGIN
    UPDATE cod.item SET modified_at = now() WHERE id = NEW.item_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION cod.update_item() OWNER TO postgres;

--
-- Name: FUNCTION update_item(); Type: COMMENT; Schema: cod; Owner: postgres
--

COMMENT ON FUNCTION update_item() IS 'DR: Update the item associated with this record (2012-02-26)';


--
-- PostgreSQL database dump complete
--

