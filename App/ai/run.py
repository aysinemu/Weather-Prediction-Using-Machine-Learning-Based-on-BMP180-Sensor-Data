import os
import joblib
import numpy as np
from collections import Counter

model_dir = './model'
model_files = [f for f in os.listdir(model_dir) if f.endswith('.pkl') and f != 'scaler.pkl']

scaler = joblib.load(os.path.join(model_dir, 'scaler.pkl'))

models = {}
for model_file in model_files:
    model_name = model_file.replace('.pkl', '').replace('_', ' ')
    model_path = os.path.join(model_dir, model_file)
    models[model_name] = joblib.load(model_path)

temperature_C = float(input("Nhập nhiệt độ (°C): "))
pressure_mb = float(input("Nhập áp suất (mb): "))

input_data = np.array([[temperature_C, pressure_mb]])
input_scaled = scaler.transform(input_data)

predictions = []

print("\n🔍 Dự đoán của từng mô hình:")
for name, model in models.items():
    pred = model.predict(input_scaled)[0]
    predictions.append(pred)
    print(f"{name}: {pred}")

final_prediction = Counter(predictions).most_common(1)[0][0]
print("\n✅ Kết quả cuối cùng sau Voting:", "Rain" if final_prediction == 1 else "Sunny")
