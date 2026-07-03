[CmdletBinding()]
param(
    [string]$ReaderName
)

# SPDX-FileCopyrightText: 2026 Simone D'Anna <dev@simonedanna.it>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

$ComuniCsvPath = Join-Path $PSScriptRoot "Elenco-comuni-italiani.csv"
$CieSdkPath = Join-Path $PSScriptRoot "lib\CIE.MRTD.SDK.dll"
$CieMiddlewarePath = Join-Path $env:WINDIR "System32\CIEPKI.dll"

if (-not (Test-Path $ComuniCsvPath)) {
    throw "File comuni non trovato: $ComuniCsvPath"
}

# Il file ISTAT distribuito con lo script e' Windows-1252, non UTF-8.
$csvEncoding = [System.Text.Encoding]::GetEncoding(1252)
$ComuneRecords = [System.IO.File]::ReadAllText($ComuniCsvPath, $csvEncoding) |
    ConvertFrom-Csv -Delimiter ';'
$ComuneByCatastale = @{}
$ComuneByNumerico = @{}

foreach ($record in $ComuneRecords) {
    $nomeComune = $record.'Denominazione in italiano'

    if ([string]::IsNullOrWhiteSpace($nomeComune)) {
        $nomeComune = $record.'Denominazione (Italiana e straniera)'
    }

    $codiceCatastale = ''
    if ($null -ne $record.'Codice Catastale del comune') {
        $codiceCatastale = $record.'Codice Catastale del comune'.Trim().ToUpperInvariant()
    }

    $codiceNumerico = ''
    if ($null -ne $record.'Codice Comune formato numerico') {
        $codiceNumerico = $record.'Codice Comune formato numerico'.Trim().ToUpperInvariant()
    }

    if ($codiceCatastale -ne '') {
        $ComuneByCatastale[$codiceCatastale] = $nomeComune
    }

    if ($codiceNumerico -ne '') {
        $ComuneByNumerico[$codiceNumerico] = $nomeComune

        $codiceNumericoNormalizzato = $codiceNumerico.TrimStart('0')
        if ($codiceNumericoNormalizzato -eq '') {
            $codiceNumericoNormalizzato = '0'
        }

        $ComuneByNumerico[$codiceNumericoNormalizzato] = $nomeComune
    }
}

if (-not ('CnsPcscNative' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class CnsPcscNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct SCARD_IO_REQUEST
    {
        public uint dwProtocol;
        public uint cbPciLength;
    }

    [DllImport("winscard.dll", CharSet = CharSet.Unicode)]
    public static extern int SCardEstablishContext(
        uint dwScope,
        IntPtr pvReserved1,
        IntPtr pvReserved2,
        out IntPtr phContext
    );

    [DllImport("winscard.dll", CharSet = CharSet.Unicode)]
    public static extern int SCardConnect(
        IntPtr hContext,
        string szReader,
        uint dwShareMode,
        uint dwPreferredProtocols,
        out IntPtr phCard,
        out uint pdwActiveProtocol
    );

    [DllImport("winscard.dll")]
    public static extern int SCardDisconnect(
        IntPtr hCard,
        uint dwDisposition
    );

    [DllImport("winscard.dll")]
    public static extern int SCardReleaseContext(
        IntPtr hContext
    );

    [DllImport("winscard.dll", EntryPoint = "SCardListReadersW", CharSet = CharSet.Unicode)]
    public static extern int SCardListReaders(
        IntPtr hContext,
        string mszGroups,
        IntPtr mszReaders,
        ref uint pcchReaders
    );

    [DllImport("winscard.dll")]
    public static extern int SCardTransmit(
        IntPtr hCard,
        ref SCARD_IO_REQUEST pioSendPci,
        byte[] pbSendBuffer,
        int cbSendLength,
        IntPtr pioRecvPci,
        byte[] pbRecvBuffer,
        ref int pcbRecvLength
    );
}
'@
}

if (-not ('CieMiddlewareNativeBridge' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public sealed class CiePairingResult
{
    public uint Code;
    public int AttemptsRemaining;
    public string Pan;
    public string Name;
    public string CardSerial;
}

public static class CieMiddlewareNativeBridge
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr LoadLibraryW(string path);

    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    private static extern IntPtr GetProcAddress(IntPtr module, string name);

    [DllImport("kernel32.dll")]
    private static extern bool FreeLibrary(IntPtr module);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate uint ProgressCallback(int progress, IntPtr message);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate uint CompletedCallback(IntPtr pan, IntPtr name, IntPtr cardSerial);

    [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    private delegate uint PairDelegate(
        [MarshalAs(UnmanagedType.LPStr)] string pan,
        [MarshalAs(UnmanagedType.LPStr)] string pin,
        ref int attempts,
        ProgressCallback progress,
        CompletedCallback completed
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
    private delegate uint IsEnrolledDelegate([MarshalAs(UnmanagedType.LPStr)] string pan);

    private static IntPtr FindExport(IntPtr module, params string[] names)
    {
        foreach (string name in names)
        {
            IntPtr address = GetProcAddress(module, name);
            if (address != IntPtr.Zero)
                return address;
        }

        throw new EntryPointNotFoundException(String.Join(" oppure ", names));
    }

    public static bool IsEnrolled(string libraryPath, string pan)
    {
        IntPtr module = LoadLibraryW(libraryPath);
        if (module == IntPtr.Zero)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());

        try
        {
            IntPtr address = FindExport(module, "VerificaCIEAbilitata", "_VerificaCIEAbilitata@4");
            IsEnrolledDelegate function = (IsEnrolledDelegate)Marshal.GetDelegateForFunctionPointer(
                address,
                typeof(IsEnrolledDelegate)
            );
            return function(pan) == 1;
        }
        finally
        {
            FreeLibrary(module);
        }
    }

    public static CiePairingResult Pair(string libraryPath, string pin)
    {
        IntPtr module = LoadLibraryW(libraryPath);
        if (module == IntPtr.Zero)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());

        try
        {
            IntPtr address = FindExport(module, "AbbinaCIE", "_AbbinaCIE@20");
            PairDelegate function = (PairDelegate)Marshal.GetDelegateForFunctionPointer(
                address,
                typeof(PairDelegate)
            );

            CiePairingResult result = new CiePairingResult();
            int attempts = 0;

            ProgressCallback progress = delegate(int value, IntPtr message)
            {
                string text = Marshal.PtrToStringAnsi(message);
                if (!String.IsNullOrWhiteSpace(text))
                    Console.WriteLine("CIE: " + text);
                return 0;
            };

            CompletedCallback completed = delegate(IntPtr pan, IntPtr name, IntPtr serial)
            {
                result.Pan = Marshal.PtrToStringAnsi(pan);
                result.Name = Marshal.PtrToStringAnsi(name);
                result.CardSerial = Marshal.PtrToStringAnsi(serial);
                return 0;
            };

            result.Code = function(null, pin, ref attempts, progress, completed);
            result.AttemptsRemaining = attempts;
            GC.KeepAlive(progress);
            GC.KeepAlive(completed);
            return result;
        }
        finally
        {
            FreeLibrary(module);
        }
    }
}
'@
}

