#!/usr/bin/env bash
# Hoe staat het gemeenschapsplatform erbij? Containers, de drie adressen, de
# uitrol vanuit GitHub en de laatste back-up.
#
#   sudo /opt/gemeenschap/server/controleer.sh

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root
cd "$DG_MAP" || exit 1
[ -s .env ] || { echo "  Nog niet geïnstalleerd."; exit 0; }

meld "Containers"
dc ps --format '  {{.Service}}: {{.Status}}'

meld "Adressen"
DOMEIN="$(sed -n 's/^DOMEIN=//p' .env)"
for naam in "kennis.$DOMEIN" "documenten.$DOMEIN" "architectuur.$DOMEIN" "beheer.$DOMEIN"; do
  wijst_hier "$naam" || waarschuw "$naam wijst nog niet naar deze server (DNS); dat deel is nog niet bereikbaar"
done
for adres in $(controle_adressen "$DOMEIN"); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$adres")"
  if [[ "$code" =~ ^[23] ]]; then ok "https://$adres ($code)"
  else waarschuw "https://$adres antwoordt niet goed ($code)"; fi
done

# "Niet veilig" bij sommige bezoekers komt bijna altijd door DNS: een naam die
# (ook) naar een andere server wijst, vaak een AAAA-record (IPv6) dat de
# registrar standaard aanmaakt. Wie IPv6 heeft, komt dan ergens anders uit, met
# een verkeerd certificaat of zonder https.
meld "DNS en https"
IP4="$(publiek_ip)"
IP6="$(ip -6 route get 2606:4700:4700::1111 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
for naam in "$DOMEIN" "www.$DOMEIN" "aanmelden.$DOMEIN" "projecten.$DOMEIN" "forum.$DOMEIN" "chat.$DOMEIN" "matrix.$DOMEIN"; do
  a="$(getent ahostsv4 "$naam" | awk '{print $1}' | sort -u | tr '\n' ' ')"
  aaaa="$(python3 -I -c 'import socket,sys
try: print(" ".join(sorted({i[4][0] for i in socket.getaddrinfo(sys.argv[1], 443, socket.AF_INET6)})))
except Exception: pass' "$naam")"
  if [ -z "$a" ]; then waarschuw "$naam: geen A-record"; continue; fi
  [ "${a% }" = "$IP4" ] || waarschuw "$naam wijst (ook) naar ${a% } in plaats van alleen $IP4; haal de andere A-records weg"
  if [ -n "$aaaa" ] && [ "$aaaa" != "$IP6" ]; then
    waarschuw "$naam heeft een AAAA-record ($aaaa) dat niet naar deze server wijst; bezoekers met IPv6 krijgen dan 'niet veilig'. Haal het weg bij de registrar${IP6:+ of zet het op $IP6}"
  fi
  code="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 8 --resolve "$naam:80:127.0.0.1" "http://$naam/")"
  case "$code" in
    30[178]\ https://*) ok "$naam: A klopt, http stuurt door naar https" ;;
    *) waarschuw "http://$naam stuurt niet door naar https ($code)" ;;
  esac
done

meld "Uitrol vanuit GitHub"
if systemctl is-active -q dg-uitrol.timer; then ok "Timer actief"; else waarschuw "Timer staat uit: sudo systemctl enable --now dg-uitrol.timer"; fi

meld "Stand van de server voor beheer"
if systemctl is-active -q dg-status.timer; then ok "Timer actief"; else waarschuw "Timer staat uit: sudo systemctl enable --now dg-status.timer"; fi

meld "Architectuurmodellen"
if systemctl is-active -q dg-architectuur.timer; then ok "Timer actief"; else waarschuw "Timer staat uit: sudo systemctl enable --now dg-architectuur.timer"; fi
if [ -s /var/lib/dg-gemeenschap/architectuur/lijst ]; then
  while IFS='|' read -r naam titel _ datum; do
    if [ -f "/srv/dg-architectuur/$naam/index.html" ]; then ok "$titel (bijgewerkt $datum)"; else waarschuw "$titel: nog geen rapport (zie sudo grep architectuur /var/lib/dg-gemeenschap/logboek)"; fi
  done < /var/lib/dg-gemeenschap/architectuur/lijst
else
  ok "Nog geen modellen in architectuur/repos.txt"
fi
"$DG_MAP/server/uitrol.sh" --status | sed 's/^/  /'

meld "Back-up"
LAATSTE="$(find /var/backups/dg-gemeenschap -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
if [ -n "$LAATSTE" ]; then ok "Laatste: $LAATSTE ($(du -sh "$LAATSTE" | cut -f1))"; else waarschuw "Nog geen back-up"; fi
echo
