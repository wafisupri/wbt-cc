param(
    [string]$StaffExcel = "$PSScriptRoot\BFI CARE Card System (v1.1) - Dump.xlsx",
    [string]$ContractorExcel = "$PSScriptRoot\BFI Online Care Card Form for Contractors & Third Parties (June 2024).xlsx",
    [string]$WalkaboutExcel = "$PSScriptRoot\BFI Walkabout System (v1.0).xlsx",
    [string]$BREExcel = "C:\Users\1\Documents\WBT-CC\BRE Personnel Details (as of 27082025) V1.xlsx",
    [string]$CExcel = "C:\Users\1\Documents\WBT-CC\C Personnel Details V1.xlsx",
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

# Validate files
if (-not (Test-Path $StaffExcel)) { Write-Host "ERROR: Staff file not found: $StaffExcel" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $ContractorExcel)) { Write-Host "ERROR: Contractor file not found: $ContractorExcel" -ForegroundColor Red; exit 1 }

Write-Host "Reading staff data..." -ForegroundColor Green
$staffData = Import-Excel $StaffExcel -WorksheetName "BFI Care Card System (v1.1)"
Write-Host "  Found: $($staffData.Count) records" -ForegroundColor Gray

Write-Host "Reading contractor data..." -ForegroundColor Green
$contractorData = Import-Excel $ContractorExcel -WorksheetName "Sheet1"
Write-Host "  Found: $($contractorData.Count) records" -ForegroundColor Gray

$outputFile = Join-Path $OutputDir "data.js"
$stream = [System.IO.StreamWriter]::new($outputFile)
$stream.WriteLine("// BFI OSS Portal - CARE Card Data")
$stream.WriteLine("// Generated: $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$stream.WriteLine("// Source: Staff ($($staffData.Count) records) + Contractors ($($contractorData.Count) records)")
$stream.WriteLine("const mockCareData = [")

$total = $staffData.Count + $contractorData.Count
$count = 0

function Sanitize($val) {
    if ($null -eq $val) { return "" }
    $s = $val.ToString().Trim()
    $s = $s -replace "\\", "\\" -replace "'", "\'" -replace "`r`n", "\n" -replace "`r", "\n" -replace "`n", "\n"
    return $s
}

# Validate walkabout file
if (-not (Test-Path $WalkaboutExcel)) { Write-Host "WARNING: Walkabout file not found: $WalkaboutExcel (skipping)" -ForegroundColor Yellow; $WalkaboutExcel = $null }

# Process staff data
$riskCol = "What can go wrong if there's no interventions or actions has been made?"
$actionCol = "What have you done to solve the problem(s)? How did you approach the person to make interventions? / How do you support the Good Practice? / What do you suggest for the Item you highlighted?"

$idx = 0
foreach ($row in $staffData) {
    $idx++
    try {
        $d = if ($row."Date & Time of Intervention" -is [datetime]) { $row."Date & Time of Intervention" } else { [datetime]::Parse($row."Date & Time of Intervention") }
    } catch { continue }
    $dateStr = $d.ToString("dd/MM/yyyy")
    $day = $d.ToString("dddd")
    $isoDate = $d.ToString("yyyy-MM-dd")

    $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', type: '$($(Sanitize($row.'Category of this Care Card Submission')))', location: '$($(Sanitize($row.'Location of Interventions')))', status: 'Closed', bfiNumber: '$($(Sanitize($row.'BFI Number (BFI000 / EXP000)')))', staffType: '$($(Sanitize($row.'BFI Staff or BRE Staff')))', employee: '$($(Sanitize($row.'Employee Details')))', position: '$($(Sanitize($row.'Position')))', department: '$($(Sanitize($row.'Department')))', section: '$($(Sanitize($row.'Section')))', company: '$($(Sanitize($row.'Department')))', purpose: '$($(Sanitize($row.'Purpose of Care Card Interventions')))', observation: '$($(Sanitize($row.'What have you Observed, Seen or Encountered?')))', risk: '$($(Sanitize($row.$riskCol)))', action: '$($(Sanitize($row.$actionCol)))' },"
    $stream.WriteLine($line)
    $count++
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
        $d = if ($row.$dateCol -is [datetime]) { $row.$dateCol } else { [datetime]::Parse($row.$dateCol) }
    } catch { continue }
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
    $count++
    if ($idx2 % 1000 -eq 0) { Write-Progress -PercentComplete ($count/$total*100) -Status "Contractors: $idx2" -Activity "Generating" -Completed:$false }
}

$stream.WriteLine("];")

# --- BRE Personnel Lookup ---
$breLookupFile = $BREExcel
if (Test-Path $breLookupFile) {
    Write-Host "Reading BRE personnel data..." -ForegroundColor Green
    $brePeople = Import-Excel $breLookupFile -WorksheetName "BRN EMPLIST - EMAIL ADDRESS (2)"
    Write-Host "  Found: $($brePeople.Count) records" -ForegroundColor Gray

    $stream.WriteLine("")
    $stream.WriteLine("const brePersonnel = {")

    $breIdCol = "`nBRE EMP`nID"
    $bIdx = 0
    foreach ($p in $brePeople) {
        $bIdx++
        $id = $p.$breIdCol
        if (-not $id) { $id = $p.'No'; if (-not $id) { continue } }
        $idStr = $id.ToString().Trim()
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

# --- Walkabout Data ---
if ($WalkaboutExcel) {
    Write-Host "Reading walkabout data..." -ForegroundColor Green
    $walkData = Import-Excel $WalkaboutExcel -WorksheetName "BFI Walkabout System (v1.0)"
    Write-Host "  Found: $($walkData.Count) records" -ForegroundColor Gray

    $stream.WriteLine("")
    $stream.WriteLine("const mockWalkaboutData = [")

    $wIdx = 0
    foreach ($row in $walkData) {
        $wIdx++
        try {
            $d = if ($row.Date -is [datetime]) { $row.Date } else { [datetime]::Parse($row.Date) }
        } catch { continue }
        $dateStr = $d.ToString("dd/MM/yyyy")
        $day = $d.ToString("dddd")
        $isoDate = $d.ToString("yyyy-MM-dd")

        $line = "    { date: '$isoDate', dateStr: '$dateStr', day: '$day', bfiNumber: '$($(Sanitize($row.'BFI Number (BFI000 / EXP000)')))', employee: '$($(Sanitize($row.'Employee Details')))', position: '$($(Sanitize($row.'Position')))', department: '$($(Sanitize($row.'Department')))', section: '$($(Sanitize($row.'Section')))', location: '$($(Sanitize($row.'Location')))', specificLocation: '$($(Sanitize($row.'Specific Location')))' },"
        $stream.WriteLine($line)
        $count++
        if ($wIdx % 200 -eq 0) { Write-Progress -PercentComplete 100 -Status "Walkabout: $wIdx" -Activity "Generating" }
    }
    $stream.WriteLine("];")
}

$stream.Close()

$size = (Get-Item $outputFile).Length
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Total records: $count" -ForegroundColor Green
Write-Host "Output file: $outputFile" -ForegroundColor Green
Write-Host "File size: $([math]::Round($size / 1MB, 2)) MB" -ForegroundColor Gray
