BEGIN;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION cod_v2.enumerations() RETURNS xml
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     cod_v2.enumerations()
    Description:  Return lists of enumeration data for selects
    Affects:      nothing
    Arguments:    none
    Returns:      xml
*/
SELECT xmlelement(name "Enumerations"
    , rest_v1.enum_to_xml('cod', 'support_model', 'SupportModels', 'SupportModel', false)
    , rest_v1.enum_to_xml('cod', 'itil_type', 'ITILTypes', 'ITILType', false)
    , xmlelement(name "Severities"
        , xmlelement(name "Severity", 1)
        , xmlelement(name "Severity", 2)
        , xmlelement(name "Severity", 3)
        , xmlelement(name "Severity", 4)
        , xmlelement(name "Severity", 5)
    )
);
$_$;

COMMENT ON FUNCTION cod_v2.enumerations() IS 'DR: Return lists of enumeration data for selects (2012-02-25)';

COMMIT;
