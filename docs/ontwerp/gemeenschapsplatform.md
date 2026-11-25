# Gemeenschapsplatform Digitaal Gemeengoed — ontwerp

*Vastgelegd 10 november 2026. Besluiten van Erik op 10 en 11 november 2026. Gebouwd in de eigen repo `Digitaal-Gemeengoed/gemeenschap` (VPS 4, "gemeenschap"); de basis van de server komt uit oa-uitrol.*

## Doel

Een gemeenschap rond Digitaal Gemeengoed (en de Office Assistent):
- **Netwerk** van contacten bij gemeenten: beheer, development en besluitvorming.
- **Werving en participatie:** gemeenten benaderen.
- **Meldingen, wensen en wijzigingsverzoeken**, en portfolio- en projectmanagement.
- **Discussiefora** in de traditionele vorm: categorieën, onderwerpen, reacties.

Omvang: tientallen contacten na een jaar, honderden na drie jaar. De verantwoordelijken zijn **Digitaal Gemeengoed** en **NL-Dit**.

## Besluiten

1. **Een eigen VPS 4**, los van de drie servers van de Office Assistent. Die hebben een ander risicoprofiel: archief en persoonsgegevens tegenover een openbare site met vrije registratie. VPS 4 zit ook **niet in het privénetwerk** van VPS 1 tot 3 (11 november 2026).
2. **Een eigen Keycloak op VPS 4**, realm `gemeenschap`. Vrije registratie komt nooit in de realm `gemeenten`, want die geeft toegang tot de Assistent.
3. **Keycloak is de bron** voor identiteit, organisatie, groepen en toestemmingen. **BuddyPress is de voordeur:** *Lid worden* op de site leidt naar de registratie van Keycloak, in de huisstijl. WordPress en Redmine maken een account aan bij de eerste keer inloggen. SCIM-provisioning vanuit BuddyPress naar Keycloak is besproken en afgewezen:
   - SCIM stuurt geen wachtwoorden;
   - je krijgt twee bronnen van gebruikers;
   - medewerkers die via de eigen inlog van hun gemeente binnenkomen, ontstaan in Keycloak.

   SCIM blijft wel bruikbaar als **inbound** voor gemeenten die hun eigen deelnemers aanleveren vanuit Entra ID. Keycloak ondersteunt dat sinds 26.8.
4. **CiviCRM vanaf het begin**, voor communicatie, mailings en toestemmingen.
5. **Traditionele fora** met bbPress in WordPress, gekoppeld aan de groepen van BuddyPress. Redmine heeft ook forums; die zijn er voor projectgebonden discussie.
6. **Onderhoud vanuit GitHub** (11 november 2026): een eigen repo, uitrol in twee sporen, pagina's als Markdown die in WordPress op slot staan. Zie hieronder.
7. **Thema BuddyX** (11 november 2026) met een kindthema in de repo: het logo van DGG (de uil) en de kleuren daaruit. Zie "Thema" hieronder.
8. **Kennisbank in Wiki.js** (11 november 2026), alleen voor leden, als de enige plek voor kennis. Zie "Kennisbank en architectuurmodellen" hieronder.
9. **Architectuurmodellen** (11 november 2026): één repo per project of domein (coArchi), op de eigen server gebouwd en alleen voor leden te zien.

## Adressen

| Adres | Wat |
|---|---|
| `digitaalgemeengoed.nl` (en `www.`) | WordPress: site, BuddyPress (leden, groepen, profielen), bbPress (fora onder `/forum/`), CiviCRM (in het beheer van WordPress) |
| `aanmelden.digitaalgemeengoed.nl` | Keycloak, realm `gemeenschap`: registreren, inloggen, eigen account. Het beheerscherm is alleen bereikbaar via een SSH-tunnel. |
| `projecten.digitaalgemeengoed.nl` | Redmine: meldingen, wensen, roadmap, portfolio, projectforums |
| `kennis.digitaalgemeengoed.nl` | Wiki.js: de kennisbank, alleen voor leden |
| `architectuur.digitaalgemeengoed.nl` | De HTML-rapporten van de architectuurmodellen, alleen voor leden |
| `forum.digitaalgemeengoed.nl` | Doorverwijzing naar `digitaalgemeengoed.nl/forum/` |

