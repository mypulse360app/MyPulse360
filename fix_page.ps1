$file = "lib\features\doctor\presentation\pages\patient_history_page.dart"
$content = Get-Content $file -Raw
$content = $content.Replace("final existing = ref`r`n        .read(doctorRepositoryProvider)`r`n        .startOrGetConsultation", "final existing = await ref`r`n        .read(doctorRepositoryProvider)`r`n        .startOrGetConsultation")
$content = $content.Replace("final existing = ref`n        .read(doctorRepositoryProvider)`n        .startOrGetConsultation", "final existing = await ref`n        .read(doctorRepositoryProvider)`n        .startOrGetConsultation")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
