
from datetime import datetime   # pour le type "date et heure"

from pydantic import BaseModel, EmailStr, Field, field_validator
# Field           : ajoute des règles (longueur min/max, valeur min/max)
# field_validator : permet d'écrire sa propre règle



class UserCreate(BaseModel):
    """Ce qu'on reçoit quand quelqu'un crée un compte (/register)."""
    email: EmailStr                                   # doit être un vrai email
    password: str = Field(min_length=8, max_length=64)  # entre 8 et 64 caractères

    # Ma règle sur le mot de passe
    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        # v = le mot de passe reçu.
        # any(...) = "au moins un caractère qui est une lettre / un chiffre"
        if not any(c.isalpha() for c in v) or not any(c.isdigit() for c in v):
            raise ValueError("Le mot de passe doit contenir au moins une lettre et un chiffre")
        return v   # si tout est bon, on renvoie le mot de passe


class UserLogin(BaseModel):
    """Ce qu'on reçoit quand quelqu'un se connecte (/login)."""
    email: EmailStr
    password: str


class UserOut(BaseModel):
    """Ce qu'on renvoie à l'application sur un utilisateur."""
    id: int
    email: EmailStr


class Token(BaseModel):
    """La réponse de /login : le jeton de connexion."""
    access_token: str
    token_type: str = "bearer"   # valeur par défaut : "bearer"



class PositionCreate(BaseModel):
    """Une position GPS envoyée par le téléphone."""
    client_uuid: str = Field(min_length=8, max_length=64)  # identifiant unique créé par le téléphone
    latitude: float = Field(ge=-90, le=90)       # ge = "supérieur ou égal", le = "inférieur ou égal"
    longitude: float = Field(ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)   # précision en mètres 
    speed: float | None = Field(default=None, ge=0)      # vitesse 
    altitude: float | None = None                        # altitude
    heading: float | None = Field(default=None, ge=0, le=360)  # cap en degrés 
    recorded_at: datetime                       


class PositionOut(PositionCreate):
    """Une position renvoyée par le serveur : mêmes champs + id et date d'enregistrement."""
    id: int
    created_at: str