# Componenti e dati di terze parti

Questo documento registra provenienza, modifiche locali e condizioni di riuso
dei materiali inclusi nel repository. Non sostituisce i testi di licenza
originali.

I materiali elencati qui non sono concessi sotto la PolyForm Noncommercial del
progetto. Restano soggetti esclusivamente alle licenze indicate per ciascun
componente; vedere [LICENSING.md](LICENSING.md) per l'ordine di prevalenza.

## CIE.MRTD.SDK

`lib/CIE.MRTD.SDK.dll` è compilato dai sorgenti del progetto ufficiale
[`italia/cie-mrtd-dotnet-sdk`](https://github.com/italia/cie-mrtd-dotnet-sdk),
commit
[`16e717e8ac036f7869909ba2d7d5d4f656ae6e78`](https://github.com/italia/cie-mrtd-dotnet-sdk/tree/16e717e8ac036f7869909ba2d7d5d4f656ae6e78).
Il progetto upstream dichiara di non essere attualmente mantenuto: ogni
aggiornamento deve quindi essere sottoposto a revisione e test di sicurezza.

Sono applicate due modifiche locali: `System.Random` è sostituito con
`RandomNumberGenerator` sia per l'esponente effimero Diffie-Hellman sia per i
nonce usati dall'SDK. La patch riproducibile è in
`lib/CIE.MRTD.SDK-CSPRNG.patch`.

- Copyright: Developers Italia, 2017
- Licenza: BSD 3-Clause
- Testo: `lib/LICENSE-CIE-MRTD-SDK.txt`
- SHA-256 del binario incluso:
  `F1323F935CA4A236A7B772172AFBACB564223A007DD8F9C4E3DF67F7D56D9497`
- Firma Authenticode: assente; l'integrità deve essere verificata tramite hash

La restrizione non commerciale del progetto non limita i diritti BSD sul
binario o sulla patch considerati separatamente.

## Elenco dei comuni italiani

`Elenco-comuni-italiani.csv` deriva dall'elenco dei codici e delle denominazioni
delle unità territoriali pubblicato da ISTAT. È letto in Windows-1252 e usato
per associare codici catastali o numerici ai nomi dei comuni.

- Fonte: [Codici statistici delle unità amministrative territoriali](https://www.istat.it/classificazione/codici-dei-comuni-delle-province-e-delle-regioni/)
- Titolare: Istituto nazionale di statistica (ISTAT)
- Licenza dichiarata da ISTAT: [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/deed.it)
- Attribuzione: elaborazione su dati ISTAT
- Record nella copia inclusa: 7.896
- Data di riferimento della copia: non registrata nel file sorgente
- SHA-256 della copia inclusa:
  `57EAF945182FC64FA05F80F1A5FB2A84CFF55EBDE2AF6E3947A731776E7809E0`

La copia inclusa contiene ancora separatamente Castegnero e Nanto e non è
allineata all'assetto ISTAT in vigore dal 21 febbraio 2026. Deve essere
aggiornata prima di un rilascio destinato a produrre denominazioni comunali
correnti; vedere [la procedura di rilascio](docs/RELEASING.md).

La restrizione non commerciale del progetto non si applica al dataset. Il suo
riuso, anche commerciale, resta consentito nei limiti e alle condizioni di
CC-BY-4.0, inclusi attribuzione e indicazione delle modifiche.
