# Licenze del repository

## Codice e documentazione originali

Copyright © 2026 Simone D'Anna <dev@simonedanna.it>.

Salvo i materiali esplicitamente elencati come componenti di terze parti, il
codice, la documentazione e la configurazione originali del progetto sono
distribuiti secondo la
[PolyForm Noncommercial License 1.0.0](LICENSE), identificatore SPDX
`PolyForm-Noncommercial-1.0.0`.

Questa licenza consente gli usi non commerciali descritti nel suo testo. Non
concede l'uso commerciale del progetto originale. Qualunque uso commerciale
richiede un'autorizzazione o una licenza separata, preventiva ed esplicita,
rilasciata per iscritto da Simone D'Anna.

Questo è pertanto software **source-available**, non software open source
secondo la definizione OSI.

## Licenza commerciale

Per richiedere un'autorizzazione commerciale scrivere a
`dev@simonedanna.it`, indicando almeno:

- soggetto giuridico richiedente;
- prodotto, servizio o attività in cui verrà usato il software;
- modalità di distribuzione o accesso;
- durata, territorio e numero previsto di installazioni o utenti;
- eventuali modifiche e componenti da ridistribuire.

L'invio della richiesta, il silenzio del titolare, una pull request o una
collaborazione tecnica non costituiscono consenso. L'autorizzazione è valida
solo se resa per iscritto dal titolare e ne specifica l'ambito.

## Componenti di terze parti

| File o componente | Titolare/fonte | Licenza applicabile |
| --- | --- | --- |
| `lib/CIE.MRTD.SDK.dll` | Developers Italia / `italia/cie-mrtd-dotnet-sdk` | BSD 3-Clause |
| `lib/CIE.MRTD.SDK-CSPRNG.patch` | codice upstream e modifiche sul relativo codice | BSD 3-Clause |
| `lib/LICENSE-CIE-MRTD-SDK.txt` | testo della licenza upstream | BSD 3-Clause license text |
| `Elenco-comuni-italiani.csv` | ISTAT | Creative Commons Attribution 4.0 International |

Provenienza, commit, modifiche, attribuzioni e hash sono documentati in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
I file `.license` adiacenti al CSV, alla DLL e alla patch forniscono inoltre
metadati SPDX leggibili automaticamente senza modificare gli artefatti originali.

## Ordine di prevalenza

1. La licenza specifica del singolo componente prevale per quel componente.
2. La PolyForm Noncommercial License si applica soltanto ai materiali originali
   di Simone D'Anna e ai contributi accettati sotto tale licenza.
3. `THIRD_PARTY_NOTICES.md` e `NOTICE` forniscono attribuzioni e chiarimenti, ma
   non riducono i diritti concessi dalle licenze BSD-3-Clause o CC-BY-4.0.
4. In caso di conflitto, i termini della licenza di terza parte prevalgono
   limitatamente al relativo materiale.

In particolare, la restrizione non commerciale non viene applicata al CSV
ISTAT né all'SDK considerati separatamente: tali materiali possono essere usati
secondo le rispettive licenze, anche quando queste concedono diritti più ampi.
L'uso del programma completo resta invece soggetto alla licenza dei suoi
componenti originali.

## Obblighi di ridistribuzione

Chi ridistribuisce il repository o un pacchetto derivato deve:

- includere `LICENSE` e tutte le righe `Required Notice:` contenute in `NOTICE`;
- conservare `lib/LICENSE-CIE-MRTD-SDK.txt` e le attribuzioni BSD richieste;
- attribuire ISTAT, collegare CC BY 4.0 e indicare eventuali modifiche ai dati;
- mantenere chiara la separazione tra licenza del progetto e licenze di terze
  parti;
- non usare nomi o marchi dei titolari terzi per suggerire approvazione o
  sponsorizzazione.

La documentazione riepiloga i termini ma non sostituisce i testi integrali delle
licenze applicabili.
