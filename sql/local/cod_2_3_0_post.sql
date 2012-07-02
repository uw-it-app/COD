CREATE TRIGGER t_93_dash_on_insert
    AFTER INSERT ON cod.escalation
    FOR EACH ROW
    EXECUTE PROCEDURE cod.escalation_dash_update();

CREATE TRIGGER t_93_dash_on_update
    AFTER UPDATE ON cod.escalation
    FOR EACH ROW WHEN (OLD.owner <> NEW.owner)
    EXECUTE PROCEDURE cod.escalation_dash_update();


CREATE TRIGGER t_95_notify_peers
    AFTER INSERT ON cod.escalation
    FOR EACH ROW
    EXECUTE PROCEDURE cod.escalation_notify_peers();
