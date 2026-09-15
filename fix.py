import os

files = [
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\config\router\app_router.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\pharmacist\data\datasources\mock_pharmacist_datasource.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\chatbot\presentation\pages\health_assistant_page.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\patient\presentation\pages\profile_page.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\auth\presentation\pages\login_page.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\appointments\presentation\widgets\time_slot_chip.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\chatbot\data\datasources\mock_chatbot_datasource.dart',
    r'c:\Users\mohaimin\Desktop\MyPulse360\lib\features\appointments\presentation\widgets\queue_status_view.dart'
]

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    in_head = False
    in_incoming = False
    
    for line in lines:
        if line.startswith('<<<<<<< HEAD'):
            in_head = True
            continue
        elif line.startswith('======='):
            in_head = False
            in_incoming = True
            continue
        elif line.startswith('>>>>>>>'):
            in_incoming = False
            continue
            
        if in_head:
            continue
        else:
            new_lines.append(line)
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print('Fixed', filepath)
