import re

with open('lib/features/pharmacist/presentation/pages/process_prescription_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

with open('temp_buildVitalsCard.dart', 'r', encoding='utf-8') as f:
    replacement = f.read()

pattern = re.compile(r'Widget _buildVitalsCard\(\{.*?^\s*@override\s*Widget build\(BuildContext context\)', re.DOTALL | re.MULTILINE)
match = pattern.search(content)
if match:
    new_content = content[:match.start()] + replacement + "\n\n  @override\n  Widget build(BuildContext context)" + content[match.end():]
    with open('lib/features/pharmacist/presentation/pages/process_prescription_page.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Replaced successfully')
else:
    print('Pattern not found')
