"""Leest organisatie.yml (wie de site is en welke onderdelen aan staan).

Alleen het deel van YAML dat organisatie.yml gebruikt: "sleutel: waarde",
een lijst ("- item") en één niveau eronder ("  sleutel: waarde"), met
commentaar na #. Geen PyYAML nodig (staat niet op elke server).

    python3 -I organisatie.py env  <organisatie.yml>   KEY='waarde'-regels voor docker compose
    python3 -I organisatie.py modules <organisatie.yml>   de modules, met spaties
    python3 -I organisatie.py controle <organisatie.yml>  alleen controleren

Zonder organisatie.yml: alle modules en de standaardwaarden hieronder.
"""

import os
import re
import sys

MODULES = [
    "basis", "ledenbeheer", "berichten", "agenda", "kennis", "architectuur",
    "bestanden", "chat", "community", "instellingen", "beheer", "projecten",
]
STANDAARD = {
    "naam": "Gemeenschapsplatform",
    "kort": "",
    "organisatie": "",
    "soort": "organisatie",
    "omschrijving": "",
    "welkom": "",
    "modules": [m for m in MODULES if m != "basis"],
    "huisstijl": {"kleur": "#14478f", "kleur_donker": "#0a2654", "kleur_link": "#1a56a8"},
}
# Een module die een andere nodig heeft.
NODIG = {"agenda": ["berichten", "ledenbeheer"], "projecten": ["ledenbeheer"]}
KLEUR = re.compile(r"^#[0-9a-fA-F]{6}$")


class Fout(Exception):
    pass


def zonder_commentaar(regel):
    # Een # binnen aanhalingstekens is geen commentaar ("#14478f").
    uit, quote = [], None
    for i, c in enumerate(regel):
        if quote:
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#" and (i == 0 or regel[i - 1].isspace()):
            break
        uit.append(c)
    return "".join(uit).rstrip()


def scalar(tekst, nr):
    tekst = tekst.strip()
    if len(tekst) >= 2 and tekst[0] == tekst[-1] and tekst[0] in "\"'":
        return tekst[1:-1]
    if tekst.startswith(("[", "{", "|", ">", "&", "*", "!")):
        raise Fout(f"regel {nr}: deze schrijfwijze kent organisatie.yml niet")
    return tekst


def lees(pad):
    data, sleutel = {}, None
    with open(pad, encoding="utf-8") as f:
        for nr, ruw in enumerate(f, 1):
            regel = zonder_commentaar(ruw.rstrip("\n"))
            if not regel.strip() or regel.strip() == "---":
                continue
            inspring = len(regel) - len(regel.lstrip(" "))
            if "\t" in regel[:inspring + 1]:
                raise Fout(f"regel {nr}: gebruik spaties, geen tabs")
            tekst = regel.strip()
            if inspring == 0:
                m = re.match(r"^([a-z_]+):(.*)$", tekst)
                if not m:
                    raise Fout(f"regel {nr}: verwacht 'sleutel: waarde'")
                sleutel, waarde = m.group(1), m.group(2).strip()
                if sleutel in data:
                    raise Fout(f"regel {nr}: {sleutel} staat er twee keer in")
                data[sleutel] = scalar(waarde, nr) if waarde else None
            elif sleutel is None:
                raise Fout(f"regel {nr}: ingesprongen zonder sleutel erboven")
            elif tekst.startswith("- "):
                if data[sleutel] is None:
                    data[sleutel] = []
                if not isinstance(data[sleutel], list):
                    raise Fout(f"regel {nr}: {sleutel} mengt een lijst en iets anders")
                data[sleutel].append(scalar(tekst[2:], nr))
            else:
                m = re.match(r"^([a-z_]+):(.*)$", tekst)
                if not m:
                    raise Fout(f"regel {nr}: verwacht '- item' of 'sleutel: waarde'")
                if data[sleutel] is None:
                    data[sleutel] = {}
                if not isinstance(data[sleutel], dict):
                    raise Fout(f"regel {nr}: {sleutel} mengt een lijst en iets anders")
                data[sleutel][m.group(1)] = scalar(m.group(2), nr)
    return data


