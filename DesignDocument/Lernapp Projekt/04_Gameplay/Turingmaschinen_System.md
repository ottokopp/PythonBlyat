## Ablauf  
- Aufgabe wird angezeigt  
- Nutzer bewegt den Cursor über das Spielfeld  
- Ziel der Aufgabe ist es, ein bestimmtes Feld oder Muster zu erreichen  
- System überprüft die Lösung  
  
## Elemente  
- Raster (Spielfeld aus Vierecken)  
- Cursor (aktuelle Position)  
- Steuerbuttons (oben, unten, links, rechts)  
- Aufgabenbeschreibung  
  
## Funktionen  
- Bewegung des Cursors  
- Interaktion mit dem Spielfeld  
- Überprüfung der Zielbedingung  
- Anzeige von Erfolg oder Fehler

### Ausgangssituation  
  
Band:  
[ 0 ][ 1 ][ 1 ][ 0 ][ _ ]  
  
Cursor (Kopf) zeigt auf das erste Feld.  
  
## Aufgabe A – Inverter  
  
### Beschreibung  
Gehe über das Band und kehre alle Werte um:  
  
- aus 0 wird 1  
- aus 1 wird 0  
- bei einem leeren Feld (_) wird gestoppt  
  
### Ablauf  
- Lies aktuelles Feld  
- Wenn 0 → schreibe 1 → gehe nach rechts  
- Wenn 1 → schreibe 0 → gehe nach rechts  
- Wenn _ → STOP  
  
### Darstellung  
  
Start:  
[ 0 ][ 1 ][ 1 ][ 0 ][ _ ]  
↑  
  
Schritt 1:  
[ 1 ][ 1 ][ 1 ][ 0 ][ _ ]  
↑  
  
Schritt 2:  
[ 1 ][ 0 ][ 1 ][ 0 ][ _ ]  
↑  
  
...  
  
→ Ergebnis:  
[ 1 ][ 0 ][ 0 ][ 1 ][ _ ]  
  
---  
  
## Aufgabe B – Zählen  
  
### Beschreibung  
Alle 1 werden zu 0 gemacht.  
Am Ende wird eine 1 hinzugefügt, um die Anzahl zu markieren.  
  
### Ablauf  
- Gehe von links nach rechts  
- Ersetze jede 1 durch 0  
- Wenn _ erreicht → schreibe 1 → STOP  
  
---  
  
## Aufgabe C – Markieren  
  
### Beschreibung  
Ein Band wie [0][0][0] ist gegeben.  
Die mittlere 0 soll durch ein "X" ersetzt werden.  
  
### Ablauf  
- Gehe nach rechts bis zum Ende (_)  
- Gehe einen Schritt zurück  
- Markiere das Feld mit X  
  
### Darstellung  
  
Start:  
[ 0 ][ 0 ][ 0 ]  
  
Ende:  
[ 0 ][ X ][ 0 ]

[[Levelübersicht]]  
[[Ergebnisbildschirm]]
