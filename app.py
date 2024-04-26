from flask import Flask, render_template, request
import speedtest

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/speedtest', methods=['POST'])
def run_speedtest():
    st = speedtest.Speedtest()
    st.get_best_server()
    download_speed = st.download() / 1024 / 1024  # Convert to Mbps
    upload_speed = st.upload() / 1024 / 1024  # Convert to Mbps
    return render_template('result.html', download_speed=download_speed, upload_speed=upload_speed)

if __name__ == '__main__':
    app.run(debug=True)