function Send-ApduOnce {
    param(
        [byte[]]$Apdu,
        [IntPtr]$CardHandle,
        [uint32]$Protocol
    )

    [byte[]]$recv = New-Object byte[] 260
    [int]$recvLen = $recv.Length

    $pci = [CnsPcscNative+SCARD_IO_REQUEST]::new()
    $pci.dwProtocol = $Protocol
    $pci.cbPciLength = 8

    $rc = [CnsPcscNative]::SCardTransmit(
        $CardHandle,
        [ref]$pci,
        $Apdu,
        $Apdu.Length,
        [IntPtr]::Zero,
        $recv,
        [ref]$recvLen
    )

    if ($rc -ne 0) {
        throw "Errore SCardTransmit: $rc"
    }

    if ($recvLen -lt 2) {
        throw "Risposta APDU non valida."
    }

    $sw1 = $recv[$recvLen - 2]
    $sw2 = $recv[$recvLen - 1]
    $dataLength = $recvLen - 2

    if ($dataLength -gt 0) {
        [byte[]]$data = $recv[0..($dataLength - 1)]
    }
    else {
        [byte[]]$data = @()
    }

    [PSCustomObject]@{
        SW   = ("{0:X2}{1:X2}" -f $sw1, $sw2)
        Data = $data
    }
}

function Send-Apdu {
    param(
        [byte[]]$Apdu,
        [IntPtr]$CardHandle,
        [uint32]$Protocol
    )

    $currentApdu = [byte[]]$Apdu.Clone()
    $allData = [System.Collections.Generic.List[byte]]::new()

    for ($attempt = 0; $attempt -lt 16; $attempt++) {
        $response = Send-ApduOnce $currentApdu $CardHandle $Protocol

        # 6Cxx: la carta comunica il Le corretto per il comando.
        if ($response.SW.StartsWith('6C') -and $currentApdu.Length -ge 5) {
            $currentApdu[$currentApdu.Length - 1] = [Convert]::ToByte($response.SW.Substring(2, 2), 16)
            continue
        }

        if ($response.Data.Length -gt 0) {
            $allData.AddRange([byte[]]$response.Data)
        }

        # 61xx: i dati rimanenti si recuperano con GET RESPONSE.
        if ($response.SW.StartsWith('61')) {
            $le = [Convert]::ToByte($response.SW.Substring(2, 2), 16)
            $currentApdu = [byte[]](0x00, 0xC0, 0x00, 0x00, $le)
            continue
        }

        return [PSCustomObject]@{
            SW   = $response.SW
            Data = $allData.ToArray()
        }
    }

    throw "Troppe risposte concatenate dalla smart card."
}

function Require-Success {
    param($Response, [string]$Step)

    if ($Response.SW -ne "9000") {
        throw "${Step}: risposta carta $($Response.SW)"
    }
}

function Read-Field {
    param([ref]$Buffer)

    $source = [string]$Buffer.Value
    $lengthDigits = 2

    if ($source.Length -lt $LengthDigits) {
        throw "Record incompleto durante la lettura."
    }

    $fieldLength = [Convert]::ToInt32(
        $source.Substring(0, $LengthDigits),
        16
    )

    $source = $source.Substring($LengthDigits)

    if ($source.Length -lt $fieldLength) {
        throw "Campo dichiarato più lungo dei dati disponibili."
    }

    $value = $source.Substring(0, $fieldLength)
    $Buffer.Value = $source.Substring($fieldLength)

    return $value.Trim()
}

function Format-Date {
    param([string]$Value)

    try {
        return [datetime]::ParseExact(
            $Value,
            "ddMMyyyy",
            [Globalization.CultureInfo]::InvariantCulture
        ).ToString("dd/MM/yyyy")
    }
    catch {
        return $Value
    }
}

function Get-PcscReaders {
    param([IntPtr]$Context)

    [uint32]$bufferLength = 0
    $rc = [CnsPcscNative]::SCardListReaders($Context, $null, [IntPtr]::Zero, [ref]$bufferLength)

    if ($rc -eq -2146435026) { # SCARD_E_NO_READERS_AVAILABLE
        return @()
    }

    if ($rc -ne 0) {
        throw "Impossibile elencare i lettori: $rc"
    }

    if ($bufferLength -le 1) {
        return @()
    }

    $buffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([int]$bufferLength * 2)

    try {
        $rc = [CnsPcscNative]::SCardListReaders($Context, $null, $buffer, [ref]$bufferLength)

        if ($rc -ne 0) {
            throw "Impossibile leggere i lettori disponibili: $rc"
        }

        $readerText = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($buffer, [int]$bufferLength)
        return @($readerText -split "`0" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($buffer)
    }
}

function Select-Reader {
    param([string[]]$Readers)

    if ($Readers.Count -eq 0) {
        throw "Nessun lettore smart card rilevato."
    }

    if ($Readers.Count -eq 1) {
        return $Readers[0]
    }

    Write-Host "Lettori disponibili:"
    for ($i = 0; $i -lt $Readers.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $Readers[$i])
    }

    while ($true) {
        $selection = Read-Host "Seleziona un lettore o premi Invio per usare il primo"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            return $Readers[0]
        }

        [int]$index = 0
        if ([int]::TryParse($selection, [ref]$index) -and $index -ge 1 -and $index -le $Readers.Count) {
            return $Readers[$index - 1]
        }

        Write-Host "Selezione non valida."
    }
}

