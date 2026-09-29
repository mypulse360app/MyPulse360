$file = "lib\features\doctor\presentation\pages\patient_history_page.dart"
$content = Get-Content $file -Raw
$pattern = '(?s)Future<void> _markAsSeen\(String appointmentId, String doctorId\) async \{\s*setState\(\(\) => _marking = true\);\s*final existing = await ref'
$replacement = 'Future<void> _markAsSeen(String appointmentId, String doctorId) async {
    setState(() => _marking = true);
    try {
      final existing = await ref'
$newContent = [regex]::Replace($content, $pattern, $replacement)

$pattern2 = '(?s)setState\(\(\) => _marking = false\);\s*// Instead of pop \(which might just go back in shell\), explicitly go to dashboard\s*context.go\(RoutePaths.doctorDashboard\);\s*\}'
$replacement2 = 'setState(() => _marking = false);
      context.go(RoutePaths.doctorDashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() => _marking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }'
$newContent = [regex]::Replace($newContent, $pattern2, $replacement2)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $newContent, $utf8NoBom)
