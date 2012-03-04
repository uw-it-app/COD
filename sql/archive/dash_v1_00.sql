BEGIN;

CREATE SCHEMA dash_v1;
GRANT ALL ON SCHEMA dash_v1 TO PUBLIC;

COMMENT ON SCHEMA dash_v1 IS 'DR: Dash interaction functions v1 (2012-02-24)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION dash_v1.prox(payload varchar) RETURNS boolean
    LANGUAGE plpython2u
    VOLATILE
    SECURITY INVOKER
    AS $_$
"""
    Function:     dash_v1.prox(payload varchar)
    Description:  Send data to prox
    Affects:      nothing
    Arguments:    data to send to prox
    Returns:      boolean
"""
import socket
s = socket.socket()
s.connect((plpy.execute("SELECT appconfig.get('PROXD_HOST')")[0]["get"], int(plpy.execute("SELECT appconfig.get('PROXD_PORT')")[0]["get"])))
s.send(payload)
data = s.recv(4096)
s.close()
return True
$_$;

COMMENT ON FUNCTION dash_v1.prox(payload varchar) IS 'DR: Send data to prox (2012-02-24)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION dash_v1.prox_del(varchar, varchar) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     dash_v1.prox_del(varchar, varchar)
    Description:  Delete event from prox by host, component
    Affects:      nothing
    Arguments:    varchar: hostname
                  varchar: component
    Returns:      boolean
*/
DECLARE
    v_host      ALIAS FOR $1;
    v_comp      ALIAS FOR $2;
BEGIN
    SET LOCAL statement_timeout TO 60000; -- 1 minute
    RETURN dash_v1.prox(
        xmlelement(name "transactionlist",
            xmlelement(name "transaction",
                xmlelement(name "delAlert",
                    xmlattributes(
                        v_host as "host",
                        v_comp as "component"
                    )
                )
            )
        )::varchar
    );
EXCEPTION
    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;

COMMENT ON FUNCTION dash_v1.prox_del(varchar, varchar) IS 'DR: Delete event from prox by host, component (2012-02-24)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION dash_v1.injector(payload varchar) RETURNS boolean
    LANGUAGE plpython2u
    VOLATILE
    SECURITY INVOKER
    AS $_$
"""
  Function:     dash_v1.injector(payload varchar)
    Description:  Send data to injector
    Affects:      nothing
    Arguments:    varchar: data to send to injector
    Returns:      boolean
"""
import socket
s = socket.socket()
s.connect((plpy.execute("SELECT appconfig.get('INJECTOR_HOST')")[0]["get"], int(plpy.execute("SELECT appconfig.get('INJECTOR_PORT')")[0]["get"])))
s.send(payload)
data = s.recv(4096)
s.close()
return True
$_$;

COMMENT ON FUNCTION dash_v1.injector(payload varchar) IS 'DR: Send data to injector (2012-02-24)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION dash_v1.injector_del(varchar, varchar) RETURNS boolean
    LANGUAGE plpgsql
    VOLATILE
    SECURITY INVOKER
    AS $_$
/*  Function:     dash_v1.injector_del(varchar, varchar)
    Description:  Delete event via injector by host, component
    Affects:      
    Arguments:    
    Returns:      boolean
*/
DECLARE
    v_host      ALIAS FOR $1;
    v_comp      ALIAS FOR $2;
BEGIN
    SET LOCAL statement_timeout TO 60000; -- 1 minute
    RETURN dash_v1.injector(
        xmlelement(name "Alert",
            xmlelement(name "Action", 'Del'),
            xmlelement(name "ProblemHost", v_host),
            xmlelement(name "Component", v_comp)
        )::varchar
    );
--EXCEPTION
--    WHEN OTHERS THEN RETURN FALSE;
END;
$_$;

COMMENT ON FUNCTION dash_v1.injector_del(varchar, varchar) IS 'DR: Delete event via injector by host, component (2012-02-24)';


COMMIT;