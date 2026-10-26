import subprocess, sys, time, os

# SQL file sits next to this script (no hard-coded drive path)
SQL_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'patient_management_system.sql')

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, shell=True)
    return r.returncode, r.stdout + r.stderr

print("Waiting for Docker Desktop to be ready...")
for i in range(36):  # wait up to 3 minutes
    code, out = run("docker ps 2>&1")
    if code == 0:
        print(f"Docker is ready after {i*5}s!")
        break
    print(f"  [{i*5}s] Docker not ready yet...")
    time.sleep(5)
else:
    print("ERROR: Docker Desktop did not start within 3 minutes.")
    sys.exit(1)

# Remove old container if exists
print("\nRemoving old pms-mysql container (if any)...")
run("docker rm -f pms-mysql 2>&1")

# Start MySQL container on port 3307
print("Starting MySQL 8.4 container on port 3307...")
code, out = run(
    "docker run -d --name pms-mysql "
    "-e MYSQL_ROOT_PASSWORD=root "
    "-e MYSQL_DATABASE=patient_management_system "
    "-p 3307:3306 "
    "mysql:8.4"
)
print(out.strip())
if code != 0:
    print("ERROR: Could not start MySQL container.")
    sys.exit(1)

# Wait for MySQL to be ready
print("\nWaiting for MySQL to be ready inside container...")
for i in range(24):  # up to 2 minutes
    code, out = run(
        'docker exec pms-mysql mysql -h127.0.0.1 -P3306 -uroot -proot -e "SELECT 1;" 2>&1'
    )
    if code == 0:
        print(f"MySQL is ready after {i*5}s!")
        break
    print(f"  [{i*5}s] MySQL initializing...")
    time.sleep(5)
else:
    print("ERROR: MySQL did not become ready in time.")
    sys.exit(1)

# Import the SQL schema
print("\nImporting patient_management_system.sql...")
with open(SQL_FILE, 'r', encoding='utf-8') as f:
    sql_content = f.read()

result = subprocess.run(
    "docker exec -i pms-mysql mysql -uroot -proot patient_management_system",
    input=sql_content, capture_output=True, text=True, encoding='utf-8', shell=True
)
if result.returncode == 0:
    print("SQL imported successfully!")
else:
    print("SQL import output:", result.stdout + result.stderr)

# Verify tables
print("\nVerifying database tables:")
code, out = run(
    'docker exec pms-mysql mysql -uroot -proot patient_management_system -e "SHOW TABLES;" 2>&1'
)
print(out)

print("\n" + "="*50)
print("SUCCESS! Your app is running at:")
print("  http://localhost:8080/pms/   (9090 if you changed the GlassFish port)")
print("="*50)
