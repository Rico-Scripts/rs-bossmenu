# rs-bossmenu

Standalone RS baasmenu voor ESX Legacy. Geen `esx_society` nodig.

## Functies
- Bedrijfsbalans
- Medewerkers bekijken
- Nabije speler aannemen op server ID
- Rang wijzigen
- Offline medewerkers beheren
- Ontslaan
- Storten/opnemen
- SQL logboek
- Discord webhook logging

## Dependencies
- es_extended
- ox_lib
- oxmysql

## Installatie
1. Importeer `install.sql`.
2. Stel eventueel `Config.Webhook` in.
3. Start resource na ESX/oxmysql.
4. Open vanuit jobscreator:
   `TriggerClientEvent('rs-bossmenu:client:open', source, jobName)`

## Let op
Standaard mag alleen een ESX grade met `name = 'boss'` openen.
