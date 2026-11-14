# Point de départ du serveur
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_db
from app.routes import auth, positions


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()   # au démarrage : crée les tables si elles n'existent pas
    yield


app = FastAPI(title="GeoTrack API", lifespan=lifespan)

# CORS : autorise Chrome (page locale) à appeler l'API pendant le développement
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",   # seulement localhost
    allow_methods=["*"],
    allow_headers=["*"],
)

# Branche les routes
app.include_router(auth.router)
app.include_router(positions.router)


# Route de test : prouve que le serveur fonctionne
@app.get("/health", tags=["Système"])
def health():
    return {"status": "ok"}