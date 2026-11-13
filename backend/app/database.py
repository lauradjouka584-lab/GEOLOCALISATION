
import os                      # pour lire des réglages de l'ordinateur (optionnel)
import sqlite3                 
from pathlib import Path      

# .parent.parent = on monte encore  backend
BASE_DIR = Path(__file__).resolve().parent.parent

# Le cahier s'appelle geotrack.db et sera dans backend
DB_PATH = BASE_DIR / "geotrack.db"

SCHEMA_PATH = BASE_DIR / "schema.sql"


def get_connection():
    # On ouvre le cahier. S'il n'existe pas, SQLite le crée.
    conn = sqlite3.connect(DB_PATH)

    # On pourra lire une info par son nom : ligne["email"]
    # (sinon il faudrait retenir des numéros : ligne[1])
    conn.row_factory = sqlite3.Row

    # (si on supprime un utilisateur, ses positions disparaissent aussi)
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


# 3) PRÉPARER LE CAHIER (créer les tables)
def init_db():
    conn = get_connection()          # on ouvre le cahier
    try:
        conn.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        conn.commit()                # on enregistre pour de bon
    finally:
        conn.close()                 # on referme le cahier, quoi qu'il arrive


def get_db():
    conn = get_connection()          
    try:
        yield conn                   # on le prête à la route qui le demande
    finally:
        conn.close()                 # quand la route a fini, on le referme