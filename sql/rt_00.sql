SELECT standard.create_data_schema('rt', 'RT related data');

/**********************************************************************************************/

CREATE TABLE rt.buffer (
    modified_at     timestamptz NOT NULL DEFAULT now(),
    modified_by     varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    id              serial      PRIMARY KEY,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      varchar     NOT NULL DEFAULT standard.get_uwnetid(),
    ticket          integer,
    fields          varchar[][],
    callback        varchar,
    lock            bigint
);

COMMENT ON TABLE rt.buffer IS 'DR: Data to publish to RT (2011-10-10)';

GRANT SELECT, INSERT ON TABLE rt.buffer TO PUBLIC;

SELECT standard.standardize_table_and_trigger('rt', 'buffer');