function Get-CardFriendlyMessage {
    param([int]$ErrorCode)

    switch ($ErrorCode) {
        -2146435060 { return "Nessuna smart card rilevata nel lettore." } # SCARD_E_NO_SMARTCARD
        -2146434967 { return "La smart card è stata rimossa." } # SCARD_W_REMOVED_CARD
        -2146434970 { return "La smart card non risponde." } # SCARD_W_UNRESPONSIVE_CARD
        -2146434969 { return "La smart card non è alimentata." } # SCARD_W_UNPOWERED_CARD
        -2146434968 { return "La smart card è stata reimpostata: riprova." } # SCARD_W_RESET_CARD
        -2146435049 { return "Il lettore selezionato non è disponibile." } # SCARD_E_READER_UNAVAILABLE
        -2146435061 { return "La smart card è già in uso esclusivo da un'altra applicazione." } # SCARD_E_SHARING_VIOLATION
        -2146435057 { return "Il lettore e la smart card non concordano un protocollo compatibile." } # SCARD_E_PROTO_MISMATCH
        -2146434971 { return "La smart card inserita non è supportata." } # SCARD_W_UNSUPPORTED_CARD
        -2146434966 { return "La smart card ha rifiutato l'accesso per motivi di sicurezza." } # SCARD_W_SECURITY_VIOLATION
        default { return ("Errore PC/SC: {0} (0x{1:X8})" -f $ErrorCode, [BitConverter]::ToUInt32([BitConverter]::GetBytes($ErrorCode), 0)) }
    }
}

function Read-BinaryRange {
    param(
        [IntPtr]$CardHandle,
        [uint32]$Protocol,
        [int]$Offset,
        [int]$Length
    )

    if ($Offset -lt 0 -or $Length -lt 1 -or ($Offset + $Length) -gt 0x8000) {
        throw "Intervallo READ BINARY non valido: offset=$Offset, lunghezza=$Length"
    }

    $result = [System.Collections.Generic.List[byte]]::new()
    $currentOffset = $Offset
    $remaining = $Length

    while ($remaining -gt 0) {
        $chunkLength = [Math]::Min(254, $remaining)
        $p1 = [byte](($currentOffset -shr 8) -band 0x7F)
        $p2 = [byte]($currentOffset -band 0xFF)
        $response = Send-Apdu ([byte[]](0x00, 0xB0, $p1, $p2, [byte]$chunkLength)) $CardHandle $Protocol
        Require-Success $response ("Lettura dati personali all'offset {0}" -f $currentOffset)

        if ($response.Data.Length -eq 0) {
            throw "La smart card non ha restituito dati all'offset $currentOffset."
        }

        $bytesToUse = [Math]::Min($response.Data.Length, $remaining)
        $result.AddRange([byte[]]$response.Data[0..($bytesToUse - 1)])
        $currentOffset += $bytesToUse
        $remaining -= $bytesToUse
    }

    # La virgola impedisce a PowerShell di srotolare byte[] nella pipeline.
    return ,([byte[]]$result.ToArray())
}

function Read-CnsCardData {
    param(
        [IntPtr]$CardHandle,
        [uint32]$Protocol
    )

    $r = Send-Apdu ([byte[]](0x00,0xA4,0x00,0x00,0x02,0x3F,0x00)) $CardHandle $Protocol
    Require-Success $r "Selezione MF 3F00"

    $r = Send-Apdu ([byte[]](0x00,0xA4,0x00,0x00,0x02,0x11,0x00)) $CardHandle $Protocol
    Require-Success $r "Selezione DF1 1100"

    $r = Send-Apdu ([byte[]](0x00,0xA4,0x00,0x00,0x02,0x11,0x02)) $CardHandle $Protocol
    Require-Success $r "Selezione EF 1102"

    [byte[]]$header = Read-BinaryRange -CardHandle $CardHandle -Protocol $Protocol -Offset 0 -Length 6
    $headerText = [System.Text.Encoding]::ASCII.GetString($header)

    if ($headerText -notmatch '^[0-9A-Fa-f]{6}$') {
        throw "Intestazione EF.DatiPersonali non valida: '$headerText'"
    }

    $declaredLength = [Convert]::ToInt32($headerText, 16)
    if ($declaredLength -lt 6 -or $declaredLength -gt 0x7FFF) {
        throw "Lunghezza EF.DatiPersonali non valida: $declaredLength"
    }

    $data = [System.Collections.Generic.List[byte]]::new()
    $data.AddRange($header)

    if ($declaredLength -gt 6) {
        [byte[]]$body = Read-BinaryRange -CardHandle $CardHandle -Protocol $Protocol -Offset 6 -Length ($declaredLength - 6)
        $data.AddRange($body)
    }

    return [PSCustomObject]@{
        SW   = '9000'
        Data = $data.ToArray()
    }
}

function Try-ConnectCard {
    param(
        [IntPtr]$Context,
        [string[]]$Readers,
        [ref]$CardHandle,
        [ref]$ActiveProtocol,
        [ref]$UsedReader
    )

    $firstError = 0

    foreach ($reader in $Readers) {
        $localCard = [IntPtr]::Zero
        $localProtocol = 0

        $rc = [CnsPcscNative]::SCardConnect(
            $Context,
            $reader,
            2,
            3,
            [ref]$localCard,
            [ref]$localProtocol
        )

        if ($rc -eq 0) {
            $CardHandle.Value = $localCard
            $ActiveProtocol.Value = $localProtocol
            $UsedReader.Value = $reader
            return 0
        }

        if ($rc -notin @(-2146435060, -2146434967, -2146434970, -2146434969, -2146434968)) {
            if ($firstError -eq 0) {
                $firstError = $rc
            }
        }
    }

    if ($firstError -ne 0) {
        return $firstError
    }

    return -2146435060
}

function Resolve-Comune {
    param([string]$Code)

    $normalizedCode = ''
    if ($null -ne $Code) {
        $normalizedCode = $Code.Trim().ToUpperInvariant()
    }

    if ($normalizedCode -eq '') {
        return $null
    }

    if ($ComuneByCatastale.ContainsKey($normalizedCode)) {
        return $ComuneByCatastale[$normalizedCode]
    }

    if ($ComuneByNumerico.ContainsKey($normalizedCode)) {
        return $ComuneByNumerico[$normalizedCode]
    }

    if ($normalizedCode -match '^\d+$') {
        $withoutLeadingZeros = $normalizedCode.TrimStart('0')
        if ($withoutLeadingZeros -eq '') {
            $withoutLeadingZeros = '0'
        }

        if ($ComuneByNumerico.ContainsKey($withoutLeadingZeros)) {
            return $ComuneByNumerico[$withoutLeadingZeros]
        }
    }

    return $null
}