def organisatie(pad):
    data = dict(STANDAARD)
    data["huisstijl"] = dict(STANDAARD["huisstijl"])
    if pad and os.path.exists(pad):
        gelezen = lees(pad)
        onbekend = set(gelezen) - set(STANDAARD) - {"netwerk"}
        if onbekend:
            raise Fout("onbekende sleutel(s): " + ", ".join(sorted(onbekend)))
        for k, v in gelezen.items():
            if k == "huisstijl":
                if not isinstance(v, dict):
                    raise Fout("huisstijl: verwacht 'kleur: …' eronder")
                onb = set(v) - set(STANDAARD["huisstijl"])
                if onb:
                    raise Fout("onbekend in huisstijl: " + ", ".join(sorted(onb)))
                data["huisstijl"].update(v)
            elif k == "modules":
                data["modules"] = v or []
            elif v is not None:
                data[k] = v
    if not isinstance(data["modules"], list):
        raise Fout("modules: verwacht een lijst ('- naam')")
    onbekend = [m for m in data["modules"] if m not in MODULES]
    if onbekend:
        raise Fout("onbekende module(s): " + ", ".join(onbekend) + ". Bekend: " + ", ".join(MODULES[1:]))
    for k, v in data.items():
        if isinstance(v, str) and not v.isprintable():
            raise Fout(f"{k}: bevat tekens die hier niet kunnen")
    # Deze tekens breken HTML, YAML of de scripts waarin de naam terechtkomt.
    for k in ("naam", "kort", "organisatie", "soort"):
        slecht = sorted(set(data[k]) & set('&<>"\\|$`'))
        if slecht:
            raise Fout(f"{k}: deze tekens kunnen niet: {' '.join(slecht)} (schrijf & als 'en')")
    for k, v in data["huisstijl"].items():
        if not KLEUR.match(v):
            raise Fout(f"huisstijl.{k}: verwacht een kleur als #14478f")
    for m, nodig in NODIG.items():
        for n in nodig:
            if m in data["modules"] and n not in data["modules"]:
                raise Fout(f"module {m} heeft module {n} nodig; zet die er ook bij")
    if not data["naam"].strip():
        raise Fout("naam is leeg")
    # Altijd basis, en in een vaste volgorde.
    data["modules"] = [m for m in MODULES if m == "basis" or m in data["modules"]]
    return data


def env_regels(data):
    def q(waarde):
        # Enkele aanhalingstekens: docker compose leest dat letterlijk (geen
        # ${...}). Een ' zelf kan daar niet in; die wordt een ’.
        return "'" + str(waarde).replace("'", "’") + "'"

    h = data["huisstijl"]
    regels = [
        "# Gemaakt door server/organisatie.py uit organisatie.yml. Niet met de hand wijzigen.",
        "ORG_NAAM=" + q(data["naam"]),
        "ORG_KORT=" + q(data["kort"] or data["naam"]),
        "ORG_ORGANISATIE=" + q(data["organisatie"] or data["naam"]),
        "ORG_SOORT=" + q(data["soort"] or "organisatie"),
        "ORG_OMSCHRIJVING=" + q(data["omschrijving"]),
        "ORG_WELKOM=" + q(data["welkom"] or data["omschrijving"]),
        "ORG_KLEUR=" + q(h["kleur"]),
        "ORG_KLEUR_DONKER=" + q(h["kleur_donker"]),
        "ORG_KLEUR_LINK=" + q(h["kleur_link"]),
        "DG_MODULES=" + q(",".join(data["modules"])),
    ]
    # Per module die aan staat MODULE_<NAAM>='1', voor compose.yml:
    # ${MODULE_PROJECTEN:+http://redmine:3000} is leeg als projecten uit staat.
    regels += ["MODULE_" + m.upper() + "='1'" for m in data["modules"]]
    return "\n".join(regels) + "\n"


def main(argv):
    if len(argv) != 3 or argv[1] not in ("env", "modules", "controle"):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        data = organisatie(argv[2])
    except (Fout, OSError, UnicodeDecodeError) as e:
        print(f"organisatie.yml: {e}", file=sys.stderr)
        return 1
    if argv[1] == "env":
        sys.stdout.write(env_regels(data))
    elif argv[1] == "modules":
        print(" ".join(data["modules"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
