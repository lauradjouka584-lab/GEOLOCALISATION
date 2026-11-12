# Charge l'outil qui crée le serveur
from fastapi import FastAPI

# Crée le serveur et lui donne un nom
app = FastAPI(title="GeoTrack API")

# Quand on ouvre l'adresse /health, la fonction ci-dessous s'exécute
@app.get("/health")
def health():
    # Réponse en JSON : prouve que le serveur fonctionne
    return {"status": "ok"}