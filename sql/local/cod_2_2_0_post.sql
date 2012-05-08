
-- update cod.item to set nat_inteval to null where default and not closed
UPDATE cod.item SET nag_interval = NULL WHERE nag_interval = ('00:30:00'::interval)::varchar AND status_id IN (SELECT id FROM cod.state WHERE name NOT IN ('Closed', 'Merged'));

