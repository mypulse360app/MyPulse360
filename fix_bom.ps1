$files = @(
  "lib\features\pharmacist\presentation\providers\pharmacist_providers.dart",
  "lib\features\pharmacist\presentation\pages\process_prescription_page.dart",
  "lib\features\doctor\data\datasources\supabase_doctor_datasource.dart",
  "lib\shared\presentation\pages\settings_page.dart"
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file)
    [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
}
Write-Output "Done BOM fixing!"