function ConvertFrom-CnsPersonalData {
    param([byte[]]$Data)

    $raw = [System.Text.Encoding]::ASCII.GetString($Data)

    if ($raw.Length -lt 6 -or $raw.Substring(0, 6) -notmatch '^[0-9A-Fa-f]{6}$') {
        throw "Record dati troppo corto o intestazione non valida."
    }

    $declaredLength = [Convert]::ToInt32($raw.Substring(0, 6), 16)

    if ($declaredLength -lt 6 -or $declaredLength -gt $raw.Length) {
        throw "Lunghezza record non valida: $declaredLength"
    }

    $buffer = $raw.Substring(6, $declaredLength - 6)

    $emettitore = Read-Field ([ref]$buffer)
    $dataEmissione = Read-Field ([ref]$buffer)
    $dataScadenza = Read-Field ([ref]$buffer)
    $cognome = Read-Field ([ref]$buffer)
    $nome = Read-Field ([ref]$buffer)
    $dataNascita = Read-Field ([ref]$buffer)
    $sesso = Read-Field ([ref]$buffer)

    $remainingFields = [System.Collections.Generic.List[string]]::new()
    while ($buffer.Length -gt 0) {
        $remainingFields.Add((Read-Field ([ref]$buffer)))
    }

    $codiceFiscaleIndex = -1
    for ($i = 0; $i -lt $remainingFields.Count; $i++) {
        if ($remainingFields[$i] -match '^[A-Za-z0-9]{16}$') {
            $codiceFiscaleIndex = $i
            break
        }
    }

    if ($codiceFiscaleIndex -notin @(0, 1)) {
        throw "Layout EF.DatiPersonali non riconosciuto: codice fiscale assente o in posizione inattesa."
    }

    $codiceFiscale = $remainingFields[$codiceFiscaleIndex].ToUpperInvariant()
    $statura = ''
    $cittadinanza = ''
    $statoEsteroNascita = ''
    $attoNascita = ''
    $indirizzoResidenza = ''
    $annotazioni = ''

    if ($codiceFiscaleIndex -eq 0) {
        # Layout compatto usato dalle TS-CNS.
        $luogoNascita = if ($remainingFields.Count -gt 1) { $remainingFields[1] } else { '' }
        $residenza = if ($remainingFields.Count -gt 2) { $remainingFields[2] } else { '' }
    }
    else {
        # Layout CNS completo, comprensivo dei campi opzionali CIE.
        $statura = $remainingFields[0]
        $cittadinanza = if ($remainingFields.Count -gt 2) { $remainingFields[2] } else { '' }
        $luogoNascita = if ($remainingFields.Count -gt 3) { $remainingFields[3] } else { '' }
        $statoEsteroNascita = if ($remainingFields.Count -gt 4) { $remainingFields[4] } else { '' }
        $attoNascita = if ($remainingFields.Count -gt 5) { $remainingFields[5] } else { '' }
        $residenza = if ($remainingFields.Count -gt 6) { $remainingFields[6] } else { '' }
        $indirizzoResidenza = if ($remainingFields.Count -gt 7) { $remainingFields[7] } else { '' }
        $annotazioni = if ($remainingFields.Count -gt 8) { $remainingFields[8] } else { '' }
    }

    return [PSCustomObject]@{
        TipoDocumento       = 'CNS / TS-CNS'
        Emettitore           = $emettitore
        Cognome              = $cognome
        Nome                 = $nome
        CodiceFiscale        = $codiceFiscale
        DataNascita          = Format-Date $dataNascita
        Sesso                = $sesso
        Statura              = $statura
        LuogoNascita         = $luogoNascita
        ComuneNascita        = Resolve-Comune $luogoNascita
        StatoEsteroNascita   = $statoEsteroNascita
        AttoNascita          = $attoNascita
        Residenza            = $residenza
        ComuneResidenza      = Resolve-Comune $residenza
        IndirizzoResidenza   = $indirizzoResidenza
        Cittadinanza         = $cittadinanza
        Annotazioni          = $annotazioni
        DataEmissione        = Format-Date $dataEmissione
        DataScadenza         = Format-Date $dataScadenza
    }
}

function Import-CieSdk {
    if ('CIE.MRTD.SDK.EAC.EAC' -as [type]) {
        return
    }

    if (-not (Test-Path -LiteralPath $CieSdkPath)) {
        throw "SDK CIE non trovato: $CieSdkPath"
    }

    Add-Type -Path $CieSdkPath
}

function Close-CieSdkCard {
    param($SmartCard)

    if ($null -eq $SmartCard) {
        return
    }

    try {
        $SmartCard.Disconnect([CIE.MRTD.SDK.PCSC.Disposition]::SCARD_RESET_CARD)
    }
    catch {
        # La disconnessione puo' fallire se la carta e' gia' stata rimossa.
    }
    finally {
        $SmartCard.Dispose()
    }
}

function Test-CieCard {
    param([string]$Reader)

    Import-CieSdk
    $smartCard = [CIE.MRTD.SDK.PCSC.SmartCard]::new()

    try {
        $connected = $smartCard.Connect(
            $Reader,
            [CIE.MRTD.SDK.PCSC.Share]::SCARD_SHARE_SHARED,
            [CIE.MRTD.SDK.PCSC.Protocol]::SCARD_PROTOCOL_T0orT1
        )

        if (-not $connected) {
            $code = [uint32]$smartCard.LastSCardResult
            throw ("Impossibile connettere la CIE tramite l'SDK: 0x{0:X8}" -f $code)
        }

        $eac = [CIE.MRTD.SDK.EAC.EAC]::new($smartCard)
        return $eac.IsSAC()
    }
    finally {
        Close-CieSdkCard $smartCard
    }
}

