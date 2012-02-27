BEGIN;

SELECT standard.create_data_schema('appconfig', 'Configuration settings for applications');

ALTER DEFAULT PRIVILEGES IN SCHEMA cod GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA cod_history GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC;

/**********************************************************************************************/

CREATE TABLE appconfig.setting (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    key             varchar     NOT NULL UNIQUE,
    data            varchar     NOT NULL
);

COMMENT ON TABLE appconfig.setting IS 'DR: Environmental settings for applications (2012-02-25)';

GRANT SELECT, INSERT, UPDATE ON TABLE appconfig.setting TO PUBLIC;

SELECT standard.standardize_table_history_and_trigger('appconfig', 'setting');

CREATE RULE forbid_delete AS ON DELETE TO appconfig.setting DO INSTEAD NOTHING;

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION appconfig.get(varchar) RETURNS varchar
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     appconfig.get(varchar)
    Description:  Retrieve application setting
    Affects:      nothing
    Arguments:    varchar: setting key to find value for
    Returns:      varchar
*/
SELECT data FROM appconfig.setting WHERE key = $1;
$_$;

COMMENT ON FUNCTION appconfig.get(varchar) IS 'DR: Retrieve application setting (2012-02-25)';

/**********************************************************************************************/

CREATE OR REPLACE FUNCTION appconfig.get(varchar, varchar) RETURNS varchar
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    AS $_$
/*  Function:     appconfig.get(varchar)
    Description:  Retrieve application setting, or default
    Affects:      nothing
    Arguments:    varchar: setting key to find value for
                  varchar: default value to return if no matching value
    Returns:      varchar
*/
DECLARE
    v_key       ALIAS FOR $1;
    v_default   ALIAS FOR $2;
    _data       varchar;
BEGIN
    _data := (SELECT data FROM appconfig.setting WHERE key = v_key);
    IF _data IS NOT NULL THEN
        RETURN _data;
    END IF;
    RETURN v_default;
END;
$_$;

COMMENT ON FUNCTION appconfig.get(varchar, varchar) IS 'DR: Retrieve application setting, or default (2012-02-25)';

COMMIT;
