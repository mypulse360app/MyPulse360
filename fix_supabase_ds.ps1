$file = "lib\features\doctor\data\datasources\supabase_doctor_datasource.dart"
$content = Get-Content $file -Raw
$content = $content -replace '(?s)\s*@override\s*Consultation startOrGetConsultation.*?UnimplementedError.*?;.*?}', ''
$content = $content -replace 'startOrGetConsultationAsync', 'startOrGetConsultation'
$content = $content -replace 'Future<Consultation> startOrGetConsultation', "@override`r`n  Future<Consultation> startOrGetConsultation"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
