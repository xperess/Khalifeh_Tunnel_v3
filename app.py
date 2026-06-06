from flask import Flask, jsonify, render_template
import os
import subprocess

app = Flask(__name__)

SERVICES = [
    "khalifeh-rathole-server",
    "khalifeh-rathole-client",
    "frps",
    "frpc",
    "hysteria2",
    "hysteria2-client"
]

# =========================
# STATUS CHECK
# =========================
def get_status(name):
    try:
        output = subprocess.check_output(
            ["systemctl", "is-active", name],
            stderr=subprocess.STDOUT
        ).decode().strip()
        return output
    except:
        return "inactive"

# =========================
# DASHBOARD
# =========================
@app.route("/")
def index():
    return render_template("index.html")

# =========================
# API STATUS
# =========================
@app.route("/api/status")
def status():
    data = {}
    for s in SERVICES:
        data[s] = get_status(s)
    return jsonify(data)

# =========================
# START SERVICE
# =========================
@app.route("/api/start/<name>")
def start(name):
    os.system(f"systemctl start {name}")
    return jsonify({"status": "started", "service": name})

# =========================
# STOP SERVICE
# =========================
@app.route("/api/stop/<name>")
def stop(name):
    os.system(f"systemctl stop {name}")
    return jsonify({"status": "stopped", "service": name})

# =========================
# RESTART
# =========================
@app.route("/api/restart/<name>")
def restart(name):
    os.system(f"systemctl restart {name}")
    return jsonify({"status": "restarted", "service": name})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)