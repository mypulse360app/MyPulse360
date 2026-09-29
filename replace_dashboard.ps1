$file = "lib\features\pharmacist\presentation\pages\pharmacist_dashboard_page.dart"
$content = Get-Content $file -Raw
$pattern = '(?s)Expanded\(\s*child: Column\(\s*crossAxisAlignment: CrossAxisAlignment.start,\s*children: \[\s*Row\(\s*children: \[\s*Text\(name, style: const TextStyle\(fontWeight: FontWeight.bold, fontSize: 16\)\),\s*const SizedBox\(width: 8\),\s*Container\(.*?\),\s*\],\s*\),\s*const SizedBox\(height: 4\),\s*Text\(.*?\),\s*\],\s*\),\s*\)'
$replacement = 'Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))'
$newContent = [regex]::Replace($content, $pattern, $replacement)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $newContent, $utf8NoBom)
