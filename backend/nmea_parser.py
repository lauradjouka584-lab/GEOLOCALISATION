# nmea_parser.py : lit des phrases NMEA 

import sys
import uuid
from datetime import datetime, timezone

PHRASES = [
    "$GPGGA,101500.00,0403.0660,N,00946.0740,E,1,08,0.9,20.0,M,0.0,M,,*65",
    "$GPRMC,101500.00,A,0403.0660,N,00946.0740,E,3.4,45.0,131126,,,A*64",
    "$GPGGA,101530.00,0403.0900,N,00946.0980,E,1,08,0.9,20.5,M,0.0,M,,*68",
    "$GPRMC,101530.00,A,0403.0900,N,00946.0980,E,3.6,46.0,131126,,,A*6D",
    "$GPGGA,101600.00,0403.1140,N,00946.1220,E,1,08,0.9,21.0,M,0.0,M,,*61",
    "$GPRMC,101600.00,A,0403.1140,N,00946.1220,E,3.5,45.5,131126,,,A*65",
    "$GPRMC,101630.00,A,0403.1380,N,00946.1460,E,3.5,45.5,131126,,,A*00",   # checksum FAUX : doit être rejetée
]


def checksum_ok(phrase):
    """Vérifie que la phrase n'est pas abîmée (le code à la fin, après le *)."""
    if not phrase.startswith("$") or "*" not in phrase:
        return False
    contenu, code = phrase[1:].split("*")      # contenu = entre $ et *, code = après *
    calcul = 0
    for lettre in contenu:
        calcul ^= ord(lettre)                  # on combine toutes les lettres 
    return f"{calcul:02X}" == code.strip().upper()   # le résultat doit égaler le code reçu


def to_degrees(valeur, direction):
    """Convertit 0403.0660 (degrés + minutes) en degrés décimaux (4.0511)."""
    point = valeur.index(".")
    degres = float(valeur[:point - 2])         # les chiffres avant les 2 derniers = degrés
    minutes = float(valeur[point - 2:])        # le reste = minutes
    resultat = degres + minutes / 60           # 60 minutes = 1 degré
    if direction in ("S", "W"):                # Sud et Ouest = valeurs négatives
        resultat = -resultat
    return round(resultat, 6)


def parse(phrase, altitude):
    """Lit une phrase. Renvoie (position, altitude) ; position vaut None si pas une position."""
    if not checksum_ok(phrase):
        print("  Phrase rejetée (checksum faux) :", phrase)
        return None, altitude

    champs = phrase.split("*")[0].split(",")   
    type_phrase = champs[0][3:]                # GPGGA -> GGA ; GPRMC -> RMC

    if type_phrase == "GGA":                   # GGA : on retient juste l'altitude
        return None, float(champs[9])

    if type_phrase == "RMC" and champs[2] == "A":   # A = le GPS a un signal valide
        # Date (jjmmaa) + heure (hhmmss) -> date et heure complètes
        moment = datetime.strptime(champs[9] + champs[1][:6], "%d%m%y%H%M%S")
        position = {
            "client_uuid": str(uuid.uuid4()),
            "latitude": to_degrees(champs[3], champs[4]),
            "longitude": to_degrees(champs[5], champs[6]),
            "speed": round(float(champs[7]) * 0.514444, 2),   # nœuds -> mètres par seconde
            "heading": float(champs[8]),                      # cap en degrés
            "altitude": altitude,
            "recorded_at": moment.replace(tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        return position, altitude

    return None, altitude                      # autre type de phrase : on ignore


def main():
    positions = []
    altitude = None
    for phrase in PHRASES:
        position, altitude = parse(phrase, altitude)
        if position:
            positions.append(position)
            print("  OK", position["latitude"], position["longitude"],
                  "vitesse", position["speed"], "m/s, cap", position["heading"])

    print(f"\n{len(positions)} positions valides sur {sum('RMC' in p for p in PHRASES)} phrases RMC")

    # Envoie les positions à l'API 
    if "--send" in sys.argv:
        from simulator import call, EMAIL, PASSWORD
        call("POST", "/register", {"email": EMAIL, "password": PASSWORD})
        _, data = call("POST", "/login", {"email": EMAIL, "password": PASSWORD})
        code, _ = call("POST", "/positions/batch", positions, data["access_token"])
        print("Envoi à l'API :", code, "(201 = OK)")


if __name__ == "__main__":
    main()