# Freewood-Guild

**Deutsch & English · German & English.** Autor · Author: Lacustat. Version 0.5.0 · Interface 16001 (World of Warcraft: Forever).

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
- **Dungeon Browser (0.5.0):** Neuer Reiter im Gilden-Fenster. Das Modul lauscht bei der Gruppensuche des Spiels mit (`C_LFGList`: Eintragen, Entfernen, Gruppenänderungen) und meldet der Gilde, wer wofür sucht: versteckt für alle mit Freewood-Guild (Nachricht `L`) und auf Wunsch (Haken, Standard an) als Zeile im Gildenchat („[Freewood] Pinky sucht für Todesminen als Schaden.“, höchstens eine pro Minute). Der Reiter listet alle Sucher je Dungeon mit Rollen und, bei Gruppen, was sie haben und was fehlt; dazu ein Gruppenvorschlag (1 Tank, 1 Heiler, 3 Schaden, Mehrfachrollen werden so verteilt, dass die Gruppe voll wird) mit Knopf „Gruppe einladen“: es lädt nur der ein, der sich zuerst angemeldet hat. Zwei Haken (Standard aus) nehmen Einladungen von Gildenmitgliedern und von Freunden automatisch an, aber nur, solange man selbst sucht und in keiner Gruppe ist. Befehl `/fwdungeon`. Die Grundlagen stammen aus der Probe `/fwlfg` (Freewood-Dev 0.13.5 bis 0.13.8); der Name des Dungeons und die Rollen beim Eintragen sind im Spiel noch ungeprüft.
- **Lebensbalken beim Affen (0.4.5):** Neue Einstellung „Lebensbalken und Name des Spielers sichtbar lassen“ (Standard an): Die Plakette bleibt normal sichtbar, der Affe sitzt darüber. Ausgeschaltet bleibt nur der Affe, wie bisher.
- **Affe ohne Namensbalken (0.4.4):** Forever kennt die Spieleinstellung `nameplateShowFriends` nicht (Messung: Wert nil), deshalb blieben die Balken freundlicher Spieler aus und der Affe war nur mit von Hand eingeschalteten Balken sichtbar. Jetzt wird `nameplateShowFriendlyPlayers` zuerst probiert, danach die älteren Namen; `/fwguild stats` zeigt, was geprüft wurde. Außerdem: Positionen anderer Karten (andere Zone) erscheinen nicht auf deiner Karte, das ist gewollt.
- **Messzeilen (0.4.3):** `/fwguild stats` zeigt zusätzlich, wie viele Positionsmeldungen ankommen (und von wem), die eigene Position, die Karten-ID, wie viele Symbole auf Weltkarte und Minimap gezeichnet werden und was der Affe über dem Kopf mit den Namensbalken macht. Nur Ausgabe, am Verhalten ändert sich nichts.
- **Dungeons ohne Bossliste (0.4.2):** Krol'dok-Festung (40-55), Alcaz-Gefängnis (48-53), Schwarzmaulfeste (55-60) und Terrasse des Formers (58-60) stehen in der Übersicht mit dem Hinweis „Bossliste noch nicht bekannt, es wird auf Daten gewartet“. Besiegte Bosse werden mit Namen gespeichert, mit der Gilde geteilt und erscheinen automatisch in der Liste.
- **Dungeon Browser (0.5.0):** New tab in the guild window. The module listens in on the game's group finder (`C_LFGList`: sign up, remove, group changes) and tells the guild who is searching for what: hidden for everyone with Freewood-Guild (message `L`) and optionally (checkbox, default on) as a line in guild chat ("[Freewood] Pinky is looking for Deadmines as Damage.", at most one per minute). The tab lists all searchers per dungeon with roles and, for groups, what they have and what is missing; plus a group suggestion (1 tank, 1 healer, 3 damage, multi-role players are spread so the group gets full) with a "Invite group" button: only the one who signed up first invites. Two checkboxes (default off) accept invites from guild members and from friends automatically, but only while you are searching yourself and are not in a group. Command `/fwdungeon`. The basis comes from the `/fwlfg` probe (Freewood-Dev 0.13.5 to 0.13.8); the dungeon name and the roles when signing up are still unverified in game.
- **Health bar with the icon (0.4.5):** New setting "Keep the health bar and name of the player visible" (default on): the plate stays visible as normal and the icon sits above it. Off keeps only the icon, as before.
- **Head icon without name plates (0.4.4):** Forever does not know the setting `nameplateShowFriends` (measured: nil), so the friendly-player plates stayed off and the icon only showed with plates switched on by hand. `nameplateShowFriendlyPlayers` is now tried first, then the older names; `/fwguild stats` shows what was checked. Also: positions on other maps (another zone) do not appear on your map, by design.
- **Diagnostic lines (0.4.3):** `/fwguild stats` also shows how many position messages arrive (and from whom), your own position, the map ID, how many icons are drawn on the world map and minimap and what the head icon does with the name plates. Output only, behaviour is unchanged.
- **Dungeons without a boss list (0.4.2):** Krol'dok Stronghold, Alcaz Island Prison, Blackmaw Hold and Shaper's Terrace are listed with a "waiting for data" note; bosses you defeat are stored by name, shared and shown automatically.
- **Neue Forever-Dungeons (0.4.1):** Halle der Thane, Ruinen von Lordaeron, Ausgrabungsstätte: Sumpfland, Stadt Dalaran und Die versunkene Stadt stehen jetzt in der Instanzübersicht und bei den Erfolgen (Dungeon-, Gildenwissen-Erfolge). Bisherige Kills unter „*Ruinen von Lordaeron“ werden beim Anmelden übernommen (auch deutsche Bossnamen wie „Der Schlächter“ = The Baron). Krol'dok-Festung, Alcaz-Gefängnis, Schwarzmaulfeste und Terrasse des Formers fehlen noch (keine Bossliste bekannt); sie erscheinen dynamisch, sobald jemand dort einen Boss besiegt. Endboss von Lordaeron ist geraten (Baron oder Hauptmann).
- **New Forever dungeons (0.4.1):** Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran and The Drowned City are now in the instance overview and the achievements. Old kills stored as "*Ruinen von Lordaeron" are migrated on login. Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and Shaper's Terrace are missing (no boss list known); they show up dynamically once someone kills a boss there. The Lordaeron final boss is a guess (Baron or Captain).
- **Erfolge (0.4.0):** Neuer Reiter „Erfolge“ im Gilden-Fenster. Die Gilde sammelt Punkte, zum Beispiel wenn mindestens 3 Gildenmitglieder in einer Gruppe den letzten Boss eines Dungeons besiegen (5 Mitglieder, 10 und 20 in Schlachtzügen geben mehr). Weitere Kategorien: Bosse (Zähler), Gildenwissen (alle Bosse einer Instanz), Mitglieder, Stufen, Berufe, Rezepte, Zeit, Vielfalt; zusammen über 120 Erfolge, aufklappbar mit Symbolen und Punkten. Jeder zählt nur seinen eigenen Anteil und teilt ihn mit der Gilde (Art „E“); die Gilde ergibt sich aus der Summe, es zählen nur Mitglieder laut Gildenliste. Die Gruppe wird über die Spieler-ID aus der Gildenliste erkannt. Ein Fenster meldet neue Erfolge (Einstellung „Fenster bei Gildenerfolgen zeigen“, auch auf der Seite), „Letzte Erfolge“ zeigt die Liste. `/fwach` zeigt die Punkte, `/fwach test` das Fenster. In den ersten 120 Sekunden nach dem Anmelden und bei alten Erfolgen (über 15 Minuten) gibt es kein Fenster. Nicht im Spiel geprüft.
- **Eigener Name:** Forever liefert Vor- und Nachnamen getrennt (`UnitName` nur „Pinky“, die Gilde sieht „Pinky Freewood“). Früher bekam deshalb jeder Spieler zwei Einträge (zum Beispiel doppelt bei den Instanzen). Seit 0.4.0 gilt der volle Name; alte Einträge werden beim Anmelden zusammengeführt.
- **Karte:** Gildenmitglieder auf der Weltkarte (Affenkopf, Gildenleiter mit Krone). In den Einstellungen ein-/ausschaltbar, eigene Position teilbar, Symbolgröße 8 bis 64 Pixel. Ab 0.3.5 auch auf der Minimap (Einstellung, Symbolgröße 8 bis 32 Pixel); die Position wird etwa alle 10 Sekunden gesendet, auf der Minimap werden die Symbole in Laufrichtung fortgeschrieben. Nicht im Spiel geprüft. Ab 0.3.6: Affensymbol (Gildenleiter mit Krone) über dem Kopf von Gildenmitgliedern, nicht beim eigenen Charakter; ein-/ausschaltbar, Größe 16 bis 64 Pixel. Es hängt an der Namensplakette: Die Einstellung „Plaketten freundlicher Spieler“ wird dafür eingeschaltet (alter Wert wird gemerkt und beim Ausschalten zurückgesetzt), das Plakettenbild bleibt ausgeblendet, nur das Symbol ist zu sehen. Nur du siehst es. Nicht im Spiel geprüft.
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
- **Achievements (0.4.0):** new “Achievements” page in the guild window. The guild collects points, for example when at least 3 guild members in one group defeat the last boss of a dungeon (5 members, and 10 and 20 in raids give more). More categories: bosses (counters), guild knowledge (every boss of an instance), members, levels, professions, recipes, time, variety; over 120 achievements in total, collapsible, with icons and points. Everyone counts only their own part and shares it with the guild (kind “E”); the guild is the sum, and only members on the guild roster count. The group is recognised by the player ID from the guild roster. A window announces new achievements (setting “Show a window for guild achievements”, also on the page), “Latest achievements” shows the list. `/fwach` prints the points, `/fwach test` shows the window. No window in the first 120 seconds after login and for old achievements (over 15 minutes). Not verified in game.
- **Own name:** Forever returns first and last name separately (`UnitName` only “Pinky”, the guild sees “Pinky Freewood”). Because of that every player used to get two entries (for example doubled in the instances). Since 0.4.0 the full name is used; old entries are merged at login.
- **Map:** guild members on the world map (monkey head, guild master with crown). Switchable in the settings, own position shareable, icon size 8 to 64 pixels. Since 0.3.5 also on the minimap (setting, icon size 8 to 32 pixels); the position is sent about every 10 seconds and the minimap icons are extrapolated along the movement. Not verified in game. Since 0.3.6: monkey icon (guild master with crown) above guild members' heads, not on your own character; switchable, size 16 to 64 pixels. It hangs on the name plate: the “friendly player name plates” game setting is turned on for it (the old value is remembered and restored when switched off), the plate picture stays hidden and only the icon shows. Only you see it. Not verified in game.
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
