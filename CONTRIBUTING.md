# Contribuire

## Prima di iniziare

Per bug e proposte usare i template delle issue. Per vulnerabilità o problemi
che coinvolgono dati personali seguire invece [SECURITY.md](SECURITY.md) e non
pubblicare dettagli sensibili.

Le modifiche alla gestione di PIN, CAN, APDU, PACE, Chip Authentication,
interop nativo o certificati richiedono una motivazione tecnica, riferimenti
alle specifiche applicabili e test su hardware controllato.

## Sviluppo

1. creare un branch da `main`;
2. limitare ogni pull request a un cambiamento coerente;
3. conservare la compatibilità con Windows PowerShell 5.1, salvo decisione
   esplicita e documentata;
4. non introdurre download automatici, telemetria o persistenza di dati
   anagrafici senza una revisione di sicurezza e privacy;
5. aggiornare README, documenti e changelog quando cambia il comportamento;
6. eseguire i controlli descritti in [docs/TESTING.md](docs/TESTING.md).

## Licenza dei contributi

Il progetto usa un modello con licenza pubblica non commerciale e possibilità
di licenze commerciali separate. Per non rendere impossibile al titolare
concedere tali autorizzazioni, ogni contributo deve rispettare
[l'accordo per contributori](CONTRIBUTOR_LICENSE_AGREEMENT.md).

Inviando una pull request e selezionando la relativa conferma, il contributore
dichiara di avere letto e accettato l'accordo. Se il contributo incorpora
materiale di terzi, deve identificarlo e dimostrare che la relativa licenza ne
consente l'inclusione. L'accordo riguarda solo i diritti effettivamente
posseduti dal contributore e non modifica le licenze dei componenti terzi.

## Stile PowerShell

- usare nomi `Verbo-Sostantivo` per le funzioni;
- preferire parametri nominati nei punti in cui migliorano la leggibilità;
- rilasciare handle, memoria non gestita, certificati e connessioni in blocchi
  `finally`;
- validare lunghezze, codici di stato e input prima dell'uso;
- mantenere i messaggi utente in italiano;
- non stampare PIN, CAN, APDU sensibili o dati grezzi del documento;
- evitare dipendenze aggiuntive quando le API di Windows sono sufficienti.

## Pull request

La descrizione deve indicare:

- problema e soluzione;
- impatto su sicurezza e privacy;
- versioni di Windows e PowerShell provate;
- lettore e tipologia di carta usati, senza numeri seriali o dati del titolare;
- test automatici e manuali eseguiti;
- eventuali modifiche a dipendenze, hash o licenze.

Non allegare schermate o output con dati reali. Usare valori sintetici e
irriconducibili a persone.
