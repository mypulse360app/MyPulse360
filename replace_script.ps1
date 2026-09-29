$file = "lib\features\pharmacist\presentation\pages\process_prescription_page.dart"
$content = Get-Content $file -Raw

$temp = "temp_buildVitalsCard.dart"
$replacement = Get-Content $temp -Raw

$startIndex = $content.IndexOf("Widget _buildVitalsCard({")
$endIndex = $content.LastIndexOf("  }")

if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
    $part1 = $content.Substring(0, $startIndex)
    # the end index is the closing brace of the class. The widget _buildVitalsCard ends right before it.
    # Actually we can just find the end of the file, minus 3 characters (`  }\r\n}`)
    
    $part2 = "`r`n}`r`n"
    
    $newContent = $part1 + $replacement + $part2
    [IO.File]::WriteAllText($file, $newContent)
    Write-Output "Successfully replaced _buildVitalsCard"
} else {
    Write-Output "Failed to find indices. Start: $startIndex, End: $endIndex"
}