Het platform is openbaar; wat alleen voor leden is, regelt elk onderdeel zelf met het inloggen via Keycloak. (Tot 0.22.0 kon alles achter één wachtwoord in Caddy; dat is weg.)

## Keycloak, realm `gemeenschap`

- **Registratie:**
  - zelf registreren, met e-mailverificatie;
  - bescherming tegen brute force;
  - akkoord met de voorwaarden als verplichte actie (Keycloak legt het moment vast);
  - het thema in de huisstijl van Digitaal Gemeengoed (de uil, blauw).
- **Profielvelden** (gebruikersprofiel van Keycloak):
  - voornaam, achternaam en e-mail;
  - `organisatie`: tekst, voor wie (nog) niet bij een organisatie in Keycloak hoort;
  - `functie`;
  - `werkveld`: meer keuzes mogelijk uit beheer, development, besluitvorming, anders;
  - `toestemming_mailing`: ja of nee, apart van de voorwaarden.
- **Organizations** (sinds Keycloak 26): elke gemeente of organisatie met haar e-maildomein. Wie zich aanmeldt met @haarlem.nl, hoort vanzelf bij *Gemeente Haarlem*. Later kan een gemeente haar eigen inlog koppelen, zoals Entra ID.
- **Groepen** (de rol in het netwerk):
  - `/netwerk/gebruikers`: standaard; melden, reageren, fora, schrijven in de kennisbank;
  - `/netwerk/contributors`: issues oppakken, bijdragen;
  - `/netwerk/members`: deelnemende organisaties; meebeslissen over de roadmap, besloten projecten;
  - `/netwerk/kerngroep`: prioriteren, beslissen, versies;
  - `/site/redactie`: redacteur in WordPress en de kennisbank;
  - `/site/beheer`: beheerder van WordPress, Redmine en de kennisbank.
- **Clients:** `wordpress`, `redmine`, `wiki` en `architectuur` (vertrouwelijk, authorization code). Plus `redmine-sync`: een serviceaccount dat alleen gebruikers en groepen mag lezen.
- **Wat in het token zit:** `groups`, `organization`, `organisatie`, `functie`, `werkveld` en `toestemming_mailing`.
- **Bron van de instellingen:** `keycloak/realm/gemeenschap.json` in de repo, bij elke versie gelijkgetrokken met keycloak-config-cli (6.5.1, image-tag `6.5.1-26`). Leden, organisaties en groepslidmaatschappen beheer je in Keycloak zelf; die blijven staan.

## Koppelingen

### WordPress (plugin `dg-gemeenschap`, eigen code)

- **Inloggen alleen via Keycloak** (plugin OpenID Connect Generic, op wordpress.org `daggerhart-openid-connect-generic`). Registreren en het wachtwoordformulier van WordPress staan uit. Een inlogverzoek blijft een half uur geldig, lang genoeg voor de bevestigingsmail.
- **Bij elke login:**
  - **WordPress-rol:** administrator bij `/site/beheer`, editor bij `/site/redactie`, anders subscriber;
  - **BuddyPress-ledentype** uit de netwerkgroep met het meeste gewicht: kerngroep, member, contributor of gebruiker;
  - **BuddyPress-profielvelden** Organisatie, Functie en Werkveld, alleen-lezen (bron: Keycloak);
  - **CiviCRM:**
    - contact (via de standaardkoppeling tussen WordPress-gebruikers en contacten);
    - organisatiecontact plus de relatie "medewerker van";
    - de netwerkgroepen als groepen in CiviCRM;
    - de groep *Nieuwsbrief*, als `toestemming_mailing` aan staat;
    - bij elke wijziging van de toestemming een activiteit met de datum.
