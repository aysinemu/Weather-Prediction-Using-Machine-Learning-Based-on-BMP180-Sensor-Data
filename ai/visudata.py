import pandas as pd
import matplotlib.pyplot as plt
import os

df = pd.read_csv('./data/weather_opti_labeled.csv')

X = df[['temperature_C', 'pressure_mb']].values
y = df['description'].values

label_descriptions = {
    # 0: "Moderate or heavy rain shower",
    # 1: "Patchy rain possible",
    # 2: "Moderate rain at times",
    # 3: "Cloudy",
    # 4: "Heavy rain at times",
    # 5: "Overcast",
    # 6: "Sunny",
    # 7: "Partly cloudy",
    # 8: "Light rain shower",
    # 9: "Patchy light rain",
    # 10: "Light drizzle"
    0: "Sunny",
    1: "Rain"
}

num_classes = len(label_descriptions)

cmap = plt.get_cmap('tab10')
colors = [cmap(i % 10) for i in range(num_classes)]

plt.figure(figsize=(12, 8))

for label in range(num_classes):
    idx = (y == label)
    plt.scatter(X[idx, 0], X[idx, 1], 
                color=colors[label], label=f'{label}: {label_descriptions[label]}', 
                alpha=0.7, edgecolors='k')

plt.xlabel('Temperature (°C)')
plt.ylabel('Pressure (mb)')
plt.title('Weather Data Visualization with Label Descriptions')
plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
plt.grid(True)
plt.tight_layout()

output_dir = '/home/pi/Desktop/App/BMP180-Driver/visualize'
os.makedirs(output_dir, exist_ok=True)

output_path = os.path.join(output_dir, 'weather_opti_visudata.png')
plt.savefig(output_path, dpi=300, bbox_inches='tight')

print(f'Biểu đồ đã được lưu tại: {output_path}')
