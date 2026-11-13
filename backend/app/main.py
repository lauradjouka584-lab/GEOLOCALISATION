

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import init_db
from app.routes import auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()   # au démarrage du serveur : crée les tables si elles n'existent pas
    yield


app = FastAPI(title="GeoTrack API", lifespan=lifespan)
# Branche les routes d'authentification sur le serveur
app.include_router(auth.router)


# Route de test : prouve que le serveur fonctionne
@app.get("/health", tags=["Système"])
def health():
    return {"status": "ok"}