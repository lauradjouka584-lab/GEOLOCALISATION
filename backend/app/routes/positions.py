# Routes des positions GPS : enregistrer, lire, supprimer

import sqlite3
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import get_db
from app.models import PositionCreate, PositionOut
from app.security import get_current_user

# Toutes les routes de ce fichier commencent par /positions
router = APIRouter(prefix="/positions", tags=["Positions"])

# Les colonnes qu'on lit dans la base
COLUMNS = ("id, client_uuid, latitude, longitude, accuracy, speed, "
           "altitude, heading, recorded_at, created_at")


def save_position(db: sqlite3.Connection, user_id: int, p: PositionCreate) -> sqlite3.Row:
    """Enregistre une position. Si le client_uuid existe déjà, on ne crée pas de doublon."""
    # INSERT OR IGNORE = "ajoute, sauf si cette position existe déjà"
    db.execute(
        "INSERT OR IGNORE INTO positions "
        "(user_id, client_uuid, latitude, longitude, accuracy, speed, altitude, heading, recorded_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (user_id, p.client_uuid, p.latitude, p.longitude, p.accuracy,
         p.speed, p.altitude, p.heading, p.recorded_at.isoformat()),
    )
    # On relit la position pour la renvoyer (avec son id)
    return db.execute(
        f"SELECT {COLUMNS} FROM positions WHERE user_id = ? AND client_uuid = ?",
        (user_id, p.client_uuid),
    ).fetchone()


@router.post("", response_model=PositionOut, status_code=201)
def add_position(p: PositionCreate, db: sqlite3.Connection = Depends(get_db),
                 user: sqlite3.Row = Depends(get_current_user)):
    """Enregistre une position GPS."""
    row = save_position(db, user["id"], p)
    db.commit()
    return dict(row)


@router.post("/batch", response_model=list[PositionOut], status_code=201)
def add_positions(items: list[PositionCreate], db: sqlite3.Connection = Depends(get_db),
                  user: sqlite3.Row = Depends(get_current_user)):
    """Enregistre plusieurs positions d'un coup (utile après un passage hors ligne)."""
    if len(items) > 500:
        raise HTTPException(status_code=422, detail="Maximum 500 positions par envoi")
    rows = [dict(save_position(db, user["id"], p)) for p in items]
    db.commit()
    return rows


@router.get("", response_model=list[PositionOut])
def list_positions(
    date_from: datetime | None = Query(default=None, alias="from"),   # filtre : à partir de cette date
    date_to: datetime | None = Query(default=None, alias="to"),       # filtre : jusqu'à cette date
    limit: int = Query(default=100, ge=1, le=1000),                  # nombre maximum de résultats
    db: sqlite3.Connection = Depends(get_db),
    user: sqlite3.Row = Depends(get_current_user),
):
    """Liste les positions de l'utilisateur, de la plus récente à la plus ancienne."""
    sql = f"SELECT {COLUMNS} FROM positions WHERE user_id = ?"
    params: list = [user["id"]]
    if date_from:
        sql += " AND recorded_at >= ?"
        params.append(date_from.isoformat())
    if date_to:
        sql += " AND recorded_at <= ?"
        params.append(date_to.isoformat())
    sql += " ORDER BY recorded_at DESC LIMIT ?"
    params.append(limit)
    return [dict(r) for r in db.execute(sql, params).fetchall()]


@router.delete("/{position_id}", status_code=204)
def delete_position(position_id: int, db: sqlite3.Connection = Depends(get_db),
                    user: sqlite3.Row = Depends(get_current_user)):
    """Supprime UNE position (seulement si elle appartient à l'utilisateur)."""
    cur = db.execute("DELETE FROM positions WHERE id = ? AND user_id = ?", (position_id, user["id"]))
    db.commit()
    if cur.rowcount == 0:   # rien n'a été supprimé : id inconnu ou position d'un autre
        raise HTTPException(status_code=404, detail="Position introuvable")


@router.delete("", status_code=204)
def delete_all_positions(db: sqlite3.Connection = Depends(get_db),
                         user: sqlite3.Row = Depends(get_current_user)):
    """Supprime TOUT l'historique de l'utilisateur."""
    db.execute("DELETE FROM positions WHERE user_id = ?", (user["id"],))
    db.commit()