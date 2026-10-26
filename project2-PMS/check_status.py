import subprocess, sys, time, os, re

LOG = r'C:\glassfish7\glassfish7\glassfish\domains\domain1\logs\server.log'
ASADMIN = r'C:\glassfish7\glassfish7\bin\asadmin.bat'
JAVA_HOME = r'C:\PROGRA~1\ECLIPS~1\jdk-21.0.12.101-hotspot'
WAR = r'd:\project2-PMS\target\pms.war'

env = os.environ.copy()
env['JAVA_HOME'] = JAVA_HOME
env['PATH'] = JAVA_HOME + r'\bin;' + env.get('PATH', '')

def run(cmd, capture=True):
    r = subprocess.run(cmd, capture_output=capture, text=True, env=env, shell=True)
    return r.stdout + r.stderr

# ── Read server log
print("\n=== LATEST SERVER LOG (last 30 lines) ===")
try:
    with open(LOG, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    print(''.join(lines[-30:]))
except Exception as e:
    print(f"Could not read log: {e}")

# ── Check ports
print("\n=== PORT STATUS ===")
ports = run('netstat -ano | findstr LISTENING')
for line in ports.splitlines():
    if ':9090' in line or ':4848' in line or ':8080' in line:
        print(line)

print("\n=== CHECKING GLASSFISH PROCESS ===")
procs = run('tasklist /FI "IMAGENAME eq java.exe" /FO CSV')
print(procs[:500] if procs else "No java.exe processes found")
