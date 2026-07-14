param(
    [string]$StaffExcel = "$PSScriptRoot\BFI CARE Card System (v1.1) - Dump.xlsx",
    [string]$ContractorExcel = "$PSScriptRoot\BFI Online Care Card Form for Contractors & Third Parties (June 2024).xlsx",
    [string]$ContractorExcel2 = "$PSScriptRoot\CARE Cards - BRE, Contractors, Third Parties.xlsx",
    [string]$PartnerExcel = "$PSScriptRoot\CARE Card Database by Syarqawi - BRE & RIMC.xlsx",
    [string]$WalkaboutExcel = "$PSScriptRoot\BFI Record Safety Walkabout 2025.xlsx",
    [string]$WalkaboutFormExcel = "$PSScriptRoot\Untitled form (Responses).xlsx",
    [string]$BREExcel = "$PSScriptRoot\BRE Personnel Details (as of 27082025) V1.xlsx",
    [string]$CExcel = "$PSScriptRoot\C Personnel Details V1.xlsx",
    [string]$StatisticsExcel = "$PSScriptRoot\CARE Cards & Walkabout Statistics (Automatic).xlsx",
    [string]$OutputDir = "$PSScriptRoot"
)

Write-Host "=== BFI OSS Portal - Data Generator ===" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "Installing ImportExcel module..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    Install-Module -Name ImportExcel -Force -Scope CurrentUser -AllowClobber
}
Import-Module ImportExcel -Force

# Force invariant culture so dd/MM/yyyy renders with literal '/' separators and English
# day names, regardless of the machine's regional settings (the portal states DD/MM/YYYY).
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

# Validate files
if (-not (Test-Path $StaffExcel)) { Write-Host "ERROR: Staff file not found: $StaffExcel" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $ContractorExcel)) { Write-Host "ERROR: Contractor file not found: $ContractorExcel" -ForegroundColor Red; exit 1 }

Write-Host "Reading staff data..." -ForegroundColor Green
$staffData = Import-Excel $StaffExcel -WorksheetName "BFI Care Card System (v1.1)"
Write-Host "  Found: $($staffData.Count) records" -ForegroundColor Gray

Write-Host "Reading contractor data (June 2024)..." -ForegroundColor Green
try {
    $contractorData = Import-Excel $ContractorExcel -WorksheetName "Sheet2"
} catch {
    Write-Host "  Sheet2 not found, trying first available sheet..." -ForegroundColor Yellow
    $contractorData = Import-Excel $ContractorExcel
}
Write-Host "  Found: $($contractorData.Count) records" -ForegroundColor Gray

# Helper to normalize column names (strip newlines, collapse whitespace)
function NormalizeData($data) {
    if (-not $data -or $data.Count -eq 0) { return $data }
    $result = @()
    foreach ($row in $data) {
        $obj = [PSCustomObject]@{}
        foreach ($prop in $row.PSObject.Properties) {
            $key = ($prop.Name -replace "`r`n", " " -replace "`n", " " -replace "`r", " " -replace "\s+", " ").Trim()
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue $prop.Value
        }
        $result += $obj
    }
    return $result
}

# Second contractor file (01.xlsx)
$hasContractor2 = $false
$contractorData2 = @()
if (Test-Path $ContractorExcel2) {
    Write-Host "Reading contractor data (01)..." -ForegroundColor Green
    try {
        $contractorData2 = NormalizeData (Import-Excel $ContractorExcel2 -WorksheetName "HSSE Records")
    } catch {
        Write-Host "  HSSE Records not found, trying first available sheet..." -ForegroundColor Yellow
        $contractorData2 = NormalizeData (Import-Excel $ContractorExcel2)
    }
    Write-Host "  Found: $($contractorData2.Count) records" -ForegroundColor Gray
    $hasContractor2 = $true
} else {
    Write-Host "WARNING: Contractor file 01 not found: $ContractorExcel2 (skipping)" -ForegroundColor Yellow
}

