# Eén platform, meerdere organisaties — ontwerp (proefstuk)

*Concept, 25 november 2026; bijgewerkt na het besluit over accounts op meer platforms. Aanleiding: een eigen platform voor de Vakvereniging NL-DIT, naast dat van Digitaal GemeenGoed. Nog niet besloten; ter beoordeling door Erik.*

## Uitgangspunten (Erik, 25 november 2026)

1. **Juridisch gescheiden.** Elke organisatie heeft een eigen platform op een eigen server, met eigen gebruikersbeheer. Elke organisatie is zelf verantwoordelijk voor de persoonsgegevens op haar platform.
2. **Modules naar keuze.** NL-DIT neemt alles behalve *projecten*.
3. **Een eigen uiterlijk.** De vormgeving staat los van het platform. Een organisatie kiest haar eigen huisstijl, en in principe ook een eigen WordPress-thema; de onderdelen van het platform krijgen daarin een plek.
4. **Sturen vanuit Git**, zoals bij DGG: inhoud op `main`, infrastructuur op een versie-tag.
5. **Een netwerk van platforms.** Een gebruiker kan zelf kiezen om één account op meer platforms te gebruiken.

## Twee soorten repo's

| Repo | Van wie | Wat erin staat |
|---|---|---|
| **Platform**, bijvoorbeeld `Digitaal-Gemeengoed/platform` | gedeeld; EUPL | alle code: Caddy, Keycloak, WordPress-plugins, Documenten, Beheer, de scripts op de server, het standaardthema. Geen naam, logo of kleuren van een organisatie. |
| **Organisatie**, bijvoorbeeld `NL-DIT/platform` | de organisatie | `organisatie.yml`, `huisstijl/`, `inhoud/` (pagina's en menu), `kennis/` (startinhoud van de wiki), eventueel `thema/` |

De server van een organisatie haalt haar eigen repo op. Daarin staat welke versie van het platform zij gebruikt. Geheimen (wachtwoorden, sleutels) staan nooit in Git, maar in `.env` op de server.

### `organisatie.yml` (voorbeeld NL-DIT)

```yaml
naam: Vakvereniging NL-DIT
kort: NL-DIT
domein: nl-dit.nl            # nog te bevestigen
contact: info@nl-dit.nl
platform: v0.30.0             # versie van het platform; ophogen = bijwerken
modules:
  - basis                     # altijd
  - ledenbeheer
  - berichten
  - agenda
  - kennis
  - architectuur
  - bestanden
  - chat
  - community
  - instellingen
  - beheer
  # - projecten
thema: standaard              # of: eigen (map thema/) of de naam van een thema op wordpress.org
netwerk: aan                  # verbinden met andere platforms mag; de verbindingen zelf staan in Beheer
```

## Modules

| Module | Onderdelen | Hangt af van |
|---|---|---|
| basis | Caddy, Keycloak, WordPress + BuddyPress (leden, profielen), pagina's uit Git, dashboard | — |
| ledenbeheer | CiviCRM | basis |
| berichten | nieuws, berichten, persoonlijke berichten (met mail) | basis |
| agenda | dg-agenda | basis |
| kennis | Wiki.js | basis |
| architectuur | rapporten van de Archi-modellen, oauth2-proxy | basis |
| bestanden | Documenten, Garage (S3), OpenSearch | basis |
| chat | Synapse, MAS, Element | basis |
| community | groepen (werkgroepen) en fora (bbPress) | basis |
| instellingen | eigen account (Keycloak), meldingen | basis |
| beheer | dg-beheer | basis |
| projecten | Redmine, projectvoorstellen, toezeggingen | basis |

Per module gaan samen aan of uit: de containers (Compose-`profiles`), het adres in Caddy, de client in Keycloak, de WordPress-plugin, de menu-items en de controles in `controleer.sh`. Een module die uitstaat, heeft geen subdomein nodig in DNS.

### Wat er in de code moet veranderen

- **Naam, logo en kleuren:** die staan nu op zo'n 30 plekken in de code. Ze moeten uit `organisatie.yml` en `huisstijl/` komen. Dat moet sowieso: naam en logo van DGG zijn beschermd.
- **Redmine los maken.** Projecten is nu verweven met het dashboard, de vaste tags `project-…` in Berichten, de projectruimtes in Documenten, de projectvoorstellen, de back-up, `herstellen.sh` en de controles. Zonder Redmine moet alles blijven werken; in Documenten blijft dan alleen de ruimte van de organisatie en die van de werkgroepen over.
- **De realm** heet nu `gemeenschap` en dat mag zo blijven: het is per server, en een vaste naam houdt de code eenvoudig.

## Uiterlijk en thema

Er zijn drie niveaus, van eenvoudig naar vrij:

1. **Huisstijl** (`huisstijl/`): logo, icoon, kleuren en lettertypen. Het standaardthema (nu het kindthema op BuddyX) en alle modules buiten WordPress lezen deze waarden. Dat zijn het inlogscherm van Keycloak, Documenten, Beheer, de kennisbank, Projecten, de overzichtspagina van Architectuur en de chat. Voor de meeste organisaties is dit genoeg.
2. **Eigen kindthema** (`thema/`): eigen CSS en sjablonen bovenop het standaardthema.
3. **Een ander WordPress-thema.** Dat kan, onder voorwaarden:
   - het thema moet BuddyPress ondersteunen (de meeste thema's doen dat via BP Nouveau);
   - de onderdelen van het platform (dashboard, berichten, agenda, kaarten op pagina's) staan in de plugins, niet in het thema, en tonen zich via shortcodes en blokken. Ze nemen de kleuren van de huisstijl over via CSS-variabelen.

Het platform levert dus de functies en het thema levert de vormgeving. Wat nu nog in het kindthema staat en geen vormgeving is, gaat naar de plugins. Een voorbeeld is het openen van modules in een nieuw tabblad; dat staat al sinds 0.22.1 in de plugin.

Een grens: modules buiten WordPress (Keycloak, Wiki.js, Element, Redmine, Documenten) kunnen geen WordPress-thema overnemen. Daar gaat alleen de huisstijl mee (logo, kleuren, lettertype, link naar de hoofdpagina).

## Eén account op meer platforms

**Besluit (Erik, 25 november 2026): accounts uitwisselen (provisioning), maar alleen op keuze van de gebruiker.** Er zijn twee manieren om het te starten, en ze sluiten elkaar niet uit:

1. **Vanuit de eigen instellingen** op het platform waar de gebruiker al lid is. De gebruiker kiest het andere platform en geeft akkoord om zijn gegevens door te geven.
2. **Bij het inloggen op het nieuwe platform**, met *Inloggen met je account bij …* (gekoppeld inloggen).

In beide gevallen krijgt de gebruiker op elk platform een eigen account; de wachtwoorden mogen verschillen. Lidmaatschap blijft een eigen relatie met elke organisatie, met eigen voorwaarden en een eigen grondslag. Het doorgeven van gegevens is dus nog geen lidmaatschap: dat begint pas als de gebruiker op het nieuwe platform akkoord geeft met de voorwaarden van die organisatie.

### Wat er overgaat

Een vaste set, het **netwerkprofiel**. De gebruiker kiest per onderdeel wat mee mag:

| Onderdeel | Bron | Standaard aangevinkt |
|---|---|---|
| Voornaam, achternaam, e-mail | Keycloak | ja (nodig voor een account) |
| Organisatie, functie, werkveld | Keycloak | ja |
| Profieltekst, foto, links | BuddyPress | nee |

**Nooit mee:** wachtwoorden, groepen en rollen (bijvoorbeeld kerngroep), toestemming voor mailings, gegevens uit CiviCRM, berichten en lidmaatschap van werkgroepen. Toestemming voor mailings vraagt elke organisatie zelf.

### Manier 1: vanuit de instellingen

Op een nieuwe pagina **Mijn platforms** in het persoonlijke menu (een gewone WordPress-pagina):

1. De gebruiker ziet de gekoppelde platforms, met naam, korte omschrijving en een link naar hun voorwaarden en privacyverklaring.
2. Bij *Account aanmaken bij NL-DIT* kiest hij welke onderdelen meegaan en geeft hij akkoord: "Ik geef Digitaal GemeenGoed opdracht om deze gegevens door te geven aan Vakvereniging NL-DIT."
3. DGG stuurt het netwerkprofiel naar NL-DIT (zie "Techniek").
4. NL-DIT maakt het account aan met de status **in afwachting** en stuurt de gebruiker een mail: "Je account bij NL-DIT staat klaar. Rond het af door de voorwaarden te lezen en een wachtwoord te kiezen, of door in te loggen met je DGG-account. Was jij dit niet? Klik dan hier, dan verdwijnt het."
5. Na akkoord met de voorwaarden van NL-DIT is het account actief: zichtbaar in de ledenlijst en bruikbaar voor de modules.

Een account dat na 30 dagen nog in afwachting is, verwijdert NL-DIT vanzelf. Dat volgt uit dataminimalisatie: zonder lidmaatschap is er geen reden om de gegevens te bewaren.

### Manier 2: bij het inloggen op het nieuwe platform

1. Op het inlogscherm van NL-DIT kiest de gebruiker *Inloggen met je account bij Digitaal GemeenGoed*.
2. Keycloak van DGG vraagt eerst toestemming: "Vakvereniging NL-DIT wil je netwerkprofiel ontvangen." De gebruiker ziet welke onderdelen dat zijn en kan de onderdelen kiezen die niet standaard aangevinkt staan.
3. NL-DIT maakt het account aan, al gekoppeld aan DGG, en vraagt direct akkoord met de eigen voorwaarden. Daarna is het account actief.
4. Later kan de gebruiker ook een eigen wachtwoord bij NL-DIT instellen. Dan kan hij inloggen zonder DGG.

### Daarna: bijhouden of niet

Na het aanmaken gaat er standaard niets meer over. Op *Mijn platforms* kan de gebruiker per platform aanzetten: **"Wijzigingen in mijn profiel ook doorgeven"**. Doorlopend doorgeven is een doorlopende verstrekking, en daarom een aparte keuze. Uitzetten stopt het doorgeven. Het account bij de andere organisatie blijft dan bestaan: opzeggen doet de gebruiker bij die organisatie zelf, en de pagina linkt naar haar opzegpagina. **Besluit (Erik, 25 november 2026):** geen knop om op afstand te laten verwijderen. Zulke acties horen thuis op het platform zelf.

Elke wijziging van een keuze komt in een **logboek van toestemmingen**, op beide platforms: wie, wanneer, welke onderdelen, welk platform en welke versie van de tekst.

### Techniek

- **Eén ontvangstpunt per platform:** een *netwerk-API* in dg-beheer, op `beheer.<domein>/netwerk/`. Die ontvangt een netwerkprofiel in het formaat van SCIM 2.0 (`User`, met een eigen uitbreiding voor organisatie, functie, werkveld en profiel). Dit is een eigen ontvangstpunt en niet de SCIM van Keycloak zelf, omdat de ontvangende kant eigen regels toepast: in afwachting, voorwaarden, de controlemail, opruimen na 30 dagen, de foto naar BuddyPress, het logboek. SCIM als formaat houdt de deur open voor platforms die niet op deze code draaien.
- **Manier 1** (push): dg-beheer van DGG stuurt een `POST /netwerk/Users` naar NL-DIT. Elke koppeling heeft eigen inloggegevens (OAuth2 client credentials), met een limiet op het aantal aanvragen. Wijzigingen gaan als `PATCH`, alleen als de gebruiker dat heeft aangezet.
- **Manier 2** (pull): het standaard gekoppelde inloggen van Keycloak (identity provider, OIDC). De client van NL-DIT bij DGG staat op *Consent required* en heeft een scope `netwerkprofiel`. De onderdelen uit Keycloak komen mee in het token. Profieltekst, foto en links haalt NL-DIT daarna met datzelfde token op bij `GET /netwerk/Me` van DGG.
- **Bestaat het e-mailadres al bij NL-DIT?** Dan wordt er geen tweede account aangemaakt. NL-DIT stuurt een mail naar dat adres met het voorstel om de twee accounts te koppelen.
- **E-mailverificatie:** NL-DIT vertrouwt een adres dat de partner al heeft bevestigd. Dat is een instelling per koppeling. De controlemail uit stap 4 werkt bovendien als tweede slot.

### De keerzijde, en hoe het ontwerp die opvangt

- *Gegevens bij een andere verantwoordelijke zonder lidmaatschap.* Het account blijft in afwachting tot de gebruiker akkoord geeft met de voorwaarden, en verdwijnt na 30 dagen.
- *Was het de gebruiker wel zelf?* De controlemail van het ontvangende platform met *Was jij dit niet?*, en het logboek aan beide kanten.
- *Een gehackte of onbetrouwbare partner* kan accounts aanmaken bij de anderen. Daartegen helpen eigen inloggegevens per koppeling, een limiet, de status in afwachting en de controlemail. En elke kant kan een verbinding in Beheer direct pauzeren.
- *Privacyverklaringen.* Beide verklaringen moeten het doorgeven noemen: de verzendende kant (op verzoek van de gebruiker) en de ontvangende kant (wat er binnenkomt en hoe lang het blijft).

### Daarnaast: de inlog van de eigen organisatie

Veel leden werken bij een gemeente met een eigen inlog (meestal Entra ID). Keycloak kan die per organisatie koppelen; dat staat al in het ontwerp van DGG (*Organizations*). Koppelen twee platforms allebei de inlog van bijvoorbeeld Haarlem, dan logt een medewerker van Haarlem op beide in met hetzelfde werkaccount. Dat staat los van het uitwisselen hierboven en vult het aan.

### Platforms verbinden (in Beheer)

**Besluit (Erik, 25 november 2026):** platforms verbinden gaat via een procedure in de module Beheer, met standaardvoorwaarden die beide organisaties accepteren. De voorwaarden staan in concept in [`netwerkvoorwaarden.md`](netwerkvoorwaarden.md).

Een verbinding staat dus niet in Git maar in Beheer. Ze bevat geheimen, en elke organisatie moet haar zelf aangaan en kunnen verbreken. In `organisatie.yml` staat alleen of verbinden mag (`netwerk: aan`).

**Wie mag wat:**
- **Beheerders** (`/site/beheer`) zetten een verbinding klaar en voeren de techniek uit.
- **Accepteren** van de voorwaarden doet iemand die de organisatie mag binden. Bij DGG is dat de kerngroep; elke organisatie wijst daarvoor zelf een groep aan in Keycloak (`netwerk_accepteren: /netwerk/kerngroep`).

**De procedure:**

1. **Verzoek.** Een beheerder van DGG vult in Beheer het adres van het andere platform in (`https://nl-dit.nl`). Beheer haalt daar de gegevens van het platform op: `/.well-known/dg-netwerk`, met naam, organisatie, netwerk-API, uitgever en de versie van de voorwaarden. Beheer toont die ter controle en stuurt een verbindingsverzoek.
2. **Controlecode.** Beide kanten tonen dezelfde code van zes tekens. De beheerders vergelijken die buiten het platform om, per mail of telefoon. Zo kan niemand zich voordoen als een ander platform.
3. **Accepteren.** Bij NL-DIT verschijnt het verzoek in Beheer. Iemand die daartoe bevoegd is, leest de voorwaarden en accepteert ze. Daarna doet een bevoegde bij DGG hetzelfde. Bij elke acceptatie wordt vastgelegd wie, wanneer, welke versie en namens welke organisatie.
4. **Sleutels uitwisselen.** Na de tweede acceptatie maakt elk platform zelf de inloggegevens voor de ander aan: een client in Keycloak voor het gekoppelde inloggen en inloggegevens voor de netwerk-API. Die gaan via de verbinding uit stap 1 over, nooit via mail. Daarna staat de verbinding **actief** en verschijnt het platform op *Mijn platforms* bij de gebruikers.
5. **Pauzeren of beëindigen** kan elke kant op elk moment, eenzijdig. Pauzeren: tijdelijk niets uitwisselen. Beëindigen: de sleutels gaan weg en de ander krijgt een bericht. Accounts die al zijn aangemaakt, blijven bestaan: dat is de eigen relatie van de gebruiker met die organisatie.
6. **Nieuwe versie van de voorwaarden.** Beide kanten moeten die opnieuw accepteren. Tot dan blijft de verbinding op de oude versie draaien, maximaal 60 dagen. Daarna wordt ze gepauzeerd.

Bij vier of meer platforms groeit het aantal verbindingen snel (N×(N−1)). Een centraal netwerkregister kan dan later de lijst met platforms bijhouden; de verbindingen zelf blijven tussen twee platforms.

## Sturen vanuit Git

| Wat | Hoe | Wanneer live |
|---|---|---|
| Een pagina, het menu, de voorwaarden | wijziging op `main` in de organisatie-repo | binnen 5 minuten |
| Huisstijl of thema | wijziging plus een versie-tag | bij de volgende uitrol |
| Een module aan of uit | één regel in `organisatie.yml` plus een tag | idem; een nieuwe module heeft eerst een DNS-record nodig |
| Bijwerken naar een nieuwe versie van het platform | `platform:` ophogen plus een tag | idem; eerst een back-up, bij een fout terug naar de vorige versie |
| Een verbinding met een ander platform | niet in Git: de procedure in Beheer (verzoek, controlecode, acceptatie van de voorwaarden aan beide kanten) | zodra beide kanten hebben geaccepteerd |

Wie wat mag, regelt de organisatie op GitHub. Bijvoorbeeld: de redactie maakt pull requests, het bestuur of de kerngroep keurt ze goed (branch protection op `main`), en alleen beheerders zetten tags. Wie een tag zet, krijgt een mail bij een geslaagde of mislukte uitrol (`UITROL_MELDEN`).

## Fasering

1. **Algemeen maken in de huidige repo.** Naam, logo en kleuren komen uit configuratie, modules worden schakelbaar en Redmine wordt optioneel. Voor DGG verandert er niets zichtbaars.
2. **Splitsen.** De code gaat naar de nieuwe platform-repo. `Digitaal-Gemeengoed/gemeenschap` blijft bestaan als de organisatie-repo van DGG, met alleen nog configuratie, huisstijl en inhoud. De server van DGG gaat over zonder opnieuw te installeren.
3. **NL-DIT neerzetten** op de nieuwe VPS, met eigen domein, SMTP, huisstijl en inhoud.
4. **Netwerk:** de netwerk-API in dg-beheer, de pagina *Mijn platforms*, gekoppeld inloggen met toestemming, en daarna de koppeling van DGG en NL-DIT na afspraak tussen de twee organisaties.

### Stand van fase 1 (branch `fase-1-algemeen`, 25 november 2026)

Gedaan: `organisatie.yml` met de lezer `server/organisatie.py`; modules als Compose-profielen en eigen Caddy-bestanden; WordPress, de serverscripts, de back-up en de controles per module; Redmine optioneel; naam, soort en kleuren uit de configuratie in de code; logo en icoon via `/huisstijl/`.

Nog niet, voor NL-DIT nodig (fase 2 en 3):
- **Een standaardthema.** Het WordPress-thema is nog dat van DGG: logo, kleuren en de voet ("© Stichting Digitaal GemeenGoed · in samenwerking met NL-Dit").
- **Inlogscherm:** de kleuren van Keycloak staan nog vast in het thema van DGG.
- **Werkgroepen en fora:** `dg_werkgroepen()` maakt nog de werkgroepen van DGG aan (Common Ground, Open Overheid …). Die moeten uit de organisatie-repo komen.
- **Inhoud:** de pagina's (`inhoud/`) en de startinhoud van de kennisbank zijn van DGG; die gaan naar de organisatie-repo.
- **Keycloak:** de clients van modules die uit staan, blijven in de realm staan (onschadelijk, maar niet netjes).
- **Een paar teksten** noemen Redmine ook als projecten uit staat (Documenten: "Mijn documenten", Beheer: meldingen na een wijziging).

## Open vragen

- Het domein van NL-DIT, en de SMTP-dienst (en het afzendadres) die NL-DIT gebruikt.
- Wie bij NL-DIT de repo beheert en tags zet.
- Waar de platform-repo komt te staan: onder Digitaal-Gemeengoed, of in een neutrale organisatie op GitHub. Dat laatste past beter als het netwerk groeit.
- De netwerkvoorwaarden (concept) laten toetsen door een jurist of de functionaris gegevensbescherming van een van de organisaties.
