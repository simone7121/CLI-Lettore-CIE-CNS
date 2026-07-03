# Changelog

Le modifiche rilevanti saranno documentate in questo file. Il formato segue
[Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/) e le release useranno
il versionamento semantico quando verrà pubblicata la prima versione.

## [Unreleased]

### Added

- lettura CNS e TS-CNS da `EF.DatiPersonali`;
- rilevamento CIE MRTD con PACE tramite CAN e Chip Authentication;
- lettura DG1, DG11 e DG12 per CIE MRTD;
- fallback CIE IAS tramite Middleware CIE e certificato di autenticazione;
- selezione automatica o esplicita del lettore PC/SC;
- documentazione per uso, sicurezza, privacy, test, contributi e release;
- template GitHub e validazione statica in CI.
- licenza PolyForm Noncommercial 1.0.0 per i componenti originali;
- separazione documentata delle licenze BSD-3-Clause e CC-BY-4.0;
- procedura per autorizzazioni commerciali e accordo per contributori.

### Security

- sostituzione di `System.Random` con `RandomNumberGenerator` nella build locale
  di CIE.MRTD.SDK.

> La cronologia precedente all'introduzione del controllo versione non è stata
> ricostruita. Le voci descrivono lo stato iniziale importato.