- **Fora:** bbPress, met forums per BuddyPress-groep, bijvoorbeeld per werkveld of per project.
- **Geen Gravatar:** profielfoto's worden niet bij Gravatar opgevraagd, want dat stuurt een versleuteld e-mailadres van elk lid naar een dienst buiten de EU.

### Redmine

- **Inloggen via OpenID Connect** met een plugin. Een account ontstaat bij de eerste login.
- **Groepen:** een synchronisatie (`redmine-groepen`, elke 10 minuten) neemt de netwerkgroepen uit Keycloak over als groepen in Redmine. Rollen per project wijs je in Redmine toe aan die groepen.
- **Rollen in Redmine:**
  - *Gebruiker*: melden, reageren;
  - *Contributor*: issues bewerken;
  - *Member*: roadmap en besloten projecten;
  - *Kerngroep*: beheren.
- **Geen wiki per project:** kennis staat in de kennisbank. Een projectwiki waarin al iets staat, blijft.
- **Zichtbaarheid van gebruikers:** alleen leden van de eigen projecten.
- **Koppeling met de code:** een kopie van de repo's op GitHub. "refs #12" in een commit verwijst naar melding 12.

### Mail

Eén SMTP-dienst voor Keycloak (verificatie), WordPress, CiviCRM (CiviMail) en Redmine (meldingen). SPF, DKIM en DMARC moeten op `digitaalgemeengoed.nl` staan. Bij voorkeur een Europese aanbieder (nu: Migadu). Poort 465 (SSL) en 587 (STARTTLS) werken allebei.

## Kennisbank en architectuurmodellen

Besluiten van Erik op 11 november 2026: **Wiki.js** als kennisbank, **één repo per project of domein** voor de architectuurmodellen, en beide **alleen voor leden** (om mee te beginnen).

**Waarom één kennisbank.** Er waren al drie plekken voor kennis: pagina's in WordPress, een wiki per project in Redmine en de fora. De wiki wordt de enige plek: het menu *Kennisbank* en het dashboard wijzen ernaar, en de wiki per project in Redmine staat uit. Wiki.js is gekozen boven een statische site uit een repo, omdat medewerkers van gemeenten zonder GitHub moeten kunnen schrijven. Met de Git-opslag staat alles toch ook in GitHub.

**Kennisbank** (`kennis.<domein>`, Wiki.js 2.5):
- Inloggen via Keycloak (client `wiki`). De wikigroepen heten zoals de groepen in Keycloak, en de wiki neemt ze bij elke login over:
  - `/netwerk/gebruikers`: lezen en schrijven;
  - `/site/redactie`: ook verplaatsen en verwijderen;
  - `/site/beheer`: alles.
- Gasten mogen niets en gaan meteen naar het inloggen.
- Ingericht als code (`wiki/inrichten.py`, via GraphQL, bij elke versie): titel, logo en kleuren, groepen, Nederlands en een startpagina met spelregels. Een noodaccount staat niet op het inlogscherm.
- **Offline:** de vertalingen zitten in de image, vastgezet op één commit van Requarks/wiki-localization. Zelfs de Engelse teksten haalt Wiki.js anders online op. Wiki.js 3.0 is overwogen, maar op GitHub is nog geen 3.x-versie.
- **Git-opslag** naar de privé-repo `Digitaal-Gemeengoed/kennisbank`, in beide richtingen, elke vijf minuten, met een deploy key die de server zelf maakt. Bij elke wijziging staan de naam en het e-mailadres van de schrijver in GitHub. Dat is een doorgifte aan Microsoft, die nog getoetst moet worden.

