#!/bin/sh
# WordPress inrichten of bijwerken voor Digitaal GemeenGoed. Draait in de
# wp-cli-container (compose.yml, service wpcli):
#
#   docker compose -f compose.yml run --rm wpcli dg-inrichten
#
# Opnieuw draaien kan zonder schade: wat er al is, blijft; plugins, WordPress
# en vertalingen worden bijgewerkt, net als de database van CiviCRM.
set -eu
cd /var/www/html
wp() { command wp --path=/var/www/html "$@"; }
log() { printf '  %s\n' "$*"; }
# Staat de module aan (organisatie.yml, via DG_MODULES)? Zonder lijst: alles.
module_aan() {
  [ -z "${DG_MODULES:-}" ] && return 0
  case ",$DG_MODULES," in *",$1,"*) return 0 ;; esac
  return 1
}

# --- WordPress ----------------------------------------------------------------
if ! wp core is-installed 2>/dev/null; then
  wp core install --url="https://$DOMEIN" --title="${ORG_NAAM:-Gemeenschapsplatform}" \
    --admin_user=beheer --admin_password="$WP_BEHEER_WACHTWOORD" \
    --admin_email="beheer@$DOMEIN" --skip-email
  log "WordPress geïnstalleerd (noodaccount: beheer)"
fi
wp core update --minor >/dev/null && wp core update-db >/dev/null
wp language core install nl_NL --activate >/dev/null 2>&1 || true
# Naam en omschrijving uit organisatie.yml (ORG_NAAM, ORG_OMSCHRIJVING).
[ -n "${ORG_NAAM:-}" ] && wp option update blogname "$ORG_NAAM" >/dev/null
[ -n "${ORG_OMSCHRIJVING:-}" ] && wp option update blogdescription "$ORG_OMSCHRIJVING" >/dev/null
wp option update timezone_string Europe/Amsterdam >/dev/null
wp option update date_format 'j F Y' >/dev/null
wp option update users_can_register 0 >/dev/null
wp option update default_comment_status closed >/dev/null
wp rewrite structure '/%postname%/' >/dev/null
log "WordPress $(wp core version), Nederlands"

# --- Plugins van wordpress.org ------------------------------------------------
# De OpenID Connect-plugin heet op wordpress.org daggerhart-openid-connect-generic.
# bbPress (de fora) hoort bij de module community.
PLUGINS="daggerhart-openid-connect-generic buddypress"
if module_aan community; then PLUGINS="$PLUGINS bbpress"; else wp plugin deactivate bbpress >/dev/null 2>&1 || true; fi
for p in $PLUGINS; do
  if wp plugin is-installed "$p"; then wp plugin update "$p" >/dev/null 2>&1 || true; else wp plugin install "$p" >/dev/null; fi
  wp plugin activate "$p" >/dev/null 2>&1 || true
done
wp language plugin install --all nl_NL >/dev/null 2>&1 || true
wp language plugin update --all >/dev/null 2>&1 || true
log "Plugins: $PLUGINS"

# Inloggen via Keycloak: de vaste instellingen; geheimen en adressen komen
# als constanten uit dg-gemeenschap.php (omgeving). Een inlogverzoek blijft een
# half uur geldig (standaard drie minuten): lang genoeg om bij het aanmelden de
# bevestigingsmail te openen.
wp option update openid_connect_generic_settings --format=json \
  '{"identity_key":"preferred_username","nickname_key":"preferred_username","email_format":"{email}","displayname_format":"{given_name} {family_name}","identify_with_username":false,"token_refresh_enable":1,"http_request_timeout":10,"state_time_limit":1800}' >/dev/null

# BuddyPress: leden, profielen, activiteit en meldingen altijd; groepen
# (community), berichten (berichten) en instellingen (instellingen) per module.
BP='"members":1,"xprofile":1,"activity":1,"notifications":1'
if module_aan community; then BP="$BP,\"groups\":1"; fi
if module_aan instellingen; then BP="$BP,\"settings\":1"; fi
if module_aan berichten; then BP="$BP,\"messages\":1"; fi
wp option update bp-active-components --format=json "{$BP}" >/dev/null
# De tabellen van de onderdelen (alleen de optie zetten maakt ze niet aan) en de pagina's.
wp eval 'require_once ABSPATH . "wp-admin/includes/upgrade.php"; require_once buddypress()->plugin_dir . "bp-core/admin/bp-core-admin-schema.php"; bp_core_install( bp_get_option( "bp-active-components" ) ); bp_core_add_page_mappings( bp_get_option( "bp-active-components" ), "keep" );' >/dev/null
# Groepen maken alleen beheerders; leden worden lid van een werkgroep.
wp option update bp_restrict_group_creation 1 >/dev/null
log "BuddyPress-onderdelen en -pagina's"

# --- CiviCRM ------------------------------------------------------------------
# Module ledenbeheer. Staat die uit, dan gaat CiviCRM uit (de gegevens blijven).
if module_aan ledenbeheer; then
  # Een nieuwe versie: CIVICRM_VERSIE in .env ophogen en bijwerken.sh draaien.
  GEINSTALLEERD="$(wp plugin get civicrm --field=version 2>/dev/null || true)"
  if [ "$GEINSTALLEERD" != "$CIVICRM_VERSIE" ]; then
    log "CiviCRM $CIVICRM_VERSIE ophalen${GEINSTALLEERD:+ (was $GEINSTALLEERD)}"
    wp plugin install "https://download.civicrm.org/civicrm-${CIVICRM_VERSIE}-wordpress.zip" --force >/dev/null
  fi
  php -r 'copy("https://download.civicrm.org/cv/cv.phar", "/tmp/cv") or exit(1);' && chmod +x /tmp/cv
  wp plugin activate civicrm >/dev/null 2>&1 || true
  if ! /tmp/cv --cwd=/var/www/html ev 'return 1;' >/dev/null 2>&1; then
    /tmp/cv core:install --cwd=/var/www/html --cms-base-url="https://$DOMEIN" --lang=nl_NL >/dev/null
    log "CiviCRM geïnstalleerd"
  else
    /tmp/cv upgrade:db --cwd=/var/www/html >/dev/null 2>&1 || true
    log "CiviCRM bijgewerkt"
  fi
  # Naam en e-mail van WordPress-gebruikers en CiviCRM-contacten gelijk houden.
  if wp plugin is-installed civicrm-wp-profile-sync; then wp plugin update civicrm-wp-profile-sync >/dev/null 2>&1 || true; else wp plugin install civicrm-wp-profile-sync >/dev/null 2>&1 || true; fi
  wp plugin activate civicrm-wp-profile-sync >/dev/null 2>&1 || true
else
  wp plugin deactivate civicrm-wp-profile-sync civicrm >/dev/null 2>&1 || true
  log "CiviCRM staat uit (module ledenbeheer)"
fi

# --- Thema: BuddyX met ons kindthema (wordpress/thema/) ------------------------
# Een vaste versie; een nieuwe kies je met BUDDYX_VERSIE in compose.yml.
if [ "$(wp theme get buddyx --field=version 2>/dev/null || true)" != "$BUDDYX_VERSIE" ]; then
  wp theme install buddyx --version="$BUDDYX_VERSIE" --force >/dev/null
fi
wp theme activate digitaalgemeengoed >/dev/null
log "Thema (BuddyX $BUDDYX_VERSIE)"

# --- Onze inrichting: fora, profielvelden, adressen ----------------------------
wp dg inrichten
wp rewrite flush >/dev/null
wp cache flush >/dev/null 2>&1 || true
log "Klaar"
