
-- Active la vérification des liens entre tables (clés étrangères).
-- Sans cette ligne, SQLite ignorerait les règles FOREIGN KEY.
PRAGMA foreign_keys = ON;


--  users 
CREATE TABLE IF NOT EXISTS users (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    email          TEXT    NOT NULL UNIQUE,
    password_hash  TEXT    NOT NULL,
    created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);


--positions (chaque point GPS enregistré)
CREATE TABLE IF NOT EXISTS positions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id      INTEGER NOT NULL,
    -- Identifiant créé par l'application, évite d'enregistrer deux fois la même position si le réseau est instable
    client_uuid  TEXT    NOT NULL,
    latitude     REAL    NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
    longitude    REAL    NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    accuracy     REAL    CHECK (accuracy >= 0),
    speed        REAL    CHECK (speed    >= 0),
    altitude     REAL,
    recorded_at  TEXT    NOT NULL,
    created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

    -- Un même utilisateur ne peut pas avoir deux fois le même client_uuid
    UNIQUE (user_id, client_uuid)
);

-- Index : comme l'index d'un livre, il rend la lecture de l'historique
CREATE INDEX IF NOT EXISTS idx_positions_user_time ON positions(user_id, recorded_at DESC);


--  favorites 
CREATE TABLE IF NOT EXISTS favorites (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     INTEGER NOT NULL,
    name        TEXT    NOT NULL,
    latitude    REAL    NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
    longitude   REAL    NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Index pour retrouver rapidement les favoris d'un utilisateur
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);