**Architectuurmodellen** (`architectuur.<domein>`):
- Elke repo is een Archi-model in het formaat van coArchi (`model/folder.xml`). De lijst staat in `architectuur/repos.txt` en werkt na samenvoegen op `main`, zonder versie.
- `server/architectuur.sh` (systemd-timer, elk kwartier) haalt elke repo op en bouwt het HTML-rapport met archimate-ci-image (Archi 5.7.0), zonder netwerk. Dat gebeurt alleen bij een nieuwe commit. Een mislukte bouw laat het vorige rapport staan.
- Er komt een overzichtspagina met alle modellen.
- Alleen leden: Caddy vraagt bij elke aanvraag aan **oauth2-proxy** (client `architectuur`, groep `/netwerk/gebruikers`) of iemand is ingelogd.
- Gekozen boven bouwen in GitHub Actions met GitHub Pages: dan zou het rapport openbaar zijn en buiten de eigen server staan.
- Spelregel: geen netwerkinrichting, beveiligingsmaatregelen of leveranciersafspraken van een gemeente in een model (BIO).

**Nog te testen op de server:**
- de image archimate-ci-image met een echt model (lokaal kon dat niet: geen Docker);
- de Git-opslag naar GitHub met de deploy key;
- of coArchi 2 een ander formaat gebruikt dan `model/folder.xml`.

## Onderhoud vanuit GitHub

**De server haalt op; GitHub komt er niet in.** Een systemd-timer (`dg-uitrol`) kijkt elke vijf minuten. Afgewezen: GitHub Actions die via SSH uitrollen. Dat vraagt een root-sleutel in GitHub en SSH open voor de adressen van GitHub, terwijl `ssh-afsluiten.sh` SSH juist dichtzet.

**Twee sporen**, omdat er geen testomgeving is:

| Spoor | Wat | Wanneer live |
|---|---|---|
| Inhoud | `inhoud/`: pagina's, menu's, afbeeldingen | na samenvoegen op `main` |
| Infrastructuur | al het andere: images, realm, plugins, thema, scripts | bij een versie-tag `vX.Y.Z` op `main`; eerst een back-up, en terug naar de vorige tag als de site daarna niet antwoordt |

Terugzetten herstelt containers en instellingen, niet database-migraties; daarvoor is de back-up van vlak ervoor. Een mislukte tag wordt niet opnieuw geprobeerd. Wie op `main` mag samenvoegen, verandert de site; wie een tag mag zetten, verandert de server. Daarom: regels op GitHub voor `main` (pull request met goedkeuring) en voor tags `v*` (alleen beheerders).

**Pagina's als Markdown** (`wp dg inhoud`, mu-plugin `dg-inhoud`):
- Een kopje met titel, adres, ouder, volgorde, status (publiceren of concept) en voorpagina, daaronder Markdown. Dat wordt omgezet naar blokken van de blokeditor.
- Eerst wordt alles gecontroleerd: onbekende velden, dubbele adressen, links naar pagina's of afbeeldingen die niet bestaan. Bij een fout verandert er niets.
- Pagina's uit de repo staan **op slot** in WordPress, ook voor beheerders, met een link *Bewerken op GitHub*. Nieuws, berichten en fora blijven in WordPress.
- Een pagina die uit de repo verdwijnt, wordt een concept.
- Menu's (hoofdmenu en voet) staan in `inhoud/menu.md` en worden gewone WordPress-menu's; het hoofdmenu komt op de plek *Primary* van het thema.
- HTML in de tekst wordt tekst: wie in de repo schrijft, kan geen scripts op de site zetten.
- Voor voorwaarden en privacyverklaring is dit een voordeel: elke versie, en wie hem wijzigde, staat in de geschiedenis van het bestand.

## Thema

