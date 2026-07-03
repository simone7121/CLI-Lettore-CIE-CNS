# Risoluzione dei problemi

## Lo script non parte

Verificare versione e architettura della shell:

```powershell
$PSVersionTable
[Environment]::Is64BitProcess
```

Eseguire dalla radice del progetto. Se compare un errore di execution policy,
controllare la policy effettiva:

```powershell
Get-ExecutionPolicy -List
```

Non disabilitare permanentemente le policy aziendali. Se il file proviene da
una fonte attendibile, verificarlo e usare `Unblock-File` come indicato nel
README.

## Nessun lettore rilevato

Controllare il servizio Smart Card:

```powershell
Get-Service SCardSvr
```

Se arrestato, avviarlo da una sessione autorizzata:

```powershell
Start-Service SCardSvr
```

Poi verificare collegamento USB, Gestione dispositivi e driver del produttore.
Un lettore solo CCID a contatto non può leggere una CIE contactless.

## Nessuna carta o carta rimossa

- per CNS/TS-CNS inserire completamente il chip nel verso corretto;
- per CIE appoggiare la carta sull'area NFC e non spostarla;
- chiudere browser, middleware o altri programmi che possano detenere la carta;
- dopo un reset, allontanare la CIE per alcuni secondi e riappoggiarla;
- provare una porta USB diretta evitando hub non alimentati.

## Errore di condivisione o modalità esclusiva

Un altro processo sta usando il lettore. Chiudere applicazioni di firma,
browser, CieID e strumenti diagnostici. Se necessario, scollegare e ricollegare
il lettore dopo aver chiuso i processi interessati.

## SDK CIE non trovato o non caricabile

Verificare presenza e hash:

```powershell
Test-Path .\lib\CIE.MRTD.SDK.dll
Get-FileHash .\lib\CIE.MRTD.SDK.dll -Algorithm SHA256
```

Il valore previsto è pubblicato in `THIRD_PARTY_NOTICES.md`. Non scaricare DLL
con lo stesso nome da siti non ufficiali.

## CIE IAS e Middleware CIE

Se viene segnalata l'assenza di `CIEPKI.dll`, installare il Middleware CIE dalla
[pagina ufficiale](https://www.cartaidentita.interno.gov.it/pa-e-imprese/documentazione-middleware-cie/)
e riaprire la shell. PIN errati riducono i tentativi disponibili; non riprovare
alla cieca. In caso di PIN bloccato usare i canali ufficiali e il PUK, non questo
programma.

## CAN non accettato o PACE fallita

Il CAN è composto da 6 cifre ed è stampato sul fronte della CIE. Non coincide
con PIN o PUK. Verificare le cifre, mantenere stabile la carta e riprovare una
sola volta prima di cambiare lettore o driver.

## Comune non risolto o non aggiornato

Il dato anagrafico letto resta disponibile, ma la denominazione derivata può
mancare o essere storica se il CSV ISTAT è obsoleto. Consultare
`THIRD_PARTY_NOTICES.md` e aggiornare il dataset seguendo `docs/RELEASING.md`.

## Aprire una segnalazione

Seguire [SUPPORT.md](../SUPPORT.md). Rimuovere ogni dato personale dal messaggio
e non allegare dump, certificati o trace APDU di carte reali.
