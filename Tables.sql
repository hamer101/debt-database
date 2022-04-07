BEGIN;
    CREATE TABLE IF NOT EXISTS users (
        id_user SERIAL PRIMARY KEY,
        name name NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS transactions (
        id_transaction SERIAL PRIMARY KEY,
        id_user_from int NOT NULL REFERENCES users(id_user),
        id_user_to int NOT NULL REFERENCES users(id_user),
        amount money NOT NULL DEFAULT 0,
        description varchar(512) DEFAULT NULL,
        timestamp timestamp DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT no_self_transaction CHECK (id_user_from <> id_user_to),
        CONSTRAINT only_positive_transaction CHECK (amount::numeric::float8 > 0)
    );

    CREATE TABLE IF NOT EXISTS debts (
        id_user_from int REFERENCES users(id_user),
        id_user_to int REFERENCES users(id_user),
        amount money NOT NULL DEFAULT 0,
        last_update_timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_update_user name NOT NULL DEFAULT CURRENT_USER,
        PRIMARY KEY (id_user_from, id_user_to),
        CONSTRAINT no_self_debt CHECK (id_user_from <> id_user_to),
        CONSTRAINT only_nonnegative_debt CHECK (amount::numeric::float8 >= 0)
    );
COMMIT;