# Freewood-Guild

**Deutsch & English · German & English.** Autor · Author: Lacustat. Version 0.1.0 · Interface 16001 (World of Warcraft: Forever).

## Inhalt · Contents
- [Deutsch](#deutsch)
- [English](#english)

## Deutsch

### Was ist das?
Das Gilden-Modul der Freewood-Familie: eine Mitgliedertabelle mit Berufen, Favoritengruppen und ein Level-Ranking für die Gilde. Alles ist im Spiel noch ungeprüft.

### Funktionen (Stufe 1)
- **Mitglieder:** Tabelle mit Online/Offline/Alle, Suche (Name, Klasse, Beruf, sogar Rezepte: „Wer kann das herstellen?“), Spalten per Klick auf- und absteigend sortierbar. Spalten: Name, Level, Klasse, Rasse, Rang, Hauptberuf 1 und 2 (anklickbar: zeigt die Rezepte des Spielers), Kochen, Erste Hilfe, Angeln, Spielzeit, EP-Balken, Gold (nur Eigentümer).
- **Rechtsklick** auf ein Mitglied: Flüstern, Einladen, Favorit und Favoritengruppe.
- **Favoriten:** Favoriten und Favoritengruppen pro Charakter oder für den ganzen Account, Gruppe mit einem Klick einladen.
- **Level-Ranking:** Wertung = Gesamt-EP durch Spielzeit; die besten vier oben als Highlight („Kopf an Kopf“), darunter die Tabelle. Mit „Folgen“ gibt es einen Hinweis bei Platzwechsel.
- **Symbole:** Affenkopf für Mitglieder, Affenkopf mit Krone für den Gildenleiter (`Media\affen_mitglied.tga`, `Media\ober_affe.tga`).
- **Befehle:** `/fwguild` (öffnen), `/fwguild probe` (prüft, was das Spiel liefert), `/fwguild share` (Daten neu senden), `/fwguild refresh`.

### So kommen die Daten zustande
Aus der Gildenliste des Spiels kommen Name, Level, Klasse, Rang, Zone, Online-Status (und die Rasse per GUID, wenn möglich). Berufe, Rezepte, EP, Spielzeit und Gold meldet jedes Mitglied mit diesem Addon selbst über Addon-Nachrichten (Präfix `FWGuild1`, gedrosselt). Wer das Addon nicht hat, zeigt dort „-“. Rezepte werden gemeldet, sobald der Spieler sein Berufefenster öffnet. Das Gold geht nur als Flüsternachricht an online Eigentümer (aus `Freewood-Codex`).

### Abhängigkeiten
- Benötigt: `Freewood-Core`
- Optional: `Freewood-Codex` (Eigentümer-Erkennung), `Freewood-CodexData`
- Kein Creator, kein Brett.

### Geplant (nächste Stufen)
Gildenaufträge, Anfragen, Instanz-Übersicht, Kartenpositionen der Mitglieder.

### Lizenz
GPL-3.0-or-later (siehe `LICENSE`).

## English

### What is this?
The guild module of the Freewood family: a member table with professions, favourite groups and a guild level ranking. Everything is still unverified in the game.

### Features (stage 1)
- **Members:** table with Online/Offline/All, search (name, class, profession, even recipes: "who can craft this?"), columns sortable ascending/descending by click. Columns: name, level, class, race, rank, main profession 1 and 2 (clickable: shows the player's recipes), cooking, first aid, fishing, played time, XP bar, gold (owners only).
- **Right click** on a member: whisper, invite, favourite and favourite group.
- **Favourites:** favourites and favourite groups per character or account-wide, invite a group with one click.
- **Level ranking:** score = total XP divided by played time; the top four as a highlight ("head to head"), the table below. "Follow" gives a notice when ranks change.
- **Icons:** monkey head for members, crowned monkey head for the guild master (`Media\affen_mitglied.tga`, `Media\ober_affe.tga`).
- **Commands:** `/fwguild` (open), `/fwguild probe` (checks what the game provides), `/fwguild share` (resend data), `/fwguild refresh`.

### Where the data comes from
The game's guild roster provides name, level, class, rank, zone, online status (and the race via GUID when possible). Professions, recipes, XP, played time and gold are reported by each member with this addon via addon messages (prefix `FWGuild1`, throttled). Players without the addon show "-". Recipes are reported when the player opens the profession window. Gold goes only as a whisper to online owners (from `Freewood-Codex`).

### Dependencies
- Required: `Freewood-Core`
- Optional: `Freewood-Codex` (owner detection), `Freewood-CodexData`
- No Creator, no Brett.

### Planned (next stages)
Guild orders, requests, instance overview, member positions on the map.

### License
GPL-3.0-or-later (see `LICENSE`).
