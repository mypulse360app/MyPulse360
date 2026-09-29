$file = "lib\features\chatbot\data\datasources\supabase_chatbot_datasource.dart"
$content = Get-Content $file -Raw
$pattern = '(?s)\.select\(''medication_name, strength, instructions, frequency''\)\s*\.inFilter\(''prescription_id'', ids\);\s*medications = \[\s*for \(final r in items\)\s*''\$\{r\[''medication_name''\]\}\$\{r\[''strength''\] \!\= null \? '' \$\{r\[''strength''\]\}'' \: ''''\}\$\{r\[''instructions''\] \!\= null \&\& r\[''instructions''\]\.toString\(\)\.isNotEmpty \? '' \(\$\{r\[''instructions''\]\}\)'' \: ''''\}\$\{r\[''frequency''\] \!\= null \? '' \- \$\{r\[''frequency''\]\}'' \: ''''\}'',\s*\];'
$replacement = '.select(''medication_name, dosage, instructions, frequency'')
            .inFilter(''prescription_id'', ids);
        medications = [
          for (final r in items)
            ''${r[''medication_name'']}${r[''dosage''] != null && r[''dosage''].toString().isNotEmpty ? '' ${r[''dosage'']}'' : ''''}${r[''instructions''] != null && r[''instructions''].toString().isNotEmpty ? '' (${r[''instructions'']})'' : ''''}${r[''frequency''] != null && r[''frequency''].toString().isNotEmpty ? '' - ${r[''frequency'']}'' : ''''}'',
        ];'
$newContent = [regex]::Replace($content, $pattern, $replacement)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $newContent, $utf8NoBom)
