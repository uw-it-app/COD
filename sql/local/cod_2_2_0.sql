ALTER TABLE cod_history.support_model ADD COLUMN nag_owned_period text DEFAULT '24 hours BHO';
ALTER TABLE cod.support_model ADD COLUMN nag_owned_period text DEFAULT '24 hours BHO';

ALTER TABLE cod_history.item ALTER COLUMN nag_interval DROP NOT NULL;
ALTER TABLE cod_history.item ALTER COLUMN nag_interval DROP DEFAULT;
ALTER TABLE cod.item ALTER COLUMN nag_interval DROP NOT NULL;
ALTER TABLE cod.item ALTER COLUMN nag_interval DROP DEFAULT;


UPDATE cod.support_model SET nag_owned_period = ('00:30:00'::interval)::text WHERE active_notification IS TRUE;
UPDATE cod.support_model SET nag = TRUE;

INSERT INTO appconfig.setting (key, data) VALUES 
    ('COD_DEFAULT_NAG', '24 hours BHO'),
    ('COD_NAG_BUSINESS_START', '09:30:00'),
    ('COD_NAG_BUSINESS_END', '17:00:00');