$outputFile = Join-Path $OutputDir "data.js"
$stream = [System.IO.StreamWriter]::new($outputFile)
$stream.WriteLine("// BFI OSS Portal - CARE Card Data")
$stream.WriteLine("// Generated: $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$stream.WriteLine("// Source: Staff ($($staffData.Count) records) + Contractors ($($contractorData.Count) records + $($contractorData2.Count) records)")
$stream.WriteLine("const mockCareData = [")

$total = $staffData.Count + $contractorData.Count + $contractorData2.Count
$count = 0
$staffWritten = 0; $conWritten = 0; $con2Written = 0; $walkWritten = 0; $partnerWritten = 0
$breCount = 0; $conKeyCount = 0

function Sanitize($val) {
    if ($null -eq $val) { return "" }
    $s = $val.ToString().Trim()
    $s = $s -replace "\\", "\\" -replace "'", "\'" -replace "`r`n", "\n" -replace "`r", "\n" -replace "`n", "\n"
    return $s
}

# Robust date parser: handles real datetimes, Excel serial numbers (OLE Automation
# dates), and date strings. Some source sheets export dates as raw serial numbers
# (e.g. 46228) rather than formatted dates, which [datetime]::Parse cannot read.
function ParseExcelDate($val) {
    if ($null -eq $val -or "$val" -eq "") { return $null }
    if ($val -is [datetime]) { return $val }
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($val -is [double] -or $val -is [int] -or $val -is [long] -or $val -is [decimal]) {
        if ([double]$val -lt 1000) { return $null }   # reject 0 / stray tiny serials (bogus ~1900 dates)
        return [datetime]::FromOADate([double]$val)
    }
    $s = $val.ToString().Trim()
    if ($s -match '^\d+(\.\d+)?$') {
        if ([double]$s -lt 1000) { return $null }
        return [datetime]::FromOADate([double]$s)
    }
    # Text-format date cells: parse day-first explicitly. Since the thread culture is
    # InvariantCulture (for slash output), a bare Parse would read dd/MM as MM/dd.
    $fmts = @('dd/MM/yyyy', 'd/M/yyyy', 'dd/MM/yyyy HH:mm', 'd/M/yyyy H:mm', 'dd/MM/yyyy HH:mm:ss', 'yyyy-MM-dd', 'yyyy-MM-dd HH:mm:ss')
    try { return [datetime]::ParseExact($s, $fmts, $inv, [System.Globalization.DateTimeStyles]::None) }
    catch { return [datetime]::Parse($s, [System.Globalization.CultureInfo]::GetCultureInfo('en-GB')) }
}

# Resolve a column value by regex against normalised (whitespace-collapsed) header
# names. Tolerant of trailing spaces / newlines that vary between form exports.
function Get-Col($row, $pattern) {
    $p = $row.PSObject.Properties | Where-Object { (($_.Name -replace '\s+', ' ').Trim()) -match $pattern } | Select-Object -First 1
    if ($p) { return $p.Value }
    return $null
}

# Process staff data
$riskCol = "What can go wrong if there's no interventions or actions has been made?"
$actionCol = "What have you done to solve the problem(s)? How did you approach the person to make interventions? / How do you support the Good Practice? / What do you suggest for the Item you highlighted?"

$idx = 0
foreach ($row in $staffData) {
    $idx++
    try {
        $d = ParseExcelDate $row."Date & Time of Intervention"
    } catch { continue }
    if ($null -eq $d) { continue }
    $dateStr = $d.ToString("dd/MM/yyyy")
    $day = $d.ToString("dddd")
    $isoDate = $d.ToString("yyyy-MM-dd")

    $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', type: '$($(Sanitize($row.'Category of this Care Card Submission')))', location: '$($(Sanitize($row.'Location of Interventions')))', status: 'Closed', bfiNumber: '$($(Sanitize($row.'BFI Number (BFI000 / EXP000)')))', staffType: '$($(Sanitize($row.'BFI Staff or BRE Staff')))', employee: '$($(Sanitize($row.'Employee Details')))', position: '$($(Sanitize($row.'Position')))', department: '$($(Sanitize($row.'Department')))', section: '$($(Sanitize($row.'Section')))', company: '$($(Sanitize($row.'Department')))', purpose: '$($(Sanitize($row.'Purpose of Care Card Interventions')))', observation: '$($(Sanitize($row.'What have you Observed, Seen or Encountered?')))', risk: '$($(Sanitize($row.$riskCol)))', action: '$($(Sanitize($row.$actionCol)))' },"
    $stream.WriteLine($line)
    $count++; $staffWritten++
    if ($idx % 1000 -eq 0) { Write-Progress -PercentComplete ($count/$total*100) -Status "Staff: $idx" -Activity "Generating" }
}

# Process contractor data
$breCol = "BRE no. (For BRE staff only)"
$dateCol = "Date of Intervention / Tarikh ketika Membuat Teguran Care Card"
$nameCol = "Full Name / Nama Penuh"
$companyCol = "Company / Organisation"
$posCol = "Position"
$locCol = "Location of Interventions / Lokasi tempat kamu buat teguran"
$purposeCol = "Purpose of Care Card Interventions / Tujuan Teguran Care Card Anda"
$obsCol = "What have you Observed, Seen or Encountered? / Apa yang kamu nampak, alami atau perhatikan?"
$riskCol2 = "What can go wrong if there's no interventions or actions has been made? / Apa boleh terjadi sekiranya tiada tindakan dilakukan?"
$actionCol2 = "What have you done to solve the problem(s)? How did you approach the person to make interventions? / How do you support the Good Practice? What do you suggest for the Item you highlighted? / Apakah ti"
$catCol = "Category of this Care Card Submission / Kategori Teguran Care Card Anda"

$idx2 = 0
foreach ($row in $contractorData) {
    $idx2++
    try {
        $d = ParseExcelDate $row.$dateCol
    } catch { continue }
    if ($null -eq $d) { continue }
    $dateStr = $d.ToString("dd/MM/yyyy")
    $day = $d.ToString("dddd")
    $isoDate = $d.ToString("yyyy-MM-dd")

    $breVal = $row.$breCol
    $bareBre = ""
    if ($breVal -ne $null -and $breVal -ne "") {
        $breStr = $breVal.ToString().Trim() -replace "^BRE\s*", "" -replace "^BRE", "" -replace "\s+", ""
        if ($breStr -match "^\d+$") { $bareBre = $breStr }
    }

    $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', type: '$($(Sanitize($row.$catCol)))', location: '$($(Sanitize($row.$locCol)))', status: 'Closed', bfiNumber: '$bareBre', staffType: 'Contractor', employee: '$($(Sanitize($row.$nameCol)))', position: '$($(Sanitize($row.$posCol)))', company: '$($(Sanitize($row.$companyCol)))', purpose: '$($(Sanitize($row.$purposeCol)))', observation: '$($(Sanitize($row.$obsCol)))', risk: '$($(Sanitize($row.$riskCol2)))', action: '$($(Sanitize($row.$actionCol2)))' },"
    $stream.WriteLine($line)
    $count++; $conWritten++
    if ($idx2 % 1000 -eq 0) { Write-Progress -PercentComplete ($count/$total*100) -Status "Contractors: $idx2" -Activity "Generating" -Completed:$false }
}

if ($hasContractor2) {
    # Process second contractor file (01.xlsx)
    $idx3 = 0
    foreach ($row in $contractorData2) {
        $idx3++
        try {
            $d = ParseExcelDate $row.$dateCol
        } catch { continue }
        if ($null -eq $d) { continue }
        $dateStr = $d.ToString("dd/MM/yyyy")
        $day = $d.ToString("dddd")
        $isoDate = $d.ToString("yyyy-MM-dd")

        $breVal = if ($row.'BFI Number (BFI000 / EXP000)') { $row.'BFI Number (BFI000 / EXP000)' } else { $row.$breCol }
        $bareBre = ""
        if ($breVal -ne $null -and $breVal -ne "") {
            $breStr = $breVal.ToString().Trim() -replace "^BRE\s*", "" -replace "^BRE", "" -replace "\s+", ""
            if ($breStr -match "^\d+$") { $bareBre = $breStr }
        }

        $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', type: '$($(Sanitize($row.$catCol)))', location: '$($(Sanitize($row.$locCol)))', status: 'Closed', bfiNumber: '$bareBre', staffType: 'Contractor', employee: '$($(Sanitize($row.$nameCol)))', position: '$($(Sanitize($row.$posCol)))', company: '$($(Sanitize($row.$companyCol)))', purpose: '$($(Sanitize($row.$purposeCol)))', observation: '$($(Sanitize($row.$obsCol)))', risk: '$($(Sanitize($row.$riskCol2)))', action: '$($(Sanitize($row.$actionCol2)))' },"
        $stream.WriteLine($line)
        $count++; $con2Written++
        if ($idx3 % 1000 -eq 0) { Write-Progress -PercentComplete ($count/$total*100) -Status "Contractors 01: $idx3" -Activity "Generating" }
    }
}

# Process BRE & RIMC business-partner CARE cards (separate DB; IDs are numeric, staffType = BRE Staff)
if (Test-Path $PartnerExcel) {
    Write-Host "Reading BRE & RIMC business-partner CARE cards..." -ForegroundColor Green
    foreach ($sheet in @("BRE Care Card Responses", "RIMC Care Card Responses")) {
        $pData = $null
        try { $pData = Import-Excel $PartnerExcel -WorksheetName $sheet } catch { $pData = $null }
        if (-not $pData) { Write-Host "  $sheet : (empty/unreadable, skipped)" -ForegroundColor Yellow; continue }
        $ps = 0
        foreach ($row in $pData) {
            try { $d = ParseExcelDate (Get-Col $row '^Date of Intervention') } catch { continue }
            if ($null -eq $d) { continue }
            $dateStr = $d.ToString("dd/MM/yyyy"); $day = $d.ToString("dddd"); $isoDate = $d.ToString("yyyy-MM-dd")

            # ID priority: BRE Employee No. -> Rotary IMC Employee No. -> BFI Intern No. (old alphanumeric BFI id)
            $pidRaw = Get-Col $row '^BRE Employee No'
            if ($null -eq $pidRaw -or "$pidRaw" -eq "") { $pidRaw = Get-Col $row 'Rotary IMC Employee No' }
            if ($null -eq $pidRaw -or "$pidRaw" -eq "") { $pidRaw = Get-Col $row 'BFI Intern No' }
            if ($pidRaw -is [double] -or $pidRaw -is [decimal]) { $pidStr = ([long][math]::Round([double]$pidRaw)).ToString() }
            elseif ($pidRaw -is [int] -or $pidRaw -is [long]) { $pidStr = $pidRaw.ToString() }
            else { $pidStr = "$pidRaw".Trim() }
            $pidStr = Sanitize $pidStr

            $pName    = Sanitize (Get-Col $row '^Full Name')
            $pCompany = Sanitize (Get-Col $row 'Company')
            $pPos     = Sanitize (Get-Col $row '^Position')
            $pLoc     = Sanitize (Get-Col $row 'Location of Interventions')
            $pPurpose = Sanitize (Get-Col $row 'Purpose of Care Card')
            $pObs     = Sanitize (Get-Col $row 'What have you Observed')
            $pRisk    = Sanitize (Get-Col $row 'What can go wrong')
            $pAction  = Sanitize (Get-Col $row 'What have you done')
            $pCat     = Sanitize (Get-Col $row 'Category of this Care Card')

            $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', type: '$pCat', location: '$pLoc', status: 'Closed', bfiNumber: '$pidStr', staffType: 'BRE Staff', employee: '$pName', position: '$pPos', company: '$pCompany', purpose: '$pPurpose', observation: '$pObs', risk: '$pRisk', action: '$pAction' },"
            $stream.WriteLine($line)
            $count++; $partnerWritten++; $ps++
        }
        Write-Host "  $sheet : $ps records" -ForegroundColor Gray
    }
} else {
    Write-Host "WARNING: BRE/RIMC file not found: $PartnerExcel (skipping)" -ForegroundColor Yellow
}

$stream.WriteLine("];")

# --- BRE Personnel Lookup ---
$breLookupFile = $BREExcel
if (Test-Path $breLookupFile) {
    Write-Host "Reading BRE personnel data..." -ForegroundColor Green
    $brePeople = Import-Excel $breLookupFile -WorksheetName "BRN EMPLIST - EMAIL ADDRESS (2)"
    Write-Host "  Found: $($brePeople.Count) records" -ForegroundColor Gray
    $breKeysSeen = @{}

    $stream.WriteLine("")
    $stream.WriteLine("const brePersonnel = {")

    $breIdCol = "`nBRE EMP`nID"
    $bIdx = 0
    foreach ($p in $brePeople) {
        $bIdx++
        $id = $p.$breIdCol
        if (-not $id) { $id = $p.'No'; if (-not $id) { continue } }
        $idStr = $id.ToString().Trim()
        $breKeysSeen[$idStr] = $true
        $name = Sanitize($p.'Official Name')
        $email = Sanitize($p.'Business  Email Information Email Address')
        $job = Sanitize($p.'Job Title')
        $dept = Sanitize($p.'Department Code')
        $section = Sanitize($p.'Section')
        $company = Sanitize($p.'Servicing Company')
        $line = "  '$idStr': { name: '$name', email: '$email', position: '$job', department: '$dept', section: '$section', company: '$company' }"
        if ($bIdx -lt $brePeople.Count) { $line += "," }
        $stream.WriteLine($line)
    }
    $stream.WriteLine("};")
    $breCount = $breKeysSeen.Count
} else {
    Write-Host "WARNING: BRE file not found: $breLookupFile (skipping)" -ForegroundColor Yellow
    $stream.WriteLine("")
    $stream.WriteLine("const brePersonnel = {};")
}

# --- Contractor Personnel Lookup ---
$cLookupFile = $CExcel
if (Test-Path $cLookupFile) {
    Write-Host "Reading contractor personnel data..." -ForegroundColor Green
    $cPeople = Import-Excel $cLookupFile -WorksheetName "Contractor"
    Write-Host "  Found: $($cPeople.Count) records" -ForegroundColor Gray

    $stream.WriteLine("")
    $stream.WriteLine("const contractorPersonnel = {")

    $cIdx = 0
    $cGroup = @{}
    foreach ($p in $cPeople) {
        $raw = $p.'ID'
        if (-not $raw) { continue }
        $idStr = $raw.ToString().Trim()
        # Strip leading C and leading zeros
        $idNum = $idStr -replace "^C0*", ""
        # Fallback: try rounding if numeric
        if ($idNum -eq "" -or $idNum -notmatch "^\d+$") {
            try { $idNum = [math]::Round([double]$idStr).ToString() } catch { continue }
        }
        if (-not $cGroup.ContainsKey($idNum)) { $cGroup[$idNum] = @() }
        $cGroup[$idNum] += $p
    }

    $cKeys = $cGroup.Keys | Sort-Object { [int]$_ }
    $conKeyCount = $cKeys.Count
    $kc = 0
    foreach ($idNum in $cKeys) {
        $kc++
        $entries = $cGroup[$idNum]
        $line = "  '$idNum': ["
        $subLines = @()
        foreach ($e in $entries) {
            $name = Sanitize($e.'Name')
            $company = Sanitize($e.'Company/Organisation')
            $position = Sanitize($e.'Designation/Job Title')
            $subLines += "{ name: '$name', company: '$company', position: '$position' }"
        }
        $line += ($subLines -join ", ") + "]"
        if ($kc -lt $cKeys.Count) { $line += "," }
        $stream.WriteLine($line)
    }
    $stream.WriteLine("};")
} else {
    Write-Host "WARNING: Contractor file not found: $cLookupFile (skipping)" -ForegroundColor Yellow
    $stream.WriteLine("")
    $stream.WriteLine("const contractorPersonnel = {};")
}

# --- Walkabout Data (SharePoint list export + Google Form attendance responses) ---
$stream.WriteLine("")
$stream.WriteLine("const mockWalkaboutData = [")

# Source 1: BFI Record Safety Walkabout 2025.xlsx (SharePoint list export)
if (Test-Path $WalkaboutExcel) {
    Write-Host "Reading walkabout data (list export)..." -ForegroundColor Green
    $walkData = Import-Excel $WalkaboutExcel
    Write-Host "  Found: $($walkData.Count) records" -ForegroundColor Gray

    $wIdx = 0
    foreach ($row in $walkData) {
        $wIdx++
        # Column headers vary between exports (e.g. "BFI Number (BFI000)/(EXP000) " with a
        # trailing space, "Name" instead of "Employee Details", "Sub Department" instead of
        # "Section"), so resolve them by pattern. Date is stored as an Excel serial number.
        try {
            $d = ParseExcelDate (Get-Col $row '^Date$')
        } catch { continue }
        if ($null -eq $d) { continue }
        $dateStr = $d.ToString("dd/MM/yyyy")
        $day = $d.ToString("dddd")
        $isoDate = $d.ToString("yyyy-MM-dd")

        $wBfi = Sanitize (Get-Col $row 'BFI Number')
        $wName = Sanitize (Get-Col $row '^Name$')
        $wPos = Sanitize (Get-Col $row '^Position$')
        $wDept = Sanitize (Get-Col $row '^Department$')
        $wSection = Sanitize (Get-Col $row '^(Section|Sub Department)$')
        $wLoc = Sanitize (Get-Col $row '^Location$')
        $wSpec = Sanitize (Get-Col $row 'Specific Location')

        $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', bfiNumber: '$wBfi', employee: '$wName', position: '$wPos', department: '$wDept', section: '$wSection', location: '$wLoc', specificLocation: '$wSpec' },"
        $stream.WriteLine($line)
        $count++; $walkWritten++
        if ($wIdx % 200 -eq 0) { Write-Progress -PercentComplete 100 -Status "Walkabout: $wIdx" -Activity "Generating" }
    }
} else {
    Write-Host "WARNING: Walkabout file not found: $WalkaboutExcel (skipping)" -ForegroundColor Yellow
}

# Source 2: Untitled form (Responses).xlsx (Google Form walkabout-attendance responses)
if (Test-Path $WalkaboutFormExcel) {
    Write-Host "Reading walkabout data (Google Form responses)..." -ForegroundColor Green
    try { $walkForm = Import-Excel $WalkaboutFormExcel -WorksheetName "Form responses 1" }
    catch { $walkForm = Import-Excel $WalkaboutFormExcel }
    Write-Host "  Found: $($walkForm.Count) records" -ForegroundColor Gray

    foreach ($row in $walkForm) {
        # Columns: Timestamp, Date, Name (first and last), ID (BFI/EXP/BRE/INT/IR),
        # Department, Section, Area (= location), Specific Location, Email address.
        try {
            $d = ParseExcelDate (Get-Col $row '^Date$')
        } catch { continue }
        if ($null -eq $d) { continue }
        $dateStr = $d.ToString("dd/MM/yyyy")
        $day = $d.ToString("dddd")
        $isoDate = $d.ToString("yyyy-MM-dd")

        $wBfi = Sanitize (Get-Col $row '^ID')
        $wName = Sanitize (Get-Col $row '^Name')
        $wDept = Sanitize (Get-Col $row '^Department$')
        $wSection = Sanitize (Get-Col $row '^Section$')
        $wLoc = Sanitize (Get-Col $row '^Area$')
        $wSpec = Sanitize (Get-Col $row 'Specific Location')

        $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', bfiNumber: '$wBfi', employee: '$wName', position: '', department: '$wDept', section: '$wSection', location: '$wLoc', specificLocation: '$wSpec' },"
        $stream.WriteLine($line)
        $count++; $walkWritten++
    }
} else {
    Write-Host "WARNING: Walkabout form file not found: $WalkaboutFormExcel (skipping)" -ForegroundColor Yellow
}

$stream.WriteLine("];")

# --- Statistics Data ---
if (Test-Path $StatisticsExcel) {
    Write-Host "Reading statistics data..." -ForegroundColor Green
    $statsData = Import-Excel $StatisticsExcel
    Write-Host "  Found: $($statsData.Count) records" -ForegroundColor Gray

    $stream.WriteLine("")
    $stream.WriteLine("const careStats = ")
    $stream.WriteLine($($statsData | ConvertTo-Json -Depth 2))
    $stream.WriteLine(";")
} else {
    Write-Host "WARNING: Statistics file not found: $StatisticsExcel (skipping)" -ForegroundColor Yellow
    $stream.WriteLine("")
    $stream.WriteLine("const careStats = {};")
}

# --- Data version + release notes (naming: month.week.upload, e.g. 7.2.3 = July, week 2, upload 3) ---
Write-Host "Writing version metadata + release notes..." -ForegroundColor Green
$now = Get-Date
$verWeek = [int][math]::Ceiling($now.Day / 7.0)
$monthWeek = "$($now.Month).$verWeek"
$genStr = $now.ToString('dd/MM/yyyy HH:mm')
$dateStr = $now.ToString('dd/MM/yyyy')
$careTotal = $staffWritten + $conWritten + $con2Written + $partnerWritten
$conTotal = $conWritten + $con2Written

# Read existing changelog first so the upload number can be sequenced within this month.week
$rnFile = Join-Path $OutputDir "release-notes.json"
$rnList = @()
if (Test-Path $rnFile) {
    try { $rnList = @(Get-Content $rnFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $rnList = @() }
}
# upload = next sequence number among existing "<month>.<week>.<n>" versions this week
$uploadRe = "^" + [regex]::Escape($monthWeek) + "\.(\d+)$"
$maxUpload = 0
foreach ($e in $rnList) {
    if ($e.version -and ($e.version -match $uploadRe) -and ([int]$Matches[1] -gt $maxUpload)) { $maxUpload = [int]$Matches[1] }
}
$upload = $maxUpload + 1
$version = "$monthWeek.$upload"

$stream.WriteLine("")
$stream.WriteLine("const dataMeta = {")
$stream.WriteLine("  version: '$version',")
$stream.WriteLine("  generated: '$genStr',")
$stream.WriteLine("  date: '$dateStr',")
$stream.WriteLine("  careCards: $careTotal,")
$stream.WriteLine("  walkabouts: $walkWritten,")
$stream.WriteLine("  staffCare: $staffWritten,")
$stream.WriteLine("  contractorCare: $conTotal,")
$stream.WriteLine("  businessPartnerCare: $partnerWritten,")
$stream.WriteLine("  brePersonnel: $breCount,")
$stream.WriteLine("  contractorPersonnel: $conKeyCount")
$stream.WriteLine("};")

$summary = "CARE Card & Walkabout data refreshed: $careTotal CARE cards ($staffWritten staff, $conTotal contractor, $partnerWritten business-partner) & $walkWritten walkabout records."
$newEntry = [PSCustomObject]@{
    version    = $version
    date       = $dateStr
    generated  = $genStr
    careCards  = $careTotal
    walkabouts = $walkWritten
    summary    = $summary
}
# Each upload is a distinct version, so always prepend; keep the 12 most recent
$rnList = @($newEntry) + $rnList
if ($rnList.Count -gt 12) { $rnList = $rnList[0..11] }
($rnList | ConvertTo-Json -Depth 3) | Out-File $rnFile -Encoding UTF8

# Emit as a guaranteed JS array (PS 5.1 unwraps single-element arrays otherwise)
$rnJs = "[" + (($rnList | ForEach-Object { $_ | ConvertTo-Json -Depth 3 -Compress }) -join ",`n") + "]"
$stream.WriteLine("")
$stream.WriteLine("const releaseNotes = $rnJs;")

$stream.Close()

$size = (Get-Item $outputFile).Length
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Total records: $count" -ForegroundColor Green
Write-Host "Output file: $outputFile" -ForegroundColor Green
Write-Host "File size: $([math]::Round($size / 1MB, 2)) MB" -ForegroundColor Gray
