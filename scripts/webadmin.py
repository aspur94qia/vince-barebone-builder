from flask import Flask, request, render_template_string
import os

app = Flask(__name__)

HTML_PAGE = """
<!DOCTYPE html>
<html>
<head><title>Azkia Router Admin</title></head>
<body>
  <h2>Azkia 4G / Wi-Fi Control Panel</h2>
  <form action="/connect" method="post">
    <label>Nama Wi-Fi (SSID):</label><br>
    <input type="text" name="ssid"><br><br>
    <label>Password Wi-Fi:</label><br>
    <input type="password" name="pass"><br><br>
    <input type="submit" value="Hubungkan Wi-Fi">
  </form>
</body>
</html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_PAGE)

@app.route('/connect', methods=['POST'])
def connect():
    ssid = request.form['ssid']
    password = request.form['pass']
    os.system(f'cmd wifi connect-network "{ssid}" wpa2 "{password}"')
    return f"Berhasil dihubungkan ke {ssid}!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