function Test-CieIasCard {
    param(
        [IntPtr]$CardHandle,
        [uint32]$Protocol
    )

    # AID dell'applicazione IAS CIE, registrato dal Ministero dell'Interno.
    $response = Send-Apdu ([byte[]](0x00,0xA4,0x04,0x0C,0x06,0xA0,0x00,0x00,0x00,0x00,0x39)) $CardHandle $Protocol
    if ($response.SW -ne '9000') {
        return $null
    }

    # EF.ID_Servizi (1001) e' un identificativo casuale di 12 caratteri,
    # leggibile senza PIN e utilizzato per associare il certificato alla carta.
    $response = Send-Apdu ([byte[]](0x00,0xA4,0x02,0x04,0x02,0x10,0x01)) $CardHandle $Protocol
    Require-Success $response "Selezione EF.ID_Servizi CIE"

    $response = Send-Apdu ([byte[]](0x00,0xB0,0x00,0x00,0x0C)) $CardHandle $Protocol
    if ($response.SW -notin @('9000', '6282') -or $response.Data.Length -ne 12) {
        throw "Lettura EF.ID_Servizi CIE: risposta carta $($response.SW), lunghezza $($response.Data.Length)"
    }

    $pan = [System.Text.Encoding]::ASCII.GetString($response.Data)
    if ($pan -notmatch '^[\x21-\x7E]{12}$') {
        throw "EF.ID_Servizi CIE contiene un identificativo non valido."
    }

    return [PSCustomObject]@{
        Pan = $pan
    }
}

function Read-CiePin {
    while ($true) {
        $securePin = Read-Host "Inserisci le 8 cifre del PIN della CIE" -AsSecureString
        $bstr = [IntPtr]::Zero

        try {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePin)
            $pin = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }

        if ($pin -match '^\d{8}$') {
            return $pin
        }

        $pin = $null
        Write-Host "PIN non valido: sono richieste esattamente 8 cifre."
    }
}

function Get-X500AttributeValue {
    param(
        [string]$DecodedName,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $pattern = '(?im)^\s*{0}\s*=\s*(.*?)\s*$' -f [regex]::Escape($name)
        $match = [regex]::Match($DecodedName, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value.Trim()
        }
    }

    return ''
}

function Get-CieAuthenticationCertificate {
    param([string]$Pan)

    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        [System.Security.Cryptography.X509Certificates.StoreName]::My,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    )

    try {
        $store.Open(
            [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly -bor
            [System.Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly
        )

        $matches = @()
        foreach ($certificate in $store.Certificates) {
            try {
                $decoded = $certificate.SubjectName.Decode(
                    [System.Security.Cryptography.X509Certificates.X500DistinguishedNameFlags]::UseNewLines
                )

                if ($decoded.IndexOf("/$Pan", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $matches += $certificate
                }
            }
            catch {
                # Ignora certificati non decodificabili o non pertinenti.
            }
        }

        $selected = $matches | Sort-Object NotAfter -Descending | Select-Object -First 1
        if ($null -eq $selected) {
            return $null
        }

        # La copia DER resta valida dopo la chiusura dello store virtuale CIE.
        return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($selected.RawData)
    }
    finally {
        $store.Close()
    }
}

function ConvertFrom-CieAuthenticationCertificate {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string]$FallbackCardSerial
    )

    $flags = [System.Security.Cryptography.X509Certificates.X500DistinguishedNameFlags]::UseNewLines
    $subject = $Certificate.SubjectName.Decode($flags)
    $issuer = $Certificate.IssuerName.Decode($flags)

    $commonName = Get-X500AttributeValue $subject @('CN', 'OID.2.5.4.3')
    $subjectSerial = Get-X500AttributeValue $subject @('SERIALNUMBER', 'OID.2.5.4.5')
    $surname = Get-X500AttributeValue $subject @('SN', 'OID.2.5.4.4')
    $givenName = Get-X500AttributeValue $subject @('G', 'GN', 'OID.2.5.4.42')
    $country = Get-X500AttributeValue $subject @('C', 'OID.2.5.4.6')
    $issuerOrganization = Get-X500AttributeValue $issuer @('O', 'OID.2.5.4.10')

    $taxCode = ''
    if ($commonName -match '^([^/]+)/') {
        $taxCode = $matches[1].Trim().ToUpperInvariant()
    }

    $documentNumber = $FallbackCardSerial
    if ($subjectSerial -match '^IDCIT-(.+)$') {
        $documentNumber = $matches[1].Trim()
    }

    return [PSCustomObject]@{
        TipoDocumento      = 'CIE 3.0 (applicazione IAS)'
        NumeroDocumento    = $documentNumber
        Cognome            = $surname
        Nome               = $givenName
        CodiceFiscale      = $taxCode
        Cittadinanza       = $country
        AutoritaRilascio   = $issuerOrganization
        DataEmissione      = $Certificate.NotBefore.ToString('dd/MM/yyyy')
        DataScadenza       = $Certificate.NotAfter.ToString('dd/MM/yyyy')
    }
}

function Read-CieIasCertificateData {
    param([string]$Pan)

    if (-not (Test-Path -LiteralPath $CieMiddlewarePath)) {
        throw "Questa CIE richiede il Middleware CIE ufficiale, ma CIEPKI.dll non e' installato."
    }

    $pairingResult = $null
    $isEnrolled = [CieMiddlewareNativeBridge]::IsEnrolled($CieMiddlewarePath, $Pan)

    if (-not $isEnrolled) {
        Write-Host "Questa CIE espone i dati personali nel certificato IAS protetto da PIN."
        Write-Host "Il Middleware CIE ufficiale abiliterà la carta su questo profilo Windows."
        $pin = Read-CiePin

        try {
            $pairingResult = [CieMiddlewareNativeBridge]::Pair($CieMiddlewarePath, $pin)
        }
        finally {
            $pin = $null
        }

        switch ($pairingResult.Code) {
            0x00000000 { }
            0x000000F0 { }
            0x000000A0 {
                throw "PIN CIE errato. Tentativi rimanenti: $($pairingResult.AttemptsRemaining)."
            }
            0x000000A4 {
                throw "PIN CIE bloccato: usa il PUK nell'applicazione CieID per sbloccarlo."
            }
            0x000000E0 {
                throw "Il Middleware CIE non rileva più la carta sul lettore."
            }
            0x000000E1 {
                throw "Il Middleware CIE non riconosce la carta rilevata."
            }
            default {
                throw ("Abilitazione CIE non riuscita: codice 0x{0:X8}." -f $pairingResult.Code)
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($pairingResult.Pan) -and $pairingResult.Pan -ne $Pan) {
            throw "Il Middleware CIE ha elaborato una carta diversa da quella selezionata."
        }
    }
    else {
        Write-Host "CIE già abilitata nel Middleware ufficiale: leggo il certificato associato."
    }

    $certificate = Get-CieAuthenticationCertificate -Pan $Pan
    if ($null -eq $certificate) {
        throw "Certificato CIE non disponibile nello store Windows dopo l'abilitazione."
    }

    try {
        $fallbackSerial = if ($null -ne $pairingResult) { $pairingResult.CardSerial } else { '' }
        return ConvertFrom-CieAuthenticationCertificate -Certificate $certificate -FallbackCardSerial $fallbackSerial
    }
    finally {
        $certificate.Reset()
    }
}

function Read-CieCan {
    while ($true) {
        $secureCan = Read-Host "Inserisci il CAN di 6 cifre stampato sul fronte della CIE" -AsSecureString
        $bstr = [IntPtr]::Zero

        try {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureCan)
            $can = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }

        if ($can -match '^\d{6}$') {
            return $can
        }

        Write-Host "CAN non valido: sono richieste esattamente 6 cifre."
    }
}

