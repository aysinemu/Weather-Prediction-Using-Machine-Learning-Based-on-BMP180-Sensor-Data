import requests
import pandas as pd
from datetime import datetime, timedelta

API_KEY = 'XXXXXXXXXXXXXXXXXXX' 
LOCATION = 'Ho Chi Minh City'
FORMAT = 'json'
TIME_STEP = 24 
BASE_URL = 'https://api.worldweatheronline.com/premium/v1/past-weather.ashx'

end_date = datetime.today()
start_date = end_date - timedelta(days=7300)

delta = timedelta(days=30)
all_data = []

while start_date < end_date:
    date_str = start_date.strftime('%Y-%m-%d')
    next_date = min(start_date + delta, end_date)
    end_str = next_date.strftime('%Y-%m-%d')

    print(f"Đang lấy dữ liệu từ {date_str} đến {end_str}")

    params = {
        'key': API_KEY,
        'q': LOCATION,
        'date': date_str,
        'enddate': end_str,
        'tp': TIME_STEP,
        'format': FORMAT
    }

    response = requests.get(BASE_URL, params=params)
    data = response.json()

    try:
        for day in data['data']['weather']:
            for hourly in day['hourly']:
                all_data.append({
                    'date': day['date'],
                    'time': hourly['time'],
                    'temperature_C': hourly['tempC'],
                    'pressure_mb': hourly['pressure'],
                    'humidity': hourly['humidity'],
                    'wind_kph': hourly['windspeedKmph'],
                    'description': hourly['weatherDesc'][0]['value']
                })
    except KeyError:
        print("Lỗi khi xử lý dữ liệu:", data)

    start_date = next_date + timedelta(days=1)

df = pd.DataFrame(all_data)
df.to_csv('/home/pi/Desktop/App/BMP180-Driver/ai/data/hcm_weather.csv', index=False)
print("Đã lưu thành công vào 'hcm_weather_past_year.csv'")
