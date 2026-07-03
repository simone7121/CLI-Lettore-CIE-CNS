# Procedura di rilascio

## 1. Prerequisiti legali e di progetto

- verificare che `LICENSE`, `NOTICE` e `LICENSING.md` siano inclusi e coerenti;
- conservare Simone D'Anna come titolare, salvo trasferimenti documentati;
- verificare compatibilità tra licenza del progetto, BSD 3-Clause dell'SDK e
  CC BY 4.0 dei dati ISTAT;
- rileggere `THIRD_PARTY_NOTICES.md` e includere tutti i testi necessari;
- abilitare Private vulnerability reporting nelle impostazioni GitHub.

La PolyForm Noncommercial rende il progetto source-available ma non open source
in senso OSI. Le release e la pagina GitHub devono usare questa terminologia.

## 2. Aggiornare il dataset ISTAT

1. scaricare l'elenco corrente dalla
   [fonte ISTAT](https://www.istat.it/classificazione/codici-dei-comuni-delle-province-e-delle-regioni/);
2. convertire in CSV delimitato da `;` mantenendo le colonne richieste:
   `Denominazione in italiano`, `Denominazione (Italiana e straniera)`,
   `Codice Comune formato numerico` e `Codice Catastale del comune`;
3. salvare in Windows-1252 oppure aggiornare contestualmente il decoder nello
   script;
4. verificare record, codici duplicati e comuni istituiti o soppressi;
5. registrare data di riferimento, numero record e nuovo SHA-256 in
   `THIRD_PARTY_NOTICES.md`.

La copia attuale non è allineata all'assetto in vigore dal 21 febbraio 2026 e
va sostituita prima del primo rilascio pubblico.

## 3. Verificare le dipendenze

- ricostruire `CIE.MRTD.SDK.dll` dal commit documentato applicando
  `lib/CIE.MRTD.SDK-CSPRNG.patch`, oppure documentare commit e patch nuovi;
- confrontare l'hash con `THIRD_PARTY_NOTICES.md` e con il workflow;
- revisionare gli avvisi di sicurezza dell'SDK e del Middleware CIE;
- non includere copie di lavoro, log o dati acquisiti.

## 4. Qualità e test

- completare [la matrice di test](TESTING.md) senza dati personali;
- verificare Windows PowerShell 5.1 e PowerShell 7 su Windows;
- controllare i tre percorsi CNS, CIE MRTD e CIE IAS;
- eseguire parser, PSScriptAnalyzer e workflow GitHub;
- aggiornare README, limiti, privacy, changelog e note di rilascio.

## 5. Pacchetto

Il pacchetto deve contenere soltanto:

```text
LettoreCNS.ps1
Elenco-comuni-italiani.csv
Elenco-comuni-italiani.csv.license
README.md
LICENSE
LICENSING.md
NOTICE
THIRD_PARTY_NOTICES.md
lib/CIE.MRTD.SDK.dll
lib/CIE.MRTD.SDK.dll.license
lib/CIE.MRTD.SDK-CSPRNG.patch
lib/CIE.MRTD.SDK-CSPRNG.patch.license
lib/LICENSE-CIE-MRTD-SDK.txt
docs/
```

Creare l'archivio da un checkout pulito e pubblicare SHA-256 dell'archivio e
dei binari. Non generarlo dalla cartella di lavoro, che può contenere MSI e
backup ignorati.

## 6. Versione e pubblicazione

1. spostare le voci di `Unreleased` in una sezione `X.Y.Z` datata;
2. creare un commit di release e un tag annotato `vX.Y.Z`;
3. creare una GitHub Release dal tag;
4. allegare archivio, checksum e note con test e limitazioni;
5. installare l'archivio su una macchina pulita e ripetere uno smoke test.
