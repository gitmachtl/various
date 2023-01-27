
## JSON Files

### config.json - Grundkonfiguration

In der config.json werden grundlegende Einstellungen vorgenommen wie der Lizenzeintrag, Name, Anzahl der Punkte innerhalb/ausserhalb eines Wegpunktes...

Beispiel *config.json*:
``` json
{
  "license": "5f41a85861175e8ad0ab0a8ae945c59c",
  "name": "Super Boot #1",
  "gpsdHost": "127.0.0.1",
  "gpsdPort": 2947,
  "systemsounds": {
    "start": "system_start.mp3",
    "gps_receive": "gps_receive.mp3",
    "gps_disconnect": "gps_disconnected.mp3"
  },
  "wpInConfirm": 3,
  "wpOutConfirm": 3,
  "wpOutExtraRadius": 2,
  "wpHeadingDiff": 20,
  "gpsHAccLow": 10,
  "gpsHAccHigh": 20,
  "gpsHeadingMinSpeed": 2,
  "debug": false
}
```

Beschreibung:

| **Eintrag** | **Beschreibung** | **Beispiel / Default** |
|------|------|------|
| license | Lizenz-String für das aktuelle System, wird von MEB Veranstaltungstechnik GmbH bereitgestellt | `5f41a85861175e8ad0ab0a8ae945c59c`| 
| name | Anzeigename für das System zur Information | `Super Boot` |
| gpsdHost | IP-Adresse/Hostname vom GPS-Daemon | `127.0.0.1` |
| gpsdPort | Port-Nummer des GPS-Daemon | `2947` |
| systemsounds start | Audiofile, welches beim Start des Systems abgespielt werden soll. | `system_start.mp3`<br>`""` für kein Audiofile |
| systemsounds gps_receive | Audiofile, welches beim Empfang von GPS-Daten abgespielt werden soll. Es müssen GPS-Daten empfangen werden, welche gültig und genau genug sind um das Abspielen auszulösen. | `gps_receive.mp3`<br>`""` für kein Audiofile| 
| systemsounds gps_disconnect | Audiofile, welches bei einer Unterbrechnung zum GPS-Daemon abgespielt werden soll. | `gps_disconnected.mp3`<br>`""` für kein Audiofile |
| wpInConfirm| Anzahl der GPS-Punkte innerhalb eines Wegpunkt-Kreises mit Durchmesser `radius` zur Aktivierung `entered` des Wegpunktes | `3` |
| wpOutConfirm | Anzahl der GPS-Punkte ausserhalb eines Wegpunkt-Kreises mit Durchmesser `radius+wpOutExtraRadius` zur Deaktivierung `exited` des Wegpunktes |  `2` |
| wpOutExtraRadius | Zusätzlicher Radius[m] des Wegpunkt-Kreise, welcher die Aussengrenze des Wegpunktes darstellt. Wenn der GPS-Empfänger genau an der Radius Grenze verweilt, kann es zu mehrfachen `entered` und `exited` Events kommen, ein zusätzlicher Radius `wpOutRadius` verhindert dies. | 2 [m] |
| wpHeadingDiff | Bei den Wegpunkten kann auch eine Fahrtrichtung zur Aktivierung angegeben werden, `wpHeadingDiff` stellt den Winkel in Grad ein, wie weit dieser Winkel (+/-) vom tatsächlichen Winkel abweichen darf. Bsp.: Wegpunkt-Winkel = 50°, wpHeadingDiff = 20°. Der Wegpunkt kann in einem Winkel zwischen 30°-70° angefahren werden. | 20 [°] |
| gpsHAccLow| HorizontalAccuracyLow - Gibt den Genaugigkeits-Wert[m] vor, ab welchem die empfangenen GPS-Daten als "genau genug" eingestuft werden. | 10 [m] |
| gpsHAccHigh| HorizontalAccuracyHigh - Gibt den Genaugigkeits-Wert[m] vor, ab welchem die empfangenen GPS-Daten als zu "ungenau" eingestuft werden. | 20 [m] |
| gpsHeadingMinSpeed | Gibt die minimale Fahrgeschwindigkeit vor, ab welcher der empfangene Richtungswinkel `heading` akzeptiert wird. Drifftet z.B. ein Boot langsam zurück, so verhindert dieser Wert ein Falschmeldung | 2 [km/h] |
| debug | Schaltet den Debug-Modus direkt beim Systemstart ein (true) oder aus (false). | false |


### waypoints.json - Wegpunkte Beschreibung

