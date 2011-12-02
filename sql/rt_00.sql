 --SELECT standard.create_data_schema('rt', 'RT related data');

/**********************************************************************************************

CREATE TABLE rt.buffer (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    ticket          integer,
    fields          varchar[][],
    callback        xml,
    lock            bigint
);

COMMENT ON TABLE rt.buffer IS 'DR: Data to publish to RT (2011-10-10)';

GRANT SELECT, INSERT ON TABLE rt.buffer TO PUBLIC;

SELECT standard.standardize_table_and_trigger('rt', 'buffer');

**********************************************************************************************/

CREATE OR REPLACE FUNCTION rt.offline_submit(payload varchar) RETURNS varchar
    LANGUAGE plpython2u
    VOLATILE
    SECURITY INVOKER
    AS $_$
"""
    Function:     rt.offline_submit(payload varchar)
    Description:  Submit the provided payload to the RT Offline Tool
    Affects:      Creates/Updates an RT ticket
    Arguments:    varchar: formatted paylod for the offline update tool
    Returns:      varchar: output from the offline tool.
"""
import httplib, urllib
params = urllib.urlencode({"string":payload,"nodecoration":1,"resultsonly":1,"UpdateTickets":"Upload"})
headers = {"Content-type": "application/x-www-form-urlencoded", "Accept": "text/plain"}
conn = httplib.HTTPSConnection("rti.cac.washington.edu")
conn.request("POST", "/Tools/Offline.html", params, headers)
response = conn.getresponse()
body = response.read()
conn.close()
if response.status == 200:
    return body

return response.reason
$_$;

COMMENT ON FUNCTION rt.offline_submit(payload varchar) IS 'DR: Submit the provided payload to the RT Offline Tool (2011-10-20)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION rt.create_ticket(varchar) RETURNS integer
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     rt.create_ticket(varchar)
    Description:  Create an RT ticket with the provided payload
    Affects:      Creates an RT Ticket
    Arguments:    varchar: payload for the offline tool
    Returns:      integer: number of the ticket created
*/
DECLARE
    v_payload    ALIAS FOR $1;
    _payload     varchar;
BEGIN
    SET LOCAL statement_timeout TO 180000; -- 3 minutes
    _payload := E'===Create-Ticket: ssgrt\n' || v_payload;
    RETURN (regexp_matches(rt.offline_submit(_payload), E'create-ssgrt: ticket (\\d+) created', 'i'))[1]::integer;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$_$;

COMMENT ON FUNCTION rt.create_ticket(varchar) IS 'DR: Create an RT ticket with the provided payload (2011-10-20)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION rt.update_ticket(integer, varchar) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     rt.update_ticket(integer, varchar)
    Description:  Update an RT ticket with the provided payload
    Affects:      Updates an RT ticket
    Arguments:    integer: number of the ticket to update
                  varchar: formmatted paylod for the offline tool
    Returns:      boolean: true on success, else false
*/
DECLARE
    v_ticket    ALIAS FOR $1;
    v_payload   ALIAS FOR $2;
    _payload    varchar;
    _output     varchar;
BEGIN
    SET LOCAL statement_timeout TO 180000; -- 3 minutes
    _payload := E'===Update-Ticket: ' || v_ticket::varchar || E'\n' || v_paylod;
    _output  := rt.offline_submit(_payload);
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;

COMMENT ON FUNCTION rt.update_ticket(integer, varchar) IS 'DR: Update an RT ticket with the provided payload (2011-10-20)';
