BEGIN;

    -- We're updating the debt table multiindex key as new users are inserted (starting from 2)
    CREATE OR REPLACE FUNCTION dbts_update_usrs_insert() 
    RETURNS TRIGGER AS $$
    BEGIN
        IF EXISTS (SELECT * FROM users LIMIT 1) THEN
            WITH combinations AS (
                SELECT DISTINCT u1.id_user AS user1, u2.id_user AS user2
                FROM users u1 CROSS JOIN users u2
                WHERE u1.id_user <> u2.id_user
                EXCEPT (SELECT id_user_from, id_user_to FROM debts)
            )
            INSERT INTO debts (id_user_from, id_user_to) SELECT user1, user2 FROM combinations;
        END IF;
    RETURN coalesce(NEW, OLD);
    END;
    $$ LANGUAGE PLPGSQL;

    CREATE OR REPLACE TRIGGER trg_update_usrs_insert 
    AFTER INSERT ON users
    EXECUTE FUNCTION dbts_update_usrs_insert();
    ---

    --- We're defining the timestamp the user commiting each update and insertion
    CREATE OR REPLACE FUNCTION dbts_timestamping()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.last_update_timestamp := CURRENT_TIMESTAMP;
        NEW.last_update_user := CURRENT_USER;
        RETURN NEW;
    END;
    $$ LANGUAGE PLPGSQL;

    CREATE OR REPLACE TRIGGER trg_dtbs_timestamping
    BEFORE UPDATE OR INSERT ON debts
    FOR EACH ROW
    EXECUTE FUNCTION dbts_timestamping();
    ---

    --- We're refreshing the materialized view of simplified_debts with each chagne of debts table
    CREATE OR REPLACE FUNCTION smpl_dbts_refreshing()
    RETURNS TRIGGER AS $$
    BEGIN
        REFRESH MATERIALIZED VIEW simplified_debts;
        RETURN NEW;
    END;
    $$ LANGUAGE PLPGSQL;

    CREATE OR REPLACE TRIGGER trg_smpl_dbts_refreshing
    AFTER UPDATE OR INSERT OR DELETE ON debts
    EXECUTE FUNCTION smpl_dbts_refreshing();
    ---

    --- We're updating the debts table with each new transaction
    CREATE OR REPLACE FUNCTION dbts_update_trns_insert()
    RETURNS TRIGGER AS $$
    BEGIN
        WITH agg AS (
            SELECT id_user_from, id_user_to, sum(amount) total FROM inserted
            GROUP BY id_user_from, id_user_to
        )
        UPDATE debts dbts
        SET amount = amount + agg.total
        FROM agg
        WHERE dbts.id_user_from = agg.id_user_from AND dbts.id_user_to = agg.id_user_to;
    RETURN coalesce(NEW, OLD);
    END;
    $$ LANGUAGE PLPGSQL; 

    CREATE OR REPLACE TRIGGER trg_dbts_update_trns_insert
    AFTER INSERT ON transactions
    REFERENCING NEW TABLE AS inserted
    EXECUTE FUNCTION dbts_update_trns_insert();
    ---

    --- We're rolling back the debt with each deleted transaction
    CREATE OR REPLACE FUNCTION dbts_update_trns_deletion()
    RETURNS TRIGGER AS $$
    BEGIN
        WITH agg AS (
            SELECT id_user_from, id_user_to, sum(amount) total FROM deleted
            GROUP BY id_user_from, id_user_to
        )
        UPDATE debts dbts
        SET amount = amount - agg.total
        FROM agg
        WHERE dbts.id_user_from = agg.id_user_from AND dbts.id_user_to = agg.id_user_to;
    RETURN coalesce(NEW, OLD);
    END;
    $$ LANGUAGE PLPGSQL; 

    CREATE OR REPLACE TRIGGER trg_dbts_update_trns_deletion
    AFTER DELETE ON transactions
    REFERENCING OLD TABLE AS deleted
    EXECUTE FUNCTION dbts_update_trns_deletion();
    ---

    --- We're updating the debt to a new value with each updated transaction
    CREATE OR REPLACE FUNCTION dbts_update_trns_update()
    RETURNS TRIGGER AS $$
    BEGIN
        WITH inserted AS (
            SELECT id_user_from, id_user_to, sum(amount) total FROM newtab
            GROUP BY id_user_from, id_user_to
        ), deleted AS ( 
            SELECT id_user_from, id_user_to, sum(amount) total FROM oldtab
            GROUP BY id_user_from, id_user_to
        ), agg AS (
            SELECT newtab.total - oldtab.total as total
            FROM inserting JOIN deleting USING (id_user_from, id_user_to)
        )
        UPDATE debts dbts
        SET amount = agg.total
        FROM agg
        WHERE dbts.id_user_from = agg.id_user_from AND dbts.id_user_to = agg.id_user_to;
    RETURN coalesce(NEW, OLD);
    END;
    $$ LANGUAGE PLPGSQL; 

    CREATE OR REPLACE TRIGGER trg_dbts_update_trns_update
    AFTER UPDATE ON transactions
    REFERENCING NEW TABLE AS newtab OLD TABLE AS oldtab
    EXECUTE FUNCTION dbts_update_trns_update();
    ---

COMMIT;