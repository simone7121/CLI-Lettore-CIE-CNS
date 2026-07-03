# Test e verifiche

## Controlli statici minimi

Eseguire dalla radice del repository su Windows:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\LettoreCNS.ps1),
    [ref]$tokens,
    [ref]$errors
) | Out-Null
$errors
```

L'output deve essere vuoto. Verificare poi integrità dell'SDK e caricamento dei
dati:

```powershell
(Get-FileHash .\lib\CIE.MRTD.SDK.dll -Algorithm SHA256).Hash

$encoding = [Text.Encoding]::GetEncoding(1252)
$records = [IO.File]::ReadAllText(
    (Resolve-Path .\Elenco-comuni-italiani.csv),
    $encoding
) | ConvertFrom-Csv -Delimiter ';'
$records.Count
```

La GitHub Action `validate.yml` ripete parser, file obbligatori, hash SDK e
caricamento CSV. Non esegue lo script, perché il runner non dispone di hardware.

## PSScriptAnalyzer

Se il modulo è disponibile localmente:

```powershell
Invoke-ScriptAnalyzer -Path .\LettoreCNS.ps1 -Severity Warning,Error
```

Ogni soppressione deve essere circoscritta e motivata. Non installare moduli da
fonti non attendibili su una postazione usata con documenti reali.

## Matrice manuale

Usare esclusivamente carte di test o documenti per i quali esiste autorizzazione.
Registrare esito e ambiente senza dati identificativi.

| Scenario | Windows PowerShell 5.1 | PowerShell 7 | Esito atteso |
| --- | --- | --- | --- |
| nessun lettore | richiesto | richiesto | messaggio e possibilità di riprovare |
| più lettori, `-ReaderName` valido/non valido | richiesto | richiesto | selezione coerente e fallback sicuro |
| CNS / TS-CNS | richiesto | consigliato | campi validati e handle rilasciati |
| CIE MRTD, CAN valido/non valido | richiesto | consigliato | input mascherato, PACE e output coerente |
| CIE IAS già abilitata | richiesto | consigliato | lettura certificato senza nuovo PIN |
| CIE IAS non abilitata, PIN valido/errato | richiesto | consigliato | pairing o tentativi residui corretti |
| rimozione/reset durante lettura | richiesto | consigliato | errore comprensibile e nuova prova |

Per ogni percorso verificare anche che non siano creati file, non partano
connessioni di rete e PIN/CAN non compaiano nella console.

## Criteri per una release

Una release richiede parser pulito, Action verde, verifica hash, test hardware
documentati almeno sui tre percorsi supportati o una limitazione esplicita nelle
note. La checklist completa è in [RELEASING.md](RELEASING.md).
