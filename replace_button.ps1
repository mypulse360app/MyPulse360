$file = "lib\features\pharmacist\presentation\pages\process_prescription_page.dart"
$content = Get-Content $file -Raw
$content = $content.Replace("'Verify & Dispense (${_items.length} ${_items.length == 1 ? 'Item' : 'Items'})'", "'Patient Complete'")
$content = $content.Replace("'Processing Dispense...'", "'Completing...'")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