function Read-CieDataGroups {
    param(
        [string]$Reader,
        [string]$Can
    )

    if ($Can -notmatch '^\d{6}$') {
        throw "Il CAN della CIE deve contenere esattamente 6 cifre."
    }

    Import-CieSdk
    $smartCard = [CIE.MRTD.SDK.PCSC.SmartCard]::new()

    try {
        $connected = $smartCard.Connect(
            $Reader,
            [CIE.MRTD.SDK.PCSC.Share]::SCARD_SHARE_EXCLUSIVE,
            [CIE.MRTD.SDK.PCSC.Protocol]::SCARD_PROTOCOL_T1
        )

        if (-not $connected) {
            $code = [uint32]$smartCard.LastSCardResult
            throw ("Impossibile aprire la CIE in modalità esclusiva: 0x{0:X8}" -f $code)
        }

        $eac = [CIE.MRTD.SDK.EAC.EAC]::new($smartCard)
        if (-not $eac.IsSAC()) {
            throw "La carta non espone un'applicazione MRTD CIE compatibile con PACE."
        }

        $eac.PACE($Can)

        # DG14 consente la Chip Authentication, che prova il possesso della
        # chiave privata del chip prima di leggere i dati anagrafici.
        [byte[]]$null = $eac.ReadDG([CIE.MRTD.SDK.EAC.DG]::DG14)
        $eac.ChipAuthentication()

        [byte[]]$dg1 = $eac.ReadDG([CIE.MRTD.SDK.EAC.DG]::DG1)
        [byte[]]$dg11 = $eac.ReadDG([CIE.MRTD.SDK.EAC.DG]::DG11)
        [byte[]]$dg12 = $eac.ReadDG([CIE.MRTD.SDK.EAC.DG]::DG12)

        return [PSCustomObject]@{
            DG1  = $dg1
            DG11 = $dg11
            DG12 = $dg12
        }
    }
    catch {
        $message = $_.Exception.Message
        $inner = $_.Exception.InnerException
        while ($null -ne $inner) {
            $message += " -> $($inner.Message)"
            $inner = $inner.InnerException
        }

        throw "Lettura CIE non riuscita: $message"
    }
    finally {
        Close-CieSdkCard $smartCard
    }
}

function Read-BerTlvNodes {
    param([byte[]]$Data)

    $nodes = [System.Collections.Generic.List[object]]::new()
    $offset = 0

    while ($offset -lt $Data.Length) {
        $firstTagByte = $Data[$offset]
        $tagBytes = [System.Collections.Generic.List[byte]]::new()
        $tagBytes.Add($firstTagByte)
        $offset++

        if (($firstTagByte -band 0x1F) -eq 0x1F) {
            do {
                if ($offset -ge $Data.Length) {
                    throw "Tag BER-TLV incompleto."
                }

                $tagByte = $Data[$offset]
                $tagBytes.Add($tagByte)
                $offset++
            } while (($tagByte -band 0x80) -ne 0)
        }

        if ($offset -ge $Data.Length) {
            throw "Lunghezza BER-TLV mancante."
        }

        $lengthByte = $Data[$offset]
        $offset++

        if (($lengthByte -band 0x80) -eq 0) {
            $valueLength = [int]$lengthByte
        }
        else {
            $lengthByteCount = $lengthByte -band 0x7F
            if ($lengthByteCount -eq 0 -or $lengthByteCount -gt 4 -or ($offset + $lengthByteCount) -gt $Data.Length) {
                throw "Lunghezza BER-TLV non supportata."
            }

            $valueLength = 0
            for ($i = 0; $i -lt $lengthByteCount; $i++) {
                $valueLength = ($valueLength -shl 8) -bor $Data[$offset]
                $offset++
            }
        }

        if ($valueLength -lt 0 -or ($offset + $valueLength) -gt $Data.Length) {
            throw "Il valore BER-TLV supera i dati disponibili."
        }

        if ($valueLength -eq 0) {
            [byte[]]$value = @()
        }
        else {
            [byte[]]$value = $Data[$offset..($offset + $valueLength - 1)]
        }

        $children = @()
        if (($firstTagByte -band 0x20) -ne 0 -and $valueLength -gt 0) {
            $children = @(Read-BerTlvNodes $value)
        }

        $tagHex = (($tagBytes.ToArray() | ForEach-Object { '{0:X2}' -f $_ }) -join '')
        $nodes.Add([PSCustomObject]@{
            Tag      = $tagHex
            Value    = $value
            Children = $children
        })

        $offset += $valueLength
    }

    return $nodes.ToArray()
}

function Find-BerTlvValue {
    param(
        [object[]]$Nodes,
        [string]$Tag
    )

    foreach ($node in $Nodes) {
        if ($node.Tag -eq $Tag) {
            return ,([byte[]]$node.Value)
        }

        if ($node.Children.Count -gt 0) {
            $found = Find-BerTlvValue -Nodes $node.Children -Tag $Tag
            if ($null -ne $found) {
                return ,([byte[]]$found)
            }
        }
    }

    return $null
}

