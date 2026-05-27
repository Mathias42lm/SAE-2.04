from fastapi import FastAPI
import subprocess

app = FastAPI()

@app.post("/add_user/{username}")
def add_user(username: str):
    # La commande s'exécute avec les privilèges du conteneur (root)
    result = subprocess.run(["samba-tool", "user", "create", username], capture_output=True)
    return {"status": "ok" if result.returncode == 0 else "error"}