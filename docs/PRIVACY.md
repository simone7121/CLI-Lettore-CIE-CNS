# Privacy e trattamento dei dati

## Dati trattati

In base al documento e al profilo disponibile, il programma può leggere e
mostrare nome, cognome, codice fiscale, sesso, data e luogo di nascita,
residenza, cittadinanza, statura, numero documento, emittente, autorità di
rilascio e date di validità. CAN e PIN sono usati come credenziali di accesso
alla CIE; il PUK non viene richiesto.

## Dove transitano i dati

- la lettura avviene localmente tra carta, lettore, driver, processo PowerShell
  ed eventuale Middleware CIE;
- `LettoreCNS.ps1` non contiene chiamate HTTP, telemetria o aggiornamenti
  automatici;
- il risultato viene scritto nella console e non in un file;
- il CSV ISTAT è consultato localmente;
- nel percorso IAS, il Middleware CIE può abilitare la carta nel profilo utente
  e rendere disponibile il relativo certificato nello store Windows.

La mancata persistenza da parte dello script non impedisce a terminali,
strumenti di registrazione, clipboard, redirect PowerShell, software di
assistenza remota, antivirus o processi privilegiati di acquisire l'output.

## PIN e CAN

L'input è mascherato con `Read-Host -AsSecureString`. Per interoperare con SDK e
middleware, i valori sono convertiti temporaneamente in memoria. La memoria BSTR
usata nella conversione viene azzerata prima del rilascio; le successive stringhe
gestite dal runtime non possono essere garantite come immediatamente azzerate.
Lo script elimina i riferimenti appena conclusa l'operazione ma non protegge da
una postazione compromessa o da un dump di memoria.

## Uso corretto

- ottenere il consenso del titolare e rispettare la base giuridica applicabile;
- usare una postazione aggiornata, non condivisa e priva di registrazione
  automatica della sessione;
- evitare redirect come `> output.txt`, trascrizioni PowerShell e screenshot;
- chiudere la console dopo l'uso e rimuovere eventuali copie create manualmente;
- non usare dati reali in test, issue o pull request;
- non conservare più dati di quelli necessari allo scopo dichiarato.

Il titolare o gestore del progetto deve definire autonomamente ruoli, base
giuridica, informative e tempi di conservazione per ogni utilizzo operativo. Il
repository non costituisce da solo una soluzione di conformità normativa.
