# Freewood-Guild

**Deutsch & English · German & English.** Autor · Author: Lacustat. Version 0.3.4 · Interface 16001 (World of Warcraft: Forever).

## Inhalt · Contents
- [Deutsch](#deutsch)
- [English](#english)
- [Tastenbelegung · Key bindings](#tastenbelegung--key-bindings)

## Deutsch

### Was ist das?
Das Gilden-Modul der Freewood-Familie: eine Mitgliedertabelle mit Berufen, Favoritengruppen, ein Level-Ranking, Gildenaufträge, Anfragen, eine Instanz-Übersicht und Mitglieder-Positionen auf der Karte. Alles ist im Spiel noch ungeprüft.

### Funktionen (Stufe 1 und 2)
- **Mitglieder:** Tabelle mit Online/Offline/Alle, Suche (Name, Klasse, Beruf, sogar Rezepte: „Wer kann das herstellen?“), Spalten per Klick auf- und absteigend sortierbar. Spalten: Name, Level, Klasse, Rasse, Rang, Hauptberuf 1 und 2 (anklickbar: zeigt die Rezepte des Spielers), Kochen, Erste Hilfe, Angeln, Spielzeit, EP-Balken, Gold (nur Eigentümer).
- **Rezeptfenster** (Klick auf einen Beruf): Rezepte nach Körperplatz gruppiert (Kopf, Brust, Gürtel …), mit Item-Stufe, Qualitätsfarbe, Item-Tooltip und Material (grün, wenn in der Tasche). „Beobachten“ legt das Rezept in die Beobachtungsliste von Freewood-Core (`/fwwatch`). Das Ergebnis-Item und das Material melden die Mitglieder mit ihren Rezepten.
- **Rechtsklick** auf ein Mitglied: Flüstern, Einladen, Favorit und Favoritengruppe.
- **Favoriten:** Favoriten und Favoritengruppen pro Charakter oder für den ganzen Account, Gruppe mit einem Klick einladen.
- **Level-Ranking:** Wertung = Gesamt-EP durch Spielzeit; die besten vier oben als Highlight („Kopf an Kopf“), darunter die Tabelle. Mit „Folgen“ gibt es einen Hinweis bei Platzwechsel.
- **Gildenaufträge:** Beruf und Rezept (aus den Rezepten der Mitglieder), Menge, Notiz, Materialliste mit „habe ich / fehlt“. Jeder darf einstellen, übernehmen („Mach ich“) und als erledigt markieren. Löschen dürfen Ersteller, Gildenleiter und Eigentümer. Nach 7 Tagen verschwindet alles von selbst.
- **Anfragen:** wie Aufträge, aber auch mit beliebigen Items (Suche über Freewood-CodexData) und Tooltips.
- **Instanz-Übersicht:** alle Dungeons und Raids mit Bossen; Mausüberfahrt zeigt, wer den Boss getötet hat; Filter pro Spieler. Quellen: Boss-Kills des Spiels (`ENCOUNTER_END`), `BOSS_KILL` und gesperrte Instanzen.
- **Karte:** Gildenmitglieder auf der Weltkarte (Affenkopf, Gildenleiter mit Krone). In den Einstellungen ein-/ausschaltbar, eigene Position teilbar, Symbolgröße 8 bis 64 Pixel.
- **Symbole:** Affenkopf für Mitglieder, Affenkopf mit Krone für den Gildenleiter (`Media\affen_mitglied.tga`, `Media\ober_affe.tga`).
- **Befehle:** `/fwguild` (öffnen), `/fwguild probe` (prüft, was das Spiel liefert), `/fwguild share` (Daten neu senden), `/fwguild refresh`, `/fwguild sendtest` (misst die Sendegrenze des Spiels), `/fwguild stats` (Sende-Statistik).

### So kommen die Daten zustande
Aus der Gildenliste des Spiels kommen Name, Level, Klasse, Rang, Zone, Online-Status (und die Rasse per GUID, wenn möglich). Berufe, Rezepte, EP, Spielzeit, Gold, Aufträge, Boss-Kills und Position meldet jedes Mitglied mit diesem Addon selbst über Addon-Nachrichten (Präfix `FWGuild1`, gedrosselt wie Blizzards Regel: Burst bis 8, danach etwa eine Nachricht pro Sekunde; abgelehnte Nachrichten bleiben in der Warteschlange). Wer das Addon nicht hat, zeigt dort „-“. Rezepte werden gemeldet, sobald der Spieler sein Berufefenster öffnet. Das Gold geht nur als Flüsternachricht an online Eigentümer (aus `Freewood-Codex`).

### Abhängigkeiten
- Benötigt: `Freewood-Core` (ab 0.7.0 für die Beobachtungsliste)
- Optional: `Freewood-Codex` (Eigentümer-Erkennung), `Freewood-CodexData`
- Kein Creator, kein Brett.

### Stand
Alles ist im Spiel noch ungeprüft (nur in der Simulation getestet).

### Lizenz
GPL-3.0-or-later (siehe `LICENSE`).

## English

### What is this?
The guild module of the Freewood family: a member table with professions, favourite groups, a guild level ranking, guild orders, requests, an instance overview and member positions on the map. Everything is still unverified in the game.

### Features (stages 1 and 2)
- **Members:** table with Online/Offline/All, search (name, class, profession, even recipes: "who can craft this?"), columns sortable ascending/descending by click. Columns: name, level, class, race, rank, main profession 1 and 2 (clickable: shows the player's recipes), cooking, first aid, fishing, played time, XP bar, gold (owners only).
- **Recipe window** (click a profession): recipes grouped by equipment slot (head, chest, belt …), with item level, quality colour, item tooltip and materials (green when in your bags). "Watch" puts the recipe into the watch list of Freewood-Core (`/fwwatch`). Members report the result item and the materials together with their recipes.
- **Right click** on a member: whisper, invite, favourite and favourite group.
- **Favourites:** favourites and favourite groups per character or account-wide, invite a group with one click.
- **Level ranking:** score = total XP divided by played time; the top four as a highlight ("head to head"), the table below. "Follow" gives a notice when ranks change.
- **Guild orders:** profession and recipe (from members' recipes), quantity, note, material list with "have / missing". Anyone can post, take ("I'll do it") and mark done. The creator, the guild master and owners can delete. Everything vanishes after 7 days.
- **Requests:** like orders, but also any item (search via Freewood-CodexData) with tooltips.
- **Instance overview:** all dungeons and raids with bosses; hover shows who killed a boss; per-player filter. Sources: the game's boss kills (`ENCOUNTER_END`), `BOSS_KILL` and saved instances.
- **Map:** guild members on the world map (monkey head, guild master with crown). Switchable in the settings, own position shareable, icon size 8 to 64 pixels.
- **Icons:** monkey head for members, crowned monkey head for the guild master (`Media\affen_mitglied.tga`, `Media\ober_affe.tga`).
- **Commands:** `/fwguild` (open), `/fwguild probe` (checks what the game provides), `/fwguild share` (resend data), `/fwguild refresh`, `/fwguild sendtest` (measures the game's send limit), `/fwguild stats` (send statistics).

### Where the data comes from
The game's guild roster provides name, level, class, rank, zone, online status (and the race via GUID when possible). Professions, recipes, XP, played time, gold, orders, boss kills and position are reported by each member with this addon via addon messages (prefix `FWGuild1`, throttled like Blizzard's rule: burst up to 8, then about one message per second; rejected messages stay in the queue). Players without the addon show "-". Recipes are reported when the player opens the profession window. Gold goes only as a whisper to online owners (from `Freewood-Codex`).

### Dependencies
- Required: `Freewood-Core` (0.7.0 or newer for the watch list)
- Optional: `Freewood-Codex` (owner detection), `Freewood-CodexData`
- No Creator, no Brett.

### Status
Everything is still unverified in the game (simulation only).

### License
GPL-3.0-or-later (see `LICENSE`).

## Tastenbelegung · Key bindings
**DE:** Unter Optionen > Tastaturbelegung gibt es einen eigenen Abschnitt für dieses Modul. Dort lässt sich eine Taste zum Öffnen und Schließen des Reiters belegen (zum Beispiel J für die Gilde). Ist der Reiter schon offen, schließt dieselbe Taste das Fenster. Nach der Installation einmal das Spiel neu starten, damit die neue Datei Bindings.xml gelesen wird.
**EN:** Options > Key Bindings has its own section for this module. Bind a key to open and close the tab (for example J for the guild). If the tab is already open, the same key closes the window. Restart the game once after installing so the new Bindings.xml file is read.
