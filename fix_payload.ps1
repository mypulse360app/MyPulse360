$file = "lib\features\doctor\data\datasources\supabase_doctor_datasource.dart"
$content = Get-Content $file -Raw
$pattern = '(?s)final data = \{\s*''appointment_id'': consultation\.appointmentId,\s*''patient_id'': consultation\.patientId,\s*''doctor_id'': consultation\.doctorId,\s*''status'': statusStr,\s*''diagnosis'': consultation\.diagnosis,\s*''recommendations'': consultation\.recommendations,\s*''notes'': consultation\.notes,\s*\};'
$replacement = 'final data = <String, dynamic>{
        ''appointment_id'': consultation.appointmentId,
        ''patient_id'': consultation.patientId,
        ''doctor_id'': consultation.doctorId,
        ''status'': statusStr,
        ''notes'': consultation.notes,
      };
      if (consultation.diagnosis != null) data[''diagnosis''] = consultation.diagnosis;
      if (consultation.recommendations != null) data[''recommendations''] = consultation.recommendations;'
$newContent = [regex]::Replace($content, $pattern, $replacement)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file, $newContent, $utf8NoBom)