function Get-CieTlvText {
    param(
        [object[]]$Nodes,
        [string]$Tag
    )

    [byte[]]$value = Find-BerTlvValue -Nodes $Nodes -Tag $Tag
    if ($null -eq $value) {
        return ''
    }

    return [System.Text.Encoding]::UTF8.GetString($value).Trim([char]0)
}

function ConvertTo-ComparableName {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $decomposed = $Value.Normalize([System.Text.NormalizationForm]::FormD)
    $result = [System.Text.StringBuilder]::new()

    foreach ($character in $decomposed.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark -and [char]::IsLetterOrDigit($character)) {
            [void]$result.Append([char]::ToUpperInvariant($character))
        }
    }

    return $result.ToString()
}

function Format-CieFullDate {
    param([string]$Value)

    foreach ($format in @('yyyyMMdd', 'yyyyMMddHHmmss')) {
        $date = [datetime]::MinValue
        if ([datetime]::TryParseExact(
            $Value,
            $format,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$date
        )) {
            return $date.ToString('dd/MM/yyyy')
        }
    }

    return $Value
}

function Format-MrzDate {
    param(
        [string]$Value,
        [switch]$BirthDate
    )

    if ($Value -notmatch '^\d{6}$') {
        return $Value
    }

    $yy = [int]$Value.Substring(0, 2)
    $month = [int]$Value.Substring(2, 2)
    $day = [int]$Value.Substring(4, 2)
    $currentYear = (Get-Date).Year
    $currentCentury = $currentYear - ($currentYear % 100)
    $candidateYears = @(
        ($currentCentury - 100 + $yy),
        ($currentCentury + $yy),
        ($currentCentury + 100 + $yy)
    )

    if ($BirthDate) {
        $year = $candidateYears | Where-Object { $_ -le $currentYear } | Sort-Object -Descending | Select-Object -First 1
    }
    else {
        $year = $candidateYears | Sort-Object { [Math]::Abs($_ - $currentYear) } | Select-Object -First 1
    }

    try {
        return ([datetime]::new([int]$year, $month, $day)).ToString('dd/MM/yyyy')
    }
    catch {
        return $Value
    }
}