Beispiel *waypoints.json*:
``` json
[
  {
    "id": "000",
    "name": "HomeBase",
    "lat": 58.2521858,
    "lon": 24.3645904,
    "radius": 25,
    "enabledAfterID": [
	      "every"
    ],
    "enterPlay": "",
    "exitPlay": ""
  },
  {
    "id": "010",
    "name": "Attraction No.1",
    "lat": 58.3521844,
    "lon": 24.652349,
    "radius": 15,
    "enabledAfterID": [
      "000"
    ],
    "enterPlay": "sounds/attraction_no01.mp3",
    "exitPlay": ""
  },
  {
    "id": "020",
    "name": "Some other place",
    "lat": 58.1528209,
    "lon": 15.3667251,
    "radius": 60,
    "enabledAfterID": [
      "010"
    ],
    "invertAfterID": false,
    "enabledHeading": 200,
    "invertHeading": true,
    "enterPlay": "",
    "exitPlay": "sounds/another_place.mp3"
  }
]
```

Das *waypoints.json* file besteht aus einer Auflistung `array` von allen Wegpunkten und deren Auslösungs Kriterien.

Die folgenden Parameter sind zwingend für jeden Wegpunkt anzuführen:

| **Eintrag** | **Beschreibung** | **Typ** | **Beispiel / Default** |
|------|------|------|-----|
| id | Eindeutige Wegpunkt-ID. Mindestlänge 1 Zeichen, Maximallänge 4 Zeichen. Jede ID darf nur einmal vorkommen. | string | `000`, `010`, `010a`, `010b` |
| name | Bezeichnung/Name des Wegpunktes. Min. 0 Zeichen lang (leer), max. 40 Zeichen lang. | string | `Attraction No.1` |
| lat | Latitude GPS-Koordinate in Grad°. Kann z.B. direkt von Google-Maps kopiert werden. | decimal number | `58.2521858` |
| lon | Longitude GPS-Koordinate in Grad°. Kann z.B. direkt von Google-Maps kopiert werden. | decimal number | `15.3667251` |
| radius | Radius des Wegpunktes, der Mittelpunkt wird durch die GPS-Koordinaten `lat` und `lon` bestimmt. Der Radius zählt immer für das Einfahren in den Wegpunkt. Beim Verlassen wird zusätzlich auch noch der Parameter `wpOutExtraRadius` der `config.json` berücksichtigt. | number | `20` [m] |

Die folgenden Parameter sind optional:

| **Eintrag** | **Beschreibung** | **Typ** | **Beispiel / Default** |
|------|------|------|-----|
| enabledAfterID | Freischaltung des Wegpunktes nach der zuletzt aktivieren ID. Hier kann das keyword "every" angegeben werden, eine oder mehrere IDs. Zur Freischaltung/Sperrung wird immer die ID des zuletzt aktivierten(`entered`) Wegpunktes herangezogen. Eine Freischaltung ermöglicht das Einfahren in diesen Wegpunkt um diesen auszulösen `entered`, eine Freischaltung/Sperrung ist noch keine Aktivierung. | array of strings | `[ "000", "010" ]`<br>`[ "every" ]` |
| invertAfterID | Invertiert die Angaben von Punkt `enabledAfterID`. Wird z.B. unter `enabledAfterID` der Wegpunkt `000` angegeben, und `invertAfterID: true` gesetzt, dann ist der Wegpunkt immer freigeschaltet, ausser wenn als letztes Ereignis der Wegpunkt `000` aktiviert wurde. | boolean | `true`, `false` |
| enabledHeading | Freischaltung des Wegpunktes erfolgt, wenn sich der GPS-Empfänger in die angegebene Fahrtrichtung bewegt. Hierfür muß die Mindestgeschwindigkeit erreicht werden, welche in der `config.json` als Parameter `wpHeadingMinSpeed` angegeben ist. Wie weit die aktuelle Fahrtrichtung vom angegebenen Wert abweichen darf, stellt der Parameter `wpHeadingDiff` in der `config.json` ein. Wichtig - Ist auch ein Eintrag in `enabledAfterID` vorhanden, so müssen beide Bedingungen erfüllt sein. | number | `0-360` [°] |
| invertHeading | Invertiert die Angaben von Punkt `enabledHeading`. Wird z.B. unter `enabledHeading` eine Fahrrichtung von 200° angegben, und `invertHeading: true` gesetzt, dann ist der Wegpunkt immer freigeschaltet, ausser der GPS-Empfänger bewegt sich in Fahrtrichtung 200°. | boolean | `true`, `false` |
| enterPlay | Pfad zum Audiofile, welches beim Einfahren `entered` in den Wegpunkt abgespielt werden soll. In einen Wegpunkt kann nur eingefahren werden, wenn dieser zuvor auch freigeschaltet wurde. | string | `sounds/testtrack1.mp3`<br>`""` für kein Audiofile |
| exitPlay | Pfad zum Audiofile, welches beim Verlassen `exited` des Wegpunkt abgespielt werden soll. Wurde in einen Wegpunkt eingefahren, so bleibt dieser automatisch freigeschaltet bis der Wegpunkt wieder verlassen wurde. | string | `sounds/byebye_attraction_no2.mp3`<br>`""` für kein Audiofile |