**BuddyX** (Wbcom Designs, gratis op wordpress.org, GPL; versie vast in `compose.yml`) met een kindthema `wordpress/thema/digitaalgemeengoed`:
- het logo (de uil) en een sitepictogram uit `assets/`, bij het inrichten in de mediabibliotheek gezet;
- kleuren uit het logo: marine `#0a2654`, blauw `#14478f`, groen `#3f7f1d`; contrast volgens WCAG AA. De lichtblauwe kleur uit het logo (`#13aef3`) haalt dat contrast niet en is alleen voor decoratie;
- één inhoudsbreedte van 1380 px, geen zijbalken; alleen de achtergrond van de opening loopt over de hele breedte;
- een voet met het menu *Voet*;
- kleuren, breedte en voet staan vast in `functions.php`; wat in de Customizer staat, telt daarvoor niet.

Gekozen boven het eigen kindthema van Twenty Twenty-Five, na een vergelijking op dezelfde testgegevens:
- BuddyX toont leden als kaarten en fora als een volle tabel, met een meldingsbel en een donkere modus;
- Twenty Twenty-Five liet BuddyPress en bbPress er kaal uitzien.

Wat ertegenover staat:
- één leverancier, die ook betaalde uitbreidingen verkoopt;
- een hybride thema (klassieke sjablonen), geen volledig blokthema.

De pagina's zijn gewone blokken; als BuddyX ooit wegvalt, werken ze in elk ander thema. BuddyBoss is afgewezen: dat vervangt BuddyPress door een eigen platform, en het thema is betaald.

## AVG

- **Gezamenlijke verwerkingsverantwoordelijken** (art. 26 AVG): Digitaal Gemeengoed en NL-Dit. Er hoort een onderlinge regeling bij, met één aanspreekpunt; de kern ervan staat in de privacyverklaring.
- **Wie de VPS beheert** en geen van beide is, is verwerker. Er hoort dan een verwerkersovereenkomst bij.
- **Grondslagen:** de overeenkomst (deelnemen aan het platform), en toestemming voor mailings. Toestemmingen worden vanaf de eerste aanmelding vastgelegd, met datum, in Keycloak en CiviCRM.
- **Zichtbaarheid:** profielvelden zijn standaard alleen zichtbaar voor ingelogde leden. E-mailadressen zijn nooit openbaar. Meldingen in Redmine zijn openbaar. De kennisbank en de architectuurmodellen zijn alleen voor leden.
- **GitHub:** de kennisbank (via de Git-opslag) en de modellen staan ook in besloten repo's op GitHub, met naam en e-mailadres bij elke wijziging. Die doorgifte buiten de EER moet nog getoetst worden.
- **Geen derden in de pagina's:** geen Gravatar, geen statistieken of trackers.
- Er hoort een register van verwerkingen en een privacyverklaring bij. Concepten van voorwaarden en privacyverklaring staan in `inhoud/paginas/`; ze moeten nog juridisch worden getoetst.

## Grootte en onderhoud

- **VPS 4:** 4 vCPU en 8 GB geheugen; Keycloak, WordPress met CiviCRM, MariaDB, Redmine, Wiki.js, oauth2-proxy en drie keer Postgres. Archi draait alleen even bij het bouwen van een rapport (maximaal 2 GB).
- **Back-up:** elke nacht en vlak voor elke nieuwe versie: de databases (ook die van de kennisbank) en uploads, 14 dagen. Ook buiten de VPS bewaren.
- **Updates:** via versie-tags in de repo. WordPress en de plugins gaan via wp-cli.

## Later

- Brokering van Keycloak naar de realm `gemeenten` van de Office Assistent, zodat medewerkers met hun bestaande account inloggen.
- Inbound SCIM voor gemeenten die hun deelnemers aanleveren.
- Discourse, als de fora groter worden dan bbPress aankan.
- Een testserver die automatisch `main` volgt, zodat een versie-tag eerst daar draait.
- Het logo als vectorbestand (SVG), voor scherpte op grote schermen en in druk.
- De kennisbank en de modellen (deels) openbaar maken, als het netwerk dat wil.
- Wiki.js 3, zodra die stabiel is en Git-opslag en OIDC daarin werken.
