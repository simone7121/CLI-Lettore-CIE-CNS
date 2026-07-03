# Lettore CIE e CNS

Utility PowerShell per Windows che rileva una CNS, una TS-CNS o una Carta
d'Identità Elettronica e ne mostra a console i dati anagrafici disponibili.

> [!IMPORTANT]
> Il programma tratta dati personali e dati identificativi. Usarlo solo con il
> consenso del titolare del documento e su una postazione attendibile. Non
> allegare output reali a issue, log o screenshot pubblici.

Il progetto è indipendente e non è un prodotto ufficiale del Ministero
dell'Interno, di IPZS o di ISTAT.

## Funzionalità

| Documento | Modalità di lettura | Credenziale | Dati principali |
| --- | --- | --- | --- |
| CNS / TS-CNS | `EF.DatiPersonali` tramite PC/SC | Nessuna | dati anagrafici esposti dalla carta |
| CIE 3.0 MRTD | PACE, Chip Authentication, DG1/DG11/DG12 | CAN di 6 cifre | dati anagrafici, documento e residenza disponibili nei Data Group |
| CIE 3.0 IAS | certificato X.509 del Middleware CIE | PIN completo di 8 cifre alla prima abilitazione | nome, cognome, codice fiscale, numero documento, cittadinanza e validità |

Il percorso IAS non legge residenza, fotografia o impronte. Il programma non
scrive sulla carta, non salva automaticamente l'output e non effettua richieste
di rete.

## Requisiti

- Windows 10 o 11;
- Windows PowerShell 5.1 oppure PowerShell 7 per Windows;
- servizio Windows **Smart Card** (`SCardSvr`) attivo;
- driver PC/SC del lettore;
- lettore a contatto per CNS/TS-CNS;
- lettore contactless PC/SC compatibile ISO/IEC 14443 A/B per CIE;
- per le CIE che espongono solo l'applicazione IAS, il
  [Middleware CIE ufficiale](https://www.cartaidentita.interno.gov.it/pa-e-imprese/documentazione-middleware-cie/).

OpenSC non è una dipendenza del programma. Installarlo solo se richiesto dal
produttore della carta o da un altro flusso applicativo.

## Installazione

Clonare il repository o scaricare un archivio dalla pagina **Releases**. I file
seguenti devono restare nella stessa struttura:

```text
LettoreCNS.ps1
Elenco-comuni-italiani.csv
lib/
  CIE.MRTD.SDK.dll
```

Prima dell'esecuzione, esaminare lo script e verificare i file distribuiti:

```powershell
Get-FileHash .\LettoreCNS.ps1, .\Elenco-comuni-italiani.csv, .\lib\CIE.MRTD.SDK.dll -Algorithm SHA256
```

Se Windows blocca uno script scaricato, sbloccarlo solo dopo averne verificato
origine e contenuto:

```powershell
Unblock-File .\LettoreCNS.ps1
```

Non è necessario avviare la shell come amministratore.

## Utilizzo

Da Windows PowerShell:

```powershell
.\LettoreCNS.ps1
```

Da PowerShell 7:

```powershell
pwsh -NoProfile -File .\LettoreCNS.ps1
```

In presenza di più lettori, il programma prova quelli disponibili. È possibile
selezionarne uno dal menu oppure specificarne il nome PC/SC completo:

```powershell
.\LettoreCNS.ps1 -ReaderName "Nome lettore PC/SC"
```

Durante la lettura CIE:

1. mantenere la carta ferma sul lettore NFC;
2. inserire il CAN stampato sul fronte se viene rilevato il profilo MRTD;
3. inserire il PIN completo solo se viene rilevato il profilo IAS e il
   Middleware CIE deve abilitare la carta.

CAN e PIN sono richiesti con input mascherato. Il percorso IAS può registrare
la CIE nel profilo Windows tramite il middleware ufficiale.

## Documentazione

- [Architettura e flussi](docs/ARCHITECTURE.md)
- [Privacy e trattamento dei dati](docs/PRIVACY.md)
- [Risoluzione dei problemi](docs/TROUBLESHOOTING.md)
- [Test e verifiche](docs/TESTING.md)
- [Dipendenze e provenienza](THIRD_PARTY_NOTICES.md)
- [Ambito e gerarchia delle licenze](LICENSING.md)
- [Supporto](SUPPORT.md)
- [Contribuire](CONTRIBUTING.md)
- [Accordo per contributori](CONTRIBUTOR_LICENSE_AGREEMENT.md)
- [Codice di condotta](CODE_OF_CONDUCT.md)
- [Policy di sicurezza](SECURITY.md)
- [Procedura di rilascio](docs/RELEASING.md)
- [Changelog](CHANGELOG.md)

## Limiti noti

- il funzionamento dipende da carta, firmware del lettore e driver PC/SC;
- non è implementata la Passive Authentication del file `EF.SOD`;
- il dataset ISTAT incluso è usato solo per risolvere i codici dei comuni e deve
  essere aggiornato periodicamente;
- i test automatici non possono sostituire le prove con carte di test e lettori
  reali;
- il progetto non fornisce funzioni di firma, autenticazione verso servizi o
  verifica legale dell'identità.

## Licenza

Copyright © 2026 Simone D'Anna.

Il codice e la documentazione originali sono distribuiti secondo la
[PolyForm Noncommercial License 1.0.0](LICENSE). Sono consentiti gli usi non
commerciali previsti dalla licenza; qualsiasi uso commerciale richiede il
consenso preventivo e scritto del titolare, contattabile all'indirizzo
`dev@simonedanna.it`.

Questa licenza è **source-available** e non è una licenza open source approvata
OSI. SDK e dati di terze parti non sono soggetti alla restrizione non
commerciale e mantengono rispettivamente BSD-3-Clause e CC-BY-4.0. Ambito,
prevalenza e obblighi di ridistribuzione sono definiti in
[LICENSING.md](LICENSING.md).
