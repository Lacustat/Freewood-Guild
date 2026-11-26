# Freewood Guild

**English · Deutsch** — Author: Lacustat · Version 0.11.0 · Interface 16001 (World of Warcraft: Forever)

## Contents · Inhalt
- [English](#english)
  - [What is Freewood Guild?](#what-is-freewood-guild)
  - [Members and professions](#members-and-professions)
  - [Favourites and level ranking](#favourites-and-level-ranking)
  - [Orders and requests](#orders-and-requests)
  - [Dungeon browser](#dungeon-browser)
  - [Instances and guild achievements](#instances-and-guild-achievements)
  - [Map and name plates](#map-and-name-plates)
  - [Where the data comes from](#where-the-data-comes-from)
  - [Commands](#commands)
  - [Requirements and installation](#requirements-and-installation)
- [Deutsch](#deutsch)
  - [Was ist Freewood Guild?](#was-ist-freewood-guild)
  - [Mitglieder und Berufe](#mitglieder-und-berufe)
  - [Favoriten und Level-Rangliste](#favoriten-und-level-rangliste)
  - [Aufträge und Gesuche](#aufträge-und-gesuche)
  - [Dungeon-Browser](#dungeon-browser-1)
  - [Instanzen und Gilden-Erfolge](#instanzen-und-gilden-erfolge)
  - [Karte und Namensplaketten](#karte-und-namensplaketten)
  - [Woher die Daten kommen](#woher-die-daten-kommen)
  - [Befehle](#befehle)
  - [Voraussetzungen und Installation](#voraussetzungen-und-installation)
- [Changelog · Änderungen](CHANGELOG.md)

---

## English

### What is Freewood Guild?
The guild module of the Freewood family. It turns your guild into a shared workplace: a member table with professions and recipes, guild orders and requests, a dungeon browser that shows who in the guild is looking for a group, guild achievements, a level ranking and guild members on the map. It works best when many guild members use it – every member with the addon shares their own data.

### Members and professions
- Member table with online/offline/all, sortable columns: name, level, class, race, rank, both main professions, cooking, first aid, fishing, played time and XP.
- Search by name, class, profession and even by recipe: "who can craft this?"
- Click a profession to see the member's recipes, grouped by equipment slot, with item level, quality, tooltip and materials (green when you have them in your bags). "Watch" puts a recipe into the Freewood watch window.
- Professions of members without the addon are picked up from profession links they post in chat, including the tier (journeyman, expert …).
- Right-click on a member: whisper, invite, add to favourites or a favourite group.

### Favourites and level ranking
- Favourites and favourite groups, per character or account-wide; invite a whole group with one click.
- Level ranking: experience per played hour. The top four are shown "head to head", everyone else in the table below; "Follow" tells you when ranks change.

### Orders and requests
- Guild orders: profession and recipe (from the members' recipes), quantity, note and a material list with "have / missing".
- Requests: like orders, but for any item, with search and tooltips.
- Anyone can post, take ("I'll do it") and mark done; the creator and the guild master can delete. Entries vanish after 7 days.

### Dungeon browser
- Listens to the game's group finder: when guild members sign up, the guild sees who is looking for which dungeon and which roles are still missing.
- Small window "Guild is looking": each search as a block with the dungeon on top, every guild member of the group below in class colour and "Group 2/5, looking for damage". Left-click whispers, right-click invites. Movable, opens and closes by itself.
- Optional single line in guild chat when you sign up (only one line per sign-up, the group leader reports for the whole group).
- Group suggestion from the searching guild members (1 tank, 1 healer, 3 damage) with "Invite group".
- Optional: accept invites from guild members or friends automatically while you are searching.

### Instances and guild achievements
- Overview of all dungeons and raids with their bosses; hover a boss to see who in the guild has killed it, with a filter per player.
- Guild achievements: the guild collects points, for example when at least 3 guild members in one group defeat the last boss of a dungeon. Over 120 achievements in categories such as bosses, guild knowledge, members, levels, professions, recipes, time and variety.

### Map and name plates
- Guild members on the world map and minimap (monkey head, the guild master with a crown), icon size adjustable, sharing your own position can be switched off.
- Optional monkey icon above guild members' heads.

### Where the data comes from
The game's guild roster provides name, level, class, rank, zone and online status. Professions, recipes, experience, played time, orders, boss kills and positions are reported by each member with this addon through hidden guild addon messages, throttled to the game's limits. Members without the addon show "-".

### Commands
- `/fwguild` or `/fwgilde` – open the guild tab; `/fwguild share` – send your data again; `/fwguild refresh`
- `/fwdungeon` or `/fwdg` – dungeon browser; `/fwdg pos` – reset the window position
- `/fwach` – guild achievements

### Requirements and installation
- Required: **Freewood Core**. Optional: **Freewood Codex**, **Freewood CodexData** (item search for requests).
- Copy the folder `Freewood-Guild` into `World of Warcraft\_forever_\Interface\AddOns\`. Full game restart for new files.
- Settings via the "Settings" button in the Guild tab. Licence: GPL-3.0.

---

## Deutsch

### Was ist Freewood Guild?
Das Gildenmodul der Freewood-Familie. Es macht deine Gilde zu einem gemeinsamen Arbeitsplatz: eine Mitgliedertabelle mit Berufen und Rezepten, Gildenaufträge und Gesuche, ein Dungeon-Browser, der zeigt, wer in der Gilde eine Gruppe sucht, Gilden-Erfolge, eine Level-Rangliste und Gildenmitglieder auf der Karte. Am besten funktioniert es, wenn viele in der Gilde es nutzen – jedes Mitglied mit dem Addon teilt seine eigenen Daten.

### Mitglieder und Berufe
- Mitgliedertabelle mit Online/Offline/Alle, sortierbare Spalten: Name, Stufe, Klasse, Rasse, Rang, beide Hauptberufe, Kochen, Erste Hilfe, Angeln, Spielzeit und Erfahrung.
- Suche nach Name, Klasse, Beruf und sogar nach Rezept: „Wer kann das herstellen?“
- Klick auf einen Beruf zeigt die Rezepte des Mitglieds, nach Ausrüstungsplatz geordnet, mit Gegenstandsstufe, Qualität, Tooltip und Materialien (grün, wenn du sie in den Taschen hast). „Beobachten“ legt ein Rezept ins Freewood-Beobachten-Fenster.
- Berufe von Mitgliedern ohne Addon werden aus Berufslinks im Chat übernommen, samt Stufe (Geselle, Experte …).
- Rechtsklick auf ein Mitglied: anflüstern, einladen, zu den Favoriten oder einer Favoritengruppe.

### Favoriten und Level-Rangliste
- Favoriten und Favoritengruppen, je Charakter oder für den ganzen Account; eine ganze Gruppe mit einem Klick einladen.
- Level-Rangliste: Erfahrung je Stunde Spielzeit. Die besten vier „Kopf an Kopf“, alle anderen in der Tabelle darunter; „Verfolgen“ meldet, wenn sich die Plätze ändern.

### Aufträge und Gesuche
- Gildenaufträge: Beruf und Rezept (aus den Rezepten der Mitglieder), Menge, Notiz und eine Materialliste mit „habe / fehlt“.
- Gesuche: wie Aufträge, aber für jeden Gegenstand, mit Suche und Tooltips.
- Jeder kann einstellen, übernehmen („Mach ich“) und als erledigt markieren; Ersteller und Gildenmeister können löschen. Einträge verschwinden nach 7 Tagen.

### Dungeon-Browser
- Lauscht bei der Gruppensuche des Spiels mit: Melden sich Gildenmitglieder an, sieht die Gilde, wer für welchen Dungeon sucht und welche Rollen noch fehlen.
- Kleines Fenster „Gilde sucht“: jede Suche als Block mit dem Dungeon oben, darunter jedes Gildenmitglied der Gruppe in Klassenfarbe und „Gruppe 2/5, sucht Schaden“. Linksklick flüstert an, Rechtsklick lädt ein. Verschiebbar, öffnet und schließt sich von selbst.
- Auf Wunsch eine Zeile im Gildenchat bei deiner Anmeldung (nur eine Zeile je Anmeldung, der Gruppenleiter meldet für die ganze Gruppe).
- Gruppenvorschlag aus den suchenden Gildenmitgliedern (1 Tank, 1 Heiler, 3 Schaden) mit „Gruppe einladen“.
- Auf Wunsch: Einladungen von Gildenmitgliedern oder Freunden automatisch annehmen, solange du suchst.

### Instanzen und Gilden-Erfolge
- Übersicht aller Dungeons und Schlachtzüge mit ihren Bossen; mit der Maus über einem Boss siehst du, wer in der Gilde ihn besiegt hat, mit Filter je Spieler.
- Gilden-Erfolge: Die Gilde sammelt Punkte, zum Beispiel wenn mindestens 3 Gildenmitglieder in einer Gruppe den Endboss eines Dungeons besiegen. Über 120 Erfolge in Kategorien wie Bosse, Gildenwissen, Mitglieder, Stufen, Berufe, Rezepte, Zeit und Vielfalt.

### Karte und Namensplaketten
- Gildenmitglieder auf Weltkarte und Minimap (Affenkopf, der Gildenmeister mit Krone), Symbolgröße einstellbar, die eigene Position zu teilen lässt sich abschalten.
- Auf Wunsch ein Affensymbol über den Köpfen der Gildenmitglieder.

### Woher die Daten kommen
Die Gildenliste des Spiels liefert Name, Stufe, Klasse, Rang, Zone und Online-Status. Berufe, Rezepte, Erfahrung, Spielzeit, Aufträge, Bosskills und Positionen meldet jedes Mitglied mit diesem Addon über versteckte Addon-Nachrichten in der Gilde, gedrosselt nach den Grenzen des Spiels. Mitglieder ohne Addon zeigen „-“.

### Befehle
- `/fwguild` oder `/fwgilde` – Gildenreiter öffnen; `/fwguild share` – eigene Daten erneut senden; `/fwguild refresh`
- `/fwdungeon` oder `/fwdg` – Dungeon-Browser; `/fwdg pos` – Fensterposition zurücksetzen
- `/fwach` – Gilden-Erfolge

### Voraussetzungen und Installation
- Benötigt: **Freewood Core**. Optional: **Freewood Codex**, **Freewood CodexData** (Gegenstandssuche für Gesuche).
- Den Ordner `Freewood-Guild` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren. Bei neuen Dateien das Spiel komplett neu starten.
- Einstellungen über den Knopf „Einstellungen“ im Reiter Gilde. Lizenz: GPL-3.0.
