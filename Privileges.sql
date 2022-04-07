BEGIN;

    CREATE SCHEMA IF NOT EXISTS debt_register AUTHORIZATION CURRENT_USER;

    CREATE ROLE debt_register_admin
    WITH NOLOGIN BYPASSRLS;

    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA debt_register TO debt_register_admin;

    CREATE ROLE debt_register_user
    WITH NOLOGIN NOBYPASSRLS;

    REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA debt_register FROM debt_register_user;

    CREATE OR REPLACE FUNCTION register_user(username name, userpassword text)
    RETURNS void AS $$
    BEGIN
        IF username IN (SELECT name FROM users) THEN
            RAISE EXCEPTION 'This user aleady exits in the users table: %', username;
        END IF;

        IF username NOT IN (SELECT rolname FROM pg_authid) THEN
            EXECUTE FORMAT('CREATE USER %I PASSWORD %L', username, userpassword);
        ELSIF username IN (SELECT a.rolname FROM pg_authid AS a RIGHT JOIN pg_auth_members AS m ON m.roleid = a.oid) THEN
            RAISE EXCEPTION 'This user has members (which is forbidden): %', username;
        END IF;
        EXECUTE FORMAT('GRANT debt_register_user TO %I', username);
        EXECUTE FORMAT('INSERT INTO users (name) VALUES (%L)', username);
    END;
    $$ LANGUAGE PLPGSQL
    SECURITY INVOKER;

COMMIT;