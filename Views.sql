BEGIN;

    --- We're materializing a view of simplified debts.
    --- The values displayed are strictly positive and the opposing debt is substracted.
    CREATE MATERIALIZED VIEW IF NOT EXISTS simplified_debts ("From", "To", "Amount", "Last_updated")
    AS
        SELECT
            (SELECT u."name" FROM users u WHERE u.id_user = d1.id_user_from),
            (SELECT u."name" FROM users u WHERE u.id_user = d1.id_user_to),
            d1.amount - d2.amount,
            TO_CHAR(d1.last_update_timestamp, 'dd.mm.yyyy hh:mm')
        FROM debts AS d1 INNER JOIN debts AS d2
            ON d1.id_user_from = d2.id_user_to 
                AND d1.id_user_to = d2.id_user_from 
                AND (d1.amount - d2.amount)::numeric::float8 > 0;

    --- We set the RBAC so that only the admin has the right to access it.
    REVOKE ALL ON TABLE simplified_debts FROM PUBLIC;

    --- And a normal user can do it by a view_summary() function.
    CREATE OR REPLACE FUNCTION view_summary()
    RETURNS TABLE ("From" name, "To" name, "Amount" money, "Last_updated" text) AS $$
    BEGIN
        RETURN QUERY
            SELECT * FROM simplified_debts 
            WHERE CURRENT_USER = 'postgres'
            OR CURRENT_USER = simplified_debts."From"
            OR CURRENT_USER = simplified_debts."To";
    END;
    $$ LANGUAGE PLPGSQL
    SECURITY DEFINER;

    GRANT EXECUTE ON FUNCTION view_summary() TO PUBLIC;

COMMIT;