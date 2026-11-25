# Eén platform, meerdere organisaties — ontwerp (proefstuk)

*Concept, 25 november 2026. Aanleiding: een eigen platform voor de Vakvereniging NL-DIT, naast dat van Digitaal GemeenGoed. Nog niet besloten; ter beoordeling door Erik.*

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
netwerk: []                   # gekoppelde platforms, zie "Eén account op meer platforms"
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

**Doel:** een gebruiker van DGG kan op het platform van NL-DIT inloggen met zijn DGG-account, als hij dat wil, en andersom. De organisaties blijven juridisch gescheiden.

### Drie mogelijkheden

**A. Gekoppeld inloggen (identity brokering, OIDC) — aanbevolen om mee te beginnen.**
Elke Keycloak kent de andere als *identity provider*. Op het inlogscherm van NL-DIT staat dan *Inloggen met je account bij Digitaal GemeenGoed*. Bij de eerste keer maakt NL-DIT een eigen account aan, gekoppeld aan dat van DGG, met naam en e-mail. Daarna geeft de gebruiker op NL-DIT nog akkoord met de voorwaarden van NL-DIT. In het eigen account (*Gekoppelde accounts*, standaard in Keycloak) kan de gebruiker de koppeling zien en verbreken.

- Gegevens gaan alleen over als de gebruiker daar zelf voor kiest, en alleen naam en e-mail. Dat past bij de gescheiden verantwoordelijkheid.
- Er worden geen wachtwoorden gedeeld en er draait geen synchronisatie op de achtergrond.
- Elk platform blijft volledig zelfstandig. Valt DGG uit, dan kan de gebruiker op NL-DIT nog inloggen met een eigen wachtwoord (aan te bieden bij de eerste koppeling).
- Nadeel: bij N platforms zijn er N×(N−1) koppelingen. Bij twee of drie platforms is dat geen probleem.

**B. Accounts uitwisselen (provisioning, bijvoorbeeld SCIM).**
Een nieuw account op het ene platform ontstaat ook op het andere.
- *Voor:* de gebruiker meldt zich één keer aan en staat meteen ook bij de andere organisatie in de ledenlijst, met mailings.
- *Tegen:* juist dat is het probleem. Lidmaatschap van een organisatie is een eigen relatie met eigen voorwaarden en een eigen grondslag voor de verwerking. Persoonsgegevens gaan dan naar een andere verwerkingsverantwoordelijke zonder dat de gebruiker daar op dat moment voor kiest. Daar is een gegevensdelingsovereenkomst voor nodig, plus toestemming per platform. Bovendien stuurt SCIM geen wachtwoorden, en heeft Keycloak geen uitgaande SCIM.
- **Advies:** niet doen. "Naar eigen keuze" is precies wat A biedt.

**C. Een netwerk-account (één centrale inlog voor het netwerk).**
Een kleine, aparte Keycloak voor het netwerk, waar alle platforms naar koppelen zoals bij A.
- *Voor:* het aantal koppelingen groeit met N, niet met N². Ook is er één plek om het netwerk te beheren.
- *Tegen:* er is een derde partij nodig die deze inlog beheert, met een eigen verantwoordelijkheid en een eigen server. Zolang er twee of drie platforms zijn, is dat meer werk dan het oplevert.
- **Advies:** pas overwegen vanaf vier of meer platforms. Doordat A en C hetzelfde mechanisme gebruiken, is de overstap later eenvoudig.

### Daarnaast: de inlog van de eigen organisatie

Veel leden werken bij een gemeente met een eigen inlog (meestal Entra ID). Keycloak kan die per organisatie koppelen; dat staat al in het ontwerp van DGG (*Organizations*). Koppelen twee platforms allebei de inlog van bijvoorbeeld Haarlem, dan gebruikt een medewerker van Haarlem op beide platforms hetzelfde werkaccount. De platforms hoeven daarvoor niets uit te wisselen. Dit vervangt A niet (zzp'ers, marktpartijen en kleine organisaties hebben geen eigen inlog), maar het vult A wel aan: voor ambtenaren is het het eerlijkste "één account".

### In `organisatie.yml`

```yaml
netwerk:
  - naam: Digitaal GemeenGoed
    uitgever: https://aanmelden.digitaalgemeengoed.nl/realms/gemeenschap
    # client-id en geheim staan in .env (NETWERK_DGG_ID, NETWERK_DGG_GEHEIM)
```

Een koppeling werkt alleen als beide kanten haar instellen. NL-DIT neemt DGG op als identity provider, en DGG registreert NL-DIT als client, en andersom. Daar gaat een afspraak tussen de twee organisaties aan vooraf, maar het is geen gegevensdeling: de gebruiker kiest zelf.

## Sturen vanuit Git

| Wat | Hoe | Wanneer live |
|---|---|---|
| Een pagina, het menu, de voorwaarden | wijziging op `main` in de organisatie-repo | binnen 5 minuten |
| Huisstijl of thema | wijziging plus een versie-tag | bij de volgende uitrol |
| Een module aan of uit | één regel in `organisatie.yml` plus een tag | idem; een nieuwe module heeft eerst een DNS-record nodig |
| Bijwerken naar een nieuwe versie van het platform | `platform:` ophogen plus een tag | idem; eerst een back-up, bij een fout terug naar de vorige versie |
| Een koppeling met een ander platform | `netwerk:` aanvullen, geheim in `.env` | na afspraak met de andere organisatie |

Wie wat mag, regelt de organisatie op GitHub. Bijvoorbeeld: de redactie maakt pull requests, het bestuur of de kerngroep keurt ze goed (branch protection op `main`), en alleen beheerders zetten tags. Wie een tag zet, krijgt een mail bij een geslaagde of mislukte uitrol (`UITROL_MELDEN`).

## Fasering

1. **Algemeen maken in de huidige repo.** Naam, logo en kleuren komen uit configuratie, modules worden schakelbaar en Redmine wordt optioneel. Voor DGG verandert er niets zichtbaars.
2. **Splitsen.** De code gaat naar de nieuwe platform-repo. `Digitaal-Gemeengoed/gemeenschap` blijft bestaan als de organisatie-repo van DGG, met alleen nog configuratie, huisstijl en inhoud. De server van DGG gaat over zonder opnieuw te installeren.
3. **NL-DIT neerzetten** op de nieuwe VPS, met eigen domein, SMTP, huisstijl en inhoud.
4. **Koppelen** van DGG en NL-DIT (mogelijkheid A), na afspraak tussen de twee organisaties.

## Open vragen

- Het domein van NL-DIT, en de SMTP-dienst (en het afzendadres) die NL-DIT gebruikt.
- Wie bij NL-DIT de repo beheert en tags zet.
- Waar de platform-repo komt te staan: onder Digitaal-Gemeengoed, of in een neutrale organisatie op GitHub. Dat laatste past beter als het netwerk groeit.
- Moet een account op het ene platform ook op het andere verwijderd worden als de gebruiker dat vraagt? Bij A niet vanzelf: elk platform heeft zijn eigen account. Op de pagina met voorwaarden moet dat duidelijk staan.
