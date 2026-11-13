
import sqlite3

from fastapi import APIRouter, Depends, HTTPException

from app.database import get_db
from app.models import Token, UserCreate, UserLogin, UserOut
from app.security import create_access_token, get_current_user, hash_password, verify_password

# Un "router" regroupe plusieurs routes liées (ici : l'authentification)
router = APIRouter(tags=["Authentification"])


@router.post("/register", response_model=UserOut, status_code=201)
def register(data: UserCreate, db: sqlite3.Connection = Depends(get_db)):
    """Crée un compte."""
    email = data.email.lower()   # on met l'email en minuscules pour éviter les doublons
    try:
        cur = db.execute(
            "INSERT INTO users (email, password_hash) VALUES (?, ?)",
            (email, hash_password(data.password)),   # on enregistre l'empreinte, pas le mot de passe
        )
        db.commit()
    except sqlite3.IntegrityError:
        # L'email existe déjà (la colonne email est UNIQUE)
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    return {"id": cur.lastrowid, "email": email}   # lastrowid = l'id du nouvel utilisateur


@router.post("/login", response_model=Token)
def login(data: UserLogin, db: sqlite3.Connection = Depends(get_db)):
    """Vérifie l'email et le mot de passe, puis renvoie un jeton."""
    user = db.execute(
        "SELECT id, password_hash FROM users WHERE email = ?", (data.email.lower(),)
    ).fetchone()
    # Même message dans les deux cas : on ne révèle pas si l'email existe
    if user is None or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")
    return Token(access_token=create_access_token(user["id"]))


@router.get("/me", response_model=UserOut)
def me(user: sqlite3.Row = Depends(get_current_user)):
    """Renvoie le profil de l'utilisateur connecté (sert à tester le jeton)."""
    return dict(user)