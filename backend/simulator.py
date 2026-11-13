# ============================================================
# simulator.py : un FAUX TÉLÉPHONE
# Il envoie de fausses positions GPS à l'API pour la tester,
# Lancer :  python simulator.py
# ============================================================

import json                 
import sys                  # pour lire ce qu'on tape après "python simulator.py" (ex : --clean)
import uuid                 
import urllib.error         # pour attraper les erreurs de l'API (400, 401, 422...)
import urllib.request       # pour envoyer des requêtes à l'API (comme un navigateur)
from datetime import datetime, timedelta, timezone   # pour manipuler les dates et heures

# -
BASE_URL = "http://127.0.0.1:8000"   # l'adresse de l'API du serveur
EMAIL = "simulateur@test.com"        # le compte du faux téléphone 
PASSWORD = "Test1234"               

#  call() = envoyer une demande à l'API
def call(method, path, body=None, token=None):
    # Si on a des données à envoyer, on les transforme en texte JSON, sinon on n'envoie rien
    data = json.dumps(body).encode("utf-8") if body is not None else None

    # On prépare la demande : adresse complète + type (GET, POST...) + données
    req = urllib.request.Request(BASE_URL + path, data=data, method=method)

    # On dit à l'API que nos données sont en JSON
    req.add_header("Content-Type", "application/json")

    # Si on a un jeton, on le montre à l'API
    if token:
        req.add_header("Authorization", "Bearer " + token)

    try:
        # Envoie la demande
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")    # le texte de la réponse
            # On renvoie : le code (200, 201...) et la réponse transformée en données Python
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        # L'API a répondu par une ERREUR (400, 401, 422...), pas un plantage :
        # on récupère le code d'erreur pour pouvoir le vérifier dans les tests.
        raw = e.read().decode("utf-8")
        return e.code, (json.loads(raw) if raw else None)


#  make_trajet() = fabriquer de fausses positions
def make_trajet(n=20):                       
    now = datetime.now(timezone.utc)        
    points = []                              # la liste des positions (vide au départ)

    for i in range(n):                       
        points.append({
            # Identifiant unique : permet à l'API de reconnaître une position déjà reçue
            "client_uuid": str(uuid.uuid4()),

            # À chaque tour, on avance un tout petit peu 
            "latitude": round(4.0511 + i * 0.0004, 6),
            "longitude": round(9.7679 + i * 0.0004, 6),

            "accuracy": 8.0,        # précision du GPS : 8 mètres
            "speed": 3.5,           
            "altitude": 20.0,      
            "heading": 45.0,       

            # Heure de la mesure : une position toutes les 30 secondes, dans le passé
            "recorded_at": (now - timedelta(seconds=30 * (n - i))).strftime("%Y-%m-%dT%H:%M:%SZ"),
        })
    return points                          


# check() = afficher OK ou ECHEC pour un test
def check(label, ok):
    print(("  OK    " if ok else "  ECHEC ") + label)
    return ok       # on renvoie True/False pour compter les tests réussis à la fin


def main():
    results = []    

    # Créer un compte et se connecter -----
    print("1) Compte et connexion")
    # On crée le compte. Si il existe déjà, l'API répond 400 : c'est normal, on ignore.
    call("POST", "/register", {"email": EMAIL, "password": PASSWORD})
    # On se connecte pour obtenir le jeton (le badge)
    code, data = call("POST", "/login", {"email": EMAIL, "password": PASSWORD})
    results.append(check("connexion (200)", code == 200))
    token = data["access_token"]     # on garde le jeton pour les demandes suivantes

    # On compte combien de positions existent déjà (pour vérifier les doublons plus bas)
    avant = len(call("GET", "/positions?limit=1000", token=token)[1])

    # Envoyer 20 positions d'un coup 
    print("2) Envoi de 20 positions")
    points = make_trajet(20)                                  # on fabrique les 20 positions
    code, data = call("POST", "/positions/batch", points, token)   # on les envoie
    results.append(check("envoi groupé (201, 20 positions)", code == 201 and len(data) == 20))

    # Renvoyer les mêmes positions (test des doublons) 
    print("3) Doublons : on renvoie les mêmes positions")
    code, data = call("POST", "/positions/batch", points, token)   # exactement les mêmes
    results.append(check("renvoi accepté (201)", code == 201))
    # On relit tout : il doit y avoir 20 positions de plus qu'avant, pas 40
    code, data = call("GET", "/positions?limit=1000", token=token)
    results.append(check("20 positions ajoutées, pas 40 (pas de doublon)", code == 200 and len(data) == avant + 20))

    #Ordre de lecture 
    print("4) Lecture")
    # La première position de la liste doit être la plus récente
    results.append(check("la plus récente est en premier", data[0]["recorded_at"] > data[-1]["recorded_at"]))

    # Sécurité
    print("5) Sécurité")
    # On demande les positions SANS jeton : l'API doit refuser (401)
    code, _ = call("GET", "/positions")
    results.append(check("sans jeton : refusé (401)", code == 401))
    # On envoie une fausse position avec une latitude de 200 (impossible) : l'API doit refuser (422)
    bad = dict(points[0], client_uuid=str(uuid.uuid4()), latitude=200)
    code, _ = call("POST", "/positions", bad, token)
    results.append(check("latitude 200 : refusée (422)", code == 422))

    if "--clean" in sys.argv:
        code, _ = call("DELETE", "/positions", token=token)
        results.append(check("historique effacé (204)", code == 204))

    print(f"\nRésultat : {sum(results)}/{len(results)} tests réussis")


if __name__ == "__main__":
    main()