<p>&nbsp;</p>

## Command Syntax

Wegpunkte können innerhalb GpsTalker mittels eigener Syntax editiert werden, hierfür stehen folgende Befehle zur Verfügung:

| **Command** | **Beschreibung** | **Beispiel** |
|------|------|------|
|load waypoints| Lädt die *waypoints.json* Datei neu ein.<br>Dies ist sinnvoll falls geänderte Werte zurückgesetzt werden sollen. | `load waypoints` |
|save waypoints| Speichert die aktuellen Wegpunktdaten in die *waypoints.json* Datei. | `save waypoints` |
|waypoint `id` show|  Zeigt die aktuell eingestellten Daten für den Wegpunkt `id` an.|`waypoint 000 show`|
|waypoint `id` new|  Legt einen neuen Wegpunkt mit der ID `id` an und setzt direkt die aktuellen GPS Koordinaten.|`waypoint 030 new`|
|waypoint `id` new `lat` `lon`| Legt einen neuen Wegpunkt mit der ID `id` an und verwendet dafür die angegebene GPS Koordinaten.|`waypoint 120 new 45.1234 15.1234`|
|waypoint `id` gps|  Setzt die aktuellen GPS Koordinaten für den Wegpunkt mit der ID `id`.|`waypoint 050 gps`|
|waypoint `id` gps `lat` `lon`| Setzt die angegebene GPS Koordinaten für den Wegpunkt mit der ID `id`.|`waypoint 060a new 45.1234 15.1234`|
|waypoint `id` name `name`| Legt den Namen `name` für den Wegpunkt mit der ID `id` fest.<br>Die max. Länge des Namens sind 40 Zeichen.|`waypoint 000 name My Home`|
|waypoint `id` radius `radius`| Legt den Radius für den Wegpunkt mit der ID `id` fest. Die Angabe erfolgt in Meter, min. Radius sind 5m.|`waypoint 120 radius 25`|
|waypoint `id` after `id1, ...idx`| Gibt an, nach welchem letzten aktivierten Wegpunkt `id1, ...idx` der Wegpunkt `id` freigeschaltet werden soll.<br>Das Keyword `every` kann verwendet werden, um damit alle möglichen IDs einzuschließen. ACHTUNG - Falls vorhanden, muß auch gleichzeitig die Bedingung von `heading` bzw. `notheading` erfüllt sein.|`waypoint 120 after 030,050`<br>`waypoint 000 after every`|
|waypoint `id` notafter `id1, ...idx`| Wie der Befehl `after` nur invertiert.|`waypoint 030 notafter 050`|
|waypoint `id` heading `angle`| Gibt an in welcher Fahrtrichtung 0-360° der Wegpunkt freigeschaltet werden soll. 0° entspricht Richtung Norden, 90° Richtung Osten, 180° Richtung Süden und 270° Richtung Westen. ACHTUNG - Es muß auch gleichzeitig die Bedingung von `after` bzw. `notafter` erfüllt sein. |`waypoint 120 heading 90`|
|waypoint `id` notheading `angle`| Wie der Befehl `heading` nur invertiert.|`waypoint 030 notheading 235`|
|waypoint `id` enterplay| Spielt das Audiofile von Wegpunkt `id` ab, welches für das Einfahren eingestellt ist.|`waypoint 010 enterplay`|
|waypoint `id` enterplay `pathToAudiofile`| Legt das Audiofile fest, welches beim Einfahren in den Wegpunkt `id` abgespielt werden soll.|`waypoint 010 enterplay sounds/hello_welcome.mp3`|
|waypoint `id` enterplay delete| Löscht den Audiofile Eintrag für den Wegpunkt `id` beim Einfahren.|`waypoint 010 enterplay delete`|
|waypoint `id` exitplay| Spielt das Audiofile von Wegpunkt `id` ab, welches für das Verlassen eingestellt ist.|`waypoint 120 exitplay`|
|waypoint `id` exitplay `pathToAudiofile`| Legt das Audiofile fest, welches beim Verlassen des Wegpunktes `id` abgespielt werden soll.|`waypoint 120 exitplay sounds/byebye.mp3`|
|waypoint `id` exitplay delete| Löscht den Audiofile Eintrag für den Wegpunkt `id` beim Verlassen.|`waypoint 010 enterplay delete`|
|waypoint `source-id` copy `dest-id`| Kopiert alle aktuellen Einstellungen von Wegpunkt `source-id` und kopiert diese mit der neuen ID `dest-id`.|`waypoint 000 copy 001`|
|waypoint `source-id` move `dest-id`| Ändert die ID des Wegpunktes `source-id` auf die neue ID `dest-id`.|`waypoint 010 move 010a`|
|restart|Startet die GpsTalker Applikation neu|`restart`|
|quit<br>exit|Beendet die GpsTalker Applikation|`quit`|


