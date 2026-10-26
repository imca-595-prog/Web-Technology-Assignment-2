import re

path = r'C:\glassfish7\glassfish7\glassfish\domains\domain1\config\domain.xml'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix: replace broken port=9090 (no quotes) with port="9090"
# Also fix doubled quotes port=""9090"" just in case
content = content.replace('port=""9090""', 'port="9090"')
content = content.replace('port=9090 ', 'port="9090" ')

# Verify result
if 'port="9090"' in content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: port changed to 9090 correctly")
else:
    print("WARNING: port=9090 not found, current state:")
    for line in content.splitlines():
        if '8080' in line or '9090' in line:
            print(" ", line.strip())
