# Gedeelde hulpfuncties voor de serverscripts van het gemeenschapsplatform.
# Wordt ingelezen, niet gestart.
# shellcheck shell=bash

set -euo pipefail

# De map van deze repo op de server, en waar de uitrol bijhoudt wat er staat.
DG_MAP="${DG_MAP:-/opt/gemeenschap}"
DG_STAAT="${DG_STAAT:-/var/lib/dg-gemeenschap}"
# shellcheck disable=SC2034  # gebruikt in de scripts die dit inlezen
DG_REPO="${DG_REPO:-https://github.com/Digitaal-Gemeengoed/gemeenschap}"
COMPOSE=compose.yml

meld()     { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()       { printf '  \033[32m✓\033[0m %s\n' "$*"; }
waarschuw(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
stop()     { printf '\n\033[1;31mGestopt:\033[0m %s\n\n' "$*" >&2; exit 1; }

moet_root() {
  [ "$(id -u)" -eq 0 ] || stop "Start dit script met sudo ervoor, bijvoorbeeld: sudo $0"
}

# --- Organisatie en modules (organisatie.yml) ----------------------------------
# server/organisatie.py zet organisatie.yml om in organisatie.env (naam,
# huisstijl, DG_MODULES) voor docker compose. bijwerken.sh doet dat bij elke
# uitrol; zonder organisatie.env staat alles aan, zoals vóór 0.23.0.
DG_ORG_ENV="$DG_STAAT/organisatie.env"
ALLE_MODULES="basis ledenbeheer berichten agenda kennis architectuur bestanden chat community instellingen beheer projecten"

organisatie_lezen() {
  local tijdelijk
  install -d -m 755 "$DG_STAAT"
  tijdelijk="$(mktemp "$DG_ORG_ENV.XXXXXX")"
  if ! python3 -I "$DG_MAP/server/organisatie.py" env "$DG_MAP/organisatie.yml" > "$tijdelijk"; then
    rm -f "$tijdelijk"; return 1
  fi
  chmod 644 "$tijdelijk"
  mv "$tijdelijk" "$DG_ORG_ENV"
}

# De modules die aan staan, met spaties; altijd met basis.
modules() {
  local lijst
  lijst="$(sed -n "s/^DG_MODULES='\(.*\)'$/\1/p" "$DG_ORG_ENV" 2>/dev/null || true)"
  if [ -n "$lijst" ]; then echo "${lijst//,/ }"; else echo "$ALLE_MODULES"; fi
}
module_aan() { [[ " $(modules) " == *" $1 "* ]]; }

# Een waarde uit organisatie.env: org_waarde ORG_NAAM.
org_waarde() {
  local w
  w="$(sed -n "s/^$1='\\(.*\\)'$/\\1/p" "$DG_ORG_ENV" 2>/dev/null || true)"
  if [ -z "$w" ] && [ "$1" = ORG_NAAM ]; then w=Gemeenschapsplatform; fi
  printf '%s' "$w"
}

# De Caddy-blokken van de modules die aan staan naar $DG_STAAT/caddy (in de
# proxy: /etc/caddy-actief). In dezelfde map blijven: de proxy ziet die map
# via een koppeling, en een vervangen map zou hij niet zien.
caddy_modules() {
  local doel="$DG_STAAT/caddy" m
  install -d -m 755 "$doel" "$doel/hoofd"
  rm -f "$doel"/*.caddy "$doel"/hoofd/*.caddy
  for m in $(modules); do
    if [ -f "$DG_MAP/caddy/modules/$m.caddy" ]; then install -m 644 "$DG_MAP/caddy/modules/$m.caddy" "$doel/$m.caddy"; fi
    if [ -f "$DG_MAP/caddy/modules/$m.hoofd.caddy" ]; then install -m 644 "$DG_MAP/caddy/modules/$m.hoofd.caddy" "$doel/hoofd/$m.caddy"; fi
  done
}

# Stopt de containers van modules die uit staan. Hun volumes (de gegevens)
# blijven; de module weer aanzetten brengt alles terug.
modules_uit_zetten() {
  local m actief profiel uit
  actief="$(dc config --services | sort)"
  for m in $ALLE_MODULES; do
    module_aan "$m" && continue
    profiel="$(dc --profile "$m" config --services | sort)"
    uit="$(comm -13 <(echo "$actief") <(echo "$profiel") | tr '\n' ' ')"
    [ -n "${uit// /}" ] || continue
    # shellcheck disable=SC2086  # bewust gesplitst: de namen van de diensten
    if [ -n "$(dc --profile "$m" ps -q $uit 2>/dev/null)" ]; then
      dc --profile "$m" rm -s -f $uit >/dev/null 2>&1 || waarschuw "Module $m: stoppen lukte niet"
      ok "Module $m staat uit: $uit gestopt (de gegevens blijven)"
    fi
  done
}

# docker compose voor dit platform. Elke module (behalve basis) is een profiel
# in compose.yml; alleen de modules die aan staan, doen mee.
dc() {
  local args=(-f "$DG_MAP/$COMPOSE" --project-directory "$DG_MAP" --env-file "$DG_MAP/.env") m
  [ -f "$DG_ORG_ENV" ] && args+=(--env-file "$DG_ORG_ENV")
  for m in $(modules); do [ "$m" = basis ] || args+=(--profile "$m"); done
  docker compose "${args[@]}" "$@"
}

# Het publieke IPv4-adres: het bronadres van de route naar buiten.
publiek_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}'
}

vraag_ja() {
  local a
  read -r -p "$1 [ja/nee] " a
  [[ "${a,,}" =~ ^(j|ja|y|yes)$ ]]
}

# Willekeurig geheim, alleen hexadecimale tekens: veilig in .env, JSON en URL's.
geheim() { openssl rand -hex "${1:-32}"; }

# OpenSearch (zoeken in Documenten) wil vm.max_map_count van minstens 262144.
zoek_sysctl() {
  local nu
  nu="$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)"
  [ "$nu" -ge 262144 ] && return 0
  echo "vm.max_map_count=262144" > /etc/sysctl.d/90-dg-opensearch.conf
  sysctl -q -w vm.max_map_count=262144 || waarschuw "vm.max_map_count kon niet worden gezet; OpenSearch start dan misschien niet"
  ok "vm.max_map_count=262144 (voor OpenSearch)"
}

# Leest een KEY=waarde-bestand zonder het als script uit te voeren.
lees_env() {
  local bestand="$1" regel naam waarde
  [ -f "$bestand" ] || return 0
  while IFS= read -r regel || [ -n "$regel" ]; do
    regel="${regel%$'\r'}"
    [[ -z "$regel" || "$regel" == \#* ]] && continue
    [[ "$regel" =~ ^([A-Z][A-Z0-9_]*)=([A-Za-z0-9+/=.:_,@-]*)$ ]] || stop "Onverwachte regel in $bestand: $regel"
    naam="${BASH_REMATCH[1]}"
    waarde="${BASH_REMATCH[2]}"
    printf -v "$naam" '%s' "$waarde"
    export "${naam?}"
  done < "$bestand"
}

# Voegt KEY=waarde aan .env toe als KEY er nog niet in staat.
vul_env_aan() {
  local bestand="$1" naam="$2" waarde="$3"
  grep -q "^${naam}=" "$bestand" 2>/dev/null && return 0
  echo "${naam}=${waarde}" >> "$bestand"
  ok "Nieuwe instelling in .env: $naam"
}

# Zet KEY=waarde in .env: vervangt een bestaande regel of voegt toe.
zet_env() {
  local bestand="$1" naam="$2" waarde="$3" tijdelijk
  tijdelijk="$(mktemp "$bestand.XXXXXX")"
  grep -v "^${naam}=" "$bestand" > "$tijdelijk" || true
  printf '%s=%s\n' "$naam" "$waarde" >> "$tijdelijk"
  chmod 600 "$tijdelijk"
  mv "$tijdelijk" "$bestand"
}

geldig_domein() { [[ "$1" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; }

# Wacht tot een opdracht slaagt; $2 is het aantal pogingen van 5 seconden.
wacht() {
  local omschrijving="$1" n="$2"; shift 2
  printf '  wachten op %s ' "$omschrijving"
  for _ in $(seq "$n"); do
    if "$@" >/dev/null 2>&1; then echo; ok "$omschrijving antwoordt"; return 0; fi
    printf '.'; sleep 5
  done
  echo; return 1
}

keycloak_klaar()  { curl -fsS -o /dev/null http://127.0.0.1:8080/realms/master/.well-known/openid-configuration; }
wordpress_klaar() { dc exec -T wordpress curl -fsS -o /dev/null http://localhost/wp-includes/images/blank.gif; }
documenten_klaar() { dc exec -T documenten dg-documenten gezond; }
beheer_klaar()    { dc exec -T beheer dg-beheer gezond; }
redmine_klaar()   { dc exec -T redmine ruby -rnet/http -e 'exit Net::HTTP.get_response(URI("http://localhost:3000/login")).code.to_i < 400'; }

# De nieuwste versie-tag (vX.Y.Z) die op main staat; leeg als er geen is.
nieuwste_tag() {
  git -C "$DG_MAP" tag -l 'v[0-9]*.[0-9]*.[0-9]*' --merged origin/main | sort -V | tail -1
}

# Antwoorden de adressen? Via Caddy op deze server, zonder DNS. Gebruikt na een
# uitrol en na terugzetten.
# De spiegel van de objecten van de documenten (back-up.sh, herstellen.sh).
DOC_SPIEGEL="${DG_DOC_SPIEGEL:-/var/backups/dg-gemeenschap-objecten}"

# Wijst deze naam al naar deze server? (Zonder DNS heeft Caddy geen certificaat.)
wijst_hier() { [ "$(getent ahostsv4 "$1" | awk 'NR==1{print $1}')" = "$(publiek_ip)" ]; }

# De adressen om te controleren: altijd de drie basisadressen; de kennisbank,
# de documenten en beheer zodra hun naam naar deze server wijst.
controle_adressen() {
  local domein="$1"
  echo "$domein/" "aanmelden.$domein/realms/gemeenschap/.well-known/openid-configuration"
  if module_aan projecten; then echo "projecten.$domein/login"; fi
  if module_aan kennis && wijst_hier "kennis.$domein"; then echo "kennis.$domein/healthz"; fi
  if module_aan bestanden && wijst_hier "documenten.$domein"; then echo "documenten.$domein/healthz"; fi
  if module_aan beheer && wijst_hier "beheer.$domein"; then echo "beheer.$domein/healthz"; fi
}

# De namen in DNS die deze server nodig heeft, voor de modules die aan staan.
dns_namen() {
  local domein="$1"
  echo "$domein" "www.$domein" "aanmelden.$domein"
  module_aan projecten && echo "projecten.$domein"
  module_aan community && echo "forum.$domein"
  module_aan kennis && echo "kennis.$domein"
  module_aan architectuur && echo "architectuur.$domein"
  module_aan bestanden && echo "documenten.$domein"
  module_aan beheer && echo "beheer.$domein"
  module_aan chat && echo "chat.$domein" "matrix.$domein" "matrix-auth.$domein"
  return 0
}

gezond() {
  local domein code adres
  domein="$(sed -n 's/^DOMEIN=//p' "$DG_MAP/.env")"
  for adres in $(controle_adressen "$domein"); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 --resolve "${adres%%/*}:443:127.0.0.1" "https://$adres")"
    [[ "$code" =~ ^[23] ]] || { echo "https://$adres gaf $code"; return 1; }
  done
}