function ConvertFrom-CieDataGroups {
    param(
        [byte[]]$DG1,
        [byte[]]$DG11,
        [byte[]]$DG12
    )

    $dg1Nodes = @(Read-BerTlvNodes $DG1)
    $dg11Nodes = @(Read-BerTlvNodes $DG11)
    $dg12Nodes = @(Read-BerTlvNodes $DG12)

    $mrz = (Get-CieTlvText -Nodes $dg1Nodes -Tag '5F1F') -replace "`r|`n", ''
    if ($mrz.Length -ne 90) {
        throw "MRZ CIE non valida: attesi 90 caratteri, trovati $($mrz.Length)."
    }

    $line1 = $mrz.Substring(0, 30)
    $line2 = $mrz.Substring(30, 30)
    $line3 = $mrz.Substring(60, 30)

    $mrzNameParts = $line3 -split '<<', 2
    $mrzSurname = ($mrzNameParts[0] -replace '<', ' ').Trim()
    $mrzGivenNames = if ($mrzNameParts.Count -gt 1) { ($mrzNameParts[1] -replace '<', ' ').Trim() } else { '' }

    $surname = $mrzSurname
    $givenNames = $mrzGivenNames
    $fullName = Get-CieTlvText -Nodes $dg11Nodes -Tag '5F0E'

    if (-not [string]::IsNullOrWhiteSpace($fullName)) {
        $fullNameParts = $fullName -split '<<', 2
        if ($fullNameParts.Count -eq 2) {
            $firstPart = ($fullNameParts[0] -replace '<', ' ').Trim()
            $secondPart = ($fullNameParts[1] -replace '<', ' ').Trim()
            $mrzSurnameKey = ConvertTo-ComparableName $mrzSurname

            if ((ConvertTo-ComparableName $firstPart) -eq $mrzSurnameKey) {
                $surname = $firstPart
                $givenNames = $secondPart
            }
            elseif ((ConvertTo-ComparableName $secondPart) -eq $mrzSurnameKey) {
                $surname = $secondPart
                $givenNames = $firstPart
            }
        }
    }

    $birthAddress = Get-CieTlvText -Nodes $dg11Nodes -Tag '5F11'
    $birthParts = @($birthAddress -split '<' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $residenceAddress = Get-CieTlvText -Nodes $dg11Nodes -Tag '5F42'
    $residenceParts = @($residenceAddress -split '<' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $fullBirthDate = Get-CieTlvText -Nodes $dg11Nodes -Tag '5F2B'
    $birthDate = if ([string]::IsNullOrWhiteSpace($fullBirthDate)) {
        Format-MrzDate -Value $line2.Substring(0, 6) -BirthDate
    }
    else {
        Format-CieFullDate $fullBirthDate
    }

    $issueDate = Format-CieFullDate (Get-CieTlvText -Nodes $dg12Nodes -Tag '5F26')

    return [PSCustomObject]@{
        TipoDocumento       = 'CIE'
        NumeroDocumento     = $line1.Substring(5, 9).Trim('<')
        Cognome             = $surname
        Nome                = $givenNames
        CodiceFiscale       = (Get-CieTlvText -Nodes $dg11Nodes -Tag '5F10').ToUpperInvariant()
        DataNascita         = $birthDate
        Sesso               = $line2.Substring(7, 1)
        LuogoNascita        = if ($birthParts.Count -gt 0) { $birthParts[0] } else { '' }
        ProvinciaNascita    = if ($birthParts.Count -gt 1) { $birthParts[1] } else { '' }
        IndirizzoResidenza  = if ($residenceParts.Count -gt 0) { $residenceParts[0] } else { '' }
        ComuneResidenza     = if ($residenceParts.Count -gt 1) { $residenceParts[1] } else { '' }
        ProvinciaResidenza  = if ($residenceParts.Count -gt 2) { $residenceParts[2] } else { '' }
        Cittadinanza        = $line2.Substring(15, 3).Trim('<')
        AutoritaRilascio    = Get-CieTlvText -Nodes $dg12Nodes -Tag '5F19'
        DataEmissione       = $issueDate
        DataScadenza        = Format-MrzDate -Value $line2.Substring(8, 6)
    }
}

function Start-DocumentReader {
$context = [IntPtr]::Zero
$card = [IntPtr]::Zero
[uint32]$activeProtocol = 0
$documentData = $null

try {
    $rc = [CnsPcscNative]::SCardEstablishContext(
        2,
        [IntPtr]::Zero,
        [IntPtr]::Zero,
        [ref]$context
    )

    if ($rc -ne 0) {
        throw "Impossibile creare il contesto PC/SC: $rc"
    }

    while ($true) {
        $availableReaders = @(Get-PcscReaders $context)

        if ($availableReaders.Count -eq 0) {
            Write-Host "Nessun lettore rilevato. Collega il lettore o verifica i driver, poi premi Invio per riprovare."
            [void](Read-Host)
            continue
        }

        $card = [IntPtr]::Zero
        $activeProtocol = 0

        $readersToTry = $availableReaders
        if (-not [string]::IsNullOrWhiteSpace($ReaderName)) {
            if ($availableReaders -contains $ReaderName) {
                $readersToTry = @($ReaderName)
            }
            else {
                Write-Host "Il lettore selezionato non è più disponibile; torno alla selezione automatica."
                $ReaderName = $null
            }
        }

        $usedReader = $null
        $rc = Try-ConnectCard -Context $context -Readers $readersToTry -CardHandle ([ref]$card) -ActiveProtocol ([ref]$activeProtocol) -UsedReader ([ref]$usedReader)

        if ($rc -ne 0) {
            Write-Host (Get-CardFriendlyMessage $rc)
            Write-Host "Verifica che la smart card sia inserita correttamente in uno di questi lettori:"
            $availableReaders | ForEach-Object { Write-Host ("- {0}" -f $_) }

            $choice = Read-Host "Premi Invio per riprovare, 's' per scegliere un lettore oppure 'q' per uscire"
            if ($choice -eq 'q') {
                return
            }

            if ($choice -eq 's') {
                $ReaderName = Select-Reader $availableReaders
            }

            continue
        }

        try {
            if ($usedReader -ne $null) {
                Write-Host "Lettore selezionato automaticamente: $usedReader"
            }

            # L'SDK MRTD deve essere provato prima dei comandi CNS: su alcune
            # CIE STM una SELECT MF cambia l'applicazione corrente e nasconde
            # EF.CardAccess fino alla successiva attivazione RF.
            if ($card -ne [IntPtr]::Zero) {
                [CnsPcscNative]::SCardDisconnect($card, 1) | Out-Null
                $card = [IntPtr]::Zero
            }

            $isMrtdCie = Test-CieCard -Reader $usedReader
            if ($isMrtdCie) {
                Write-Host "CIE MRTD rilevata. Mantieni la carta ferma sul lettore NFC durante tutta la lettura."
                $can = Read-CieCan

                try {
                    $cieDataGroups = Read-CieDataGroups -Reader $usedReader -Can $can
                    $documentData = ConvertFrom-CieDataGroups -DG1 $cieDataGroups.DG1 -DG11 $cieDataGroups.DG11 -DG12 $cieDataGroups.DG12
                }
                finally {
                    $can = $null
                }

                break
            }

            # Riapre la sessione raw per distinguere l'applicazione IAS CIE
            # dal filesystem CNS. Alcuni lettori notificano una sola volta il
            # reset appena eseguito dall'SDK: in quel caso si riconnette.
            $cieIas = $null
            $probeCompleted = $false
            for ($probeAttempt = 0; $probeAttempt -lt 2; $probeAttempt++) {
                $reconnectedReader = $null
                $rc = Try-ConnectCard -Context $context -Readers @($usedReader) -CardHandle ([ref]$card) -ActiveProtocol ([ref]$activeProtocol) -UsedReader ([ref]$reconnectedReader)
                if ($rc -ne 0) {
                    throw (Get-CardFriendlyMessage $rc)
                }

                try {
                    $cieIas = Test-CieIasCard -CardHandle $card -Protocol $activeProtocol
                    $probeCompleted = $true
                    break
                }
                catch {
                    if ($_.Exception.Message -notmatch '-2146434968') {
                        throw
                    }

                    [CnsPcscNative]::SCardDisconnect($card, 2) | Out-Null
                    $card = [IntPtr]::Zero
                }
            }

            if (-not $probeCompleted) {
                throw "La CIE è stata reimpostata dal lettore: allontanala e riappoggiala."
            }

            if ($null -ne $cieIas) {
                Write-Host "CIE IAS rilevata. Mantieni la carta ferma sul lettore NFC."
                [CnsPcscNative]::SCardDisconnect($card, 1) | Out-Null
                $card = [IntPtr]::Zero
                $documentData = Read-CieIasCertificateData -Pan $cieIas.Pan
                break
            }

            try {
                $cnsResponse = Read-CnsCardData -CardHandle $card -Protocol $activeProtocol
                $documentData = ConvertFrom-CnsPersonalData $cnsResponse.Data
                break
            }
            catch {
                $cnsReadError = $_.Exception.Message
            }

            throw "Carta non riconosciuta come CNS/TS-CNS o CIE. Dettaglio CNS: $cnsReadError"
        }
        catch {
            Write-Host $_.Exception.Message
            Write-Host "Il documento è stato rilevato ma la lettura non è riuscita. Reinseriscilo o cambia lettore."

            $choice = Read-Host "Premi Invio per riprovare, 's' per scegliere un lettore oppure 'q' per uscire"
            if ($choice -eq 'q') {
                return
            }

            if ($choice -eq 's') {
                $ReaderName = Select-Reader $availableReaders
            }

            continue
        }
        finally {
            if ($card -ne [IntPtr]::Zero) {
                [CnsPcscNative]::SCardDisconnect($card, 0) | Out-Null
                $card = [IntPtr]::Zero
            }
        }
    }

    $documentData | Format-List
}
finally {
    if ($card -ne [IntPtr]::Zero) {
        [CnsPcscNative]::SCardDisconnect($card, 0) | Out-Null
    }

    if ($context -ne [IntPtr]::Zero) {
        [CnsPcscNative]::SCardReleaseContext($context) | Out-Null
    }
}
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-DocumentReader
}
