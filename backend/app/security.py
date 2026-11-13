
import os
import sqlite3
from datetime import datetime, timedelta, timezone

import bcrypt                                    # transforme un mot de passe en empreinte illisible
from fastapi import Depends, HTTPException       # Depends = "j'ai besoin de ça" ; HTTPException = renvoyer une erreur
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt                   # jwt = fabriquer et lire les jetons

from app.database import get_db

# Clé secrète qui "signe" les jetons : sans elle, impossible de fabriquer un faux jeton
SECRET_KEY = os.getenv("GEOTRACK_SECRET_KEY", "cle-de-developpement-a-changer")
ALGORITHM = "HS256"        # méthode de signature
TOKEN_EXPIRE_HOURS = 24    

# Lit l'en-tête "Authorization: Bearer <jeton>" envoyé par l'application
bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    """Transforme le mot de passe en empreinte illisible."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    """Compare un mot de passe saisi avec l'empreinte enregistrée."""
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def create_access_token(user_id: int) -> str:
    """Fabrique un jeton contenant l'id de l'utilisateur et une date d'expiration."""
    expire = datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRE_HOURS)
    payload = {"sub": str(user_id), "exp": expire}   # sub = qui, exp = jusqu'à quand
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: sqlite3.Connection = Depends(get_db),
) -> sqlite3.Row:
    """Vérifie le jeton reçu et renvoie l'utilisateur connecté (sinon erreur 401)."""
    error = HTTPException(status_code=401, detail="Non authentifié ou jeton expiré")

    # Pas de jeton envoyé : refus
    if credentials is None:
        raise error
    try:
        # Lit le jeton : vérifie la signature et la date d'expiration
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise error   # jeton faux, modifié ou expiré

    # Vérifie que l'utilisateur existe toujours dans la base
    user = db.execute("SELECT id, email FROM users WHERE id = ?", (user_id,)).fetchone()
    if user is None:
        raise error
    return user