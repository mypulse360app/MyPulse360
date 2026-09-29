$file = "lib\features\pharmacist\presentation\pages\process_prescription_page.dart"
$content = Get-Content $file -Raw
$content = $content -replace ": 'Patient Complete'Item' : 'Items'}\)',", ": 'Patient Complete',"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
