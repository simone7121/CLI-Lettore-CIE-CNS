# Sicurezza

## Versioni supportate

Finché non esistono release stabili, riceve correzioni di sicurezza soltanto il
branch `main`. Dopo il primo rilascio saranno supportate la versione più recente
e `main`; le versioni precedenti non riceveranno correzioni salvo indicazione
esplicita nelle note di rilascio.

## Segnalare una vulnerabilità

Non aprire una issue pubblica per vulnerabilità, esposizione di dati personali,
errori nella gestione di PIN/CAN o problemi crittografici.

Usare **Security > Report a vulnerability** nel repository GitHub. Se il canale
non è disponibile, scrivere a `dev@simonedanna.it` con oggetto
`[SECURITY CNSCTS]`. Non inviare mai dati anagrafici, PIN, CAN,
certificati personali, dump di memoria o tracce APDU di carte reali.

La segnalazione dovrebbe contenere, in forma anonimizzata:

- versione o commit interessato;
- prerequisiti e impatto;
- procedura minima di riproduzione;
- ambiente Windows, versione PowerShell e modello del lettore;
- proposta di mitigazione, se disponibile.

Il maintainer confermerà la ricezione, valuterà impatto e riproducibilità e
coordinerà la divulgazione dopo la disponibilità di una correzione. Non è
garantito un tempo di risposta finché il progetto non dichiara maintainer e SLA.

## Modello di sicurezza

Il programma opera localmente e non fornisce isolamento da una postazione già
compromessa. Un processo con privilegi sufficienti può osservare memoria,
console, certificati o chiamate al middleware. Eseguire il programma soltanto su
computer attendibili e con dipendenze verificate.
