from fastapi import FastAPI, Request, Form
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import uuid
import subprocess
import os
import time
import joblib
import numpy as np
import pandas as pd
import fcntl
import uvicorn
from collections import Counter
import struct

DEVICE_PATH = "/dev/bmp180"
BMP180_IOCTL_READ_TEMP = 0x80046201
BMP180_IOCTL_READ_PRESS = 0x80046202
SAMPLE_COUNT = 5

AC1, AC2, AC3 = 8492, -1056, -14273
AC4, AC5, AC6 = 33682, 25835, 15882
B1, B2 = 6515, 36
MB, MC, MD = -32768, -11786, 2311

model_dir = './ai/model'
model_files = [f for f in os.listdir(model_dir) if f.endswith('.pkl') and f != 'scaler.pkl']
WORK_DIR = Path("/home/pi/Desktop/App/BMP180-Driver")
# WORK_DIR = Path("M:\Embedded_System\App\BMP180-Driver")
STATIC_DIR = WORK_DIR / "static"
TEMP_DIR = STATIC_DIR / "temp"

app = FastAPI(docs_url=None, redoc_url=None)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory=WORK_DIR / "templates")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

fake_users = {
    "admin": {"password": "1", "position": "admin"},
    "guest": {"password": "1", "position": "lecture"},
}

@app.get("/")
async def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

scaler = joblib.load(os.path.join(model_dir, 'scaler.pkl'))
models = {}
for model_file in model_files:
    model_name = model_file.replace('.pkl', '').replace('_', ' ')
    model_path = os.path.join(model_dir, model_file)
    models[model_name] = joblib.load(model_path)

@app.get("/sensor")
def get_sensor_data():
    try:
        with open(DEVICE_PATH, "rb") as fd:
            temp_samples, press_samples = [], []
            for _ in range(SAMPLE_COUNT):
                buf_temp = bytearray(4)
                buf_press = bytearray(4)
                fcntl.ioctl(fd, BMP180_IOCTL_READ_TEMP, buf_temp, True)
                fcntl.ioctl(fd, BMP180_IOCTL_READ_PRESS, buf_press, True)
                raw_temp = struct.unpack("i", buf_temp)[0]
                raw_press = struct.unpack("i", buf_press)[0]
                temp_samples.append(raw_temp)
                press_samples.append(raw_press)

        avg_temp = sum(temp_samples) // SAMPLE_COUNT
        avg_press = sum(press_samples) // SAMPLE_COUNT

        X1 = ((avg_temp - AC6) * AC5) / 32768.0
        X2 = (MC * 2048.0) / (X1 + MD)
        B5 = X1 + X2
        temp = (B5 + 8.0) / 16.0 

        B6 = B5 - 4000.0
        X1 = (B2 * (B6 * B6 / 4096.0)) / 2048.0
        X2 = (AC2 * B6) / 2048.0
        X3 = X1 + X2
        B3 = ((AC1 * 4.0 + X3) + 2.0) / 4.0

        X1 = (AC3 * B6) / 8192.0
        X2 = (B1 * (B6 * B6 / 4096.0)) / 65536.0
        X3 = (X1 + X2 + 2.0) / 4.0
        B4 = (AC4 * (X3 + 32768.0)) / 32768.0

        B7 = (avg_press - B3) * 50000.0

        if B7 < 0x80000000:
            p = (B7 * 2.0) / B4
        else:
            p = (B7 / B4) * 2.0

        X1 = (p / 256.0) * (p / 256.0)
        X1 = (X1 * 3038.0) / 65536.0
        X2 = (-7357.0 * p) / 65536.0
        p = p + (X1 + X2 + 3791.0) / 16.0

        temperature = round(temp / 10.0, 4)
        pressure = round(p / 100.0, 4)

        input_data = pd.DataFrame([[temperature, pressure]], columns=["temperature_C", "pressure_mb"])
        input_scaled = scaler.transform(input_data)

        predictions = [model.predict(input_scaled)[0] for model in models.values()]
        final_prediction = Counter(predictions).most_common(1)[0][0]
        final_result = "Rain" if final_prediction == 1 else "Sunny"

        df_to_save = pd.DataFrame([[temperature, pressure, final_result]], columns=["temperature_C", "pressure_mb", "model_predict"])
        df_to_save.to_csv("./ai/data/result_predictions.csv", mode='a', index=False, header=False)

        return {
            "input": {
                "temperature": temperature,
                "pressure": pressure
            },
            "prediction": final_result
        }

    except Exception as e:
        return {"error": str(e)}

@app.post("/login")
async def login(username: str = Form(...), password: str = Form(...)):
    if username in fake_users and fake_users[username]["password"] == password:
        return {
            "success": True,
            "position": fake_users[username]["position"]
        }
    return {
        "success": False,
        "message": "Sai tên đăng nhập hoặc mật khẩu"
    }

@app.get("/weather", response_class=HTMLResponse)
async def weather_page(request: Request):
    return templates.TemplateResponse("weather.html", {"request": request})



# if __name__ == "__main__":
#     uvicorn.run("web:app", host="0.0.0.0", port=8000, reload=True)

# sudo /home/pi/Desktop/App/BMP180-Driver/web/bin/uvicorn web:app --host 0.0.0.0 --port 8000 --reload
# uvicorn web:app --host 0.0.0.0 --port 8000 --reload
# ngrok http http://localhost:8000
