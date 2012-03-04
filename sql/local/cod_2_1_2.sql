DROP TRIGGER IF EXISTS t_70_update_rt ON cod.item;

CREATE TRIGGER t_70_update_rt BEFORE UPDATE ON cod.item FOR EACH ROW WHEN ((new.workflow_lock IS FALSE AND new.rt_ticket IS NOT NULL)) EXECUTE PROCEDURE cod.item_rt_update();

