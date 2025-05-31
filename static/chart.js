const tempCtx = document.getElementById('temperatureChart').getContext('2d');
const pressureCtx = document.getElementById('pressureChart').getContext('2d');

const temperatureChart = new Chart(tempCtx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [{
            label: 'Nhiệt độ (°C)',
            borderColor: 'red',
            backgroundColor: 'rgba(255,0,0,0.1)',
            data: [],
            fill: true,
            tension: 0.3
        }]
    },
    options: {
        responsive: true,
        scales: {
            x: {
                title: { display: true, text: 'Thời gian' }
            },
            y: {
                beginAtZero: false,
                title: { display: true, text: 'Nhiệt độ (°C)' }
            }
        }
    }
});

const pressureChart = new Chart(pressureCtx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [{
            label: 'Áp suất (hPa)',
            borderColor: 'blue',
            backgroundColor: 'rgba(0,0,255,0.1)',
            data: [],
            fill: true,
            tension: 0.3
        }]
    },
    options: {
        responsive: true,
        scales: {
            x: {
                title: { display: true, text: 'Thời gian' }
            },
            y: {
                beginAtZero: false,
                title: { display: true, text: 'Áp suất (hPa)' }
            }
        }
    }
});

const temperatureList = [];
const pressureList = [];

function updateChart() {
    fetch('/sensor')
        .then(response => response.json())
        .then(data => {
            if (!data.input || !data.input.temperature || !data.input.pressure) return;

            const temperature = data.input.temperature;
            const pressure = data.input.pressure;

            const now = new Date();

            const options = {
                timeZone: 'Asia/Ho_Chi_Minh',
                weekday: 'long',
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            };

            const fullTimeStr = new Intl.DateTimeFormat('vi-VN', options).format(now);

            const timeOnlyOptions = {
                timeZone: 'Asia/Ho_Chi_Minh',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            };
            const timeStr = new Intl.DateTimeFormat('vi-VN', timeOnlyOptions).format(now);

            document.getElementById('currentTime').textContent = `Thời gian hiện tại: ${fullTimeStr}`;

            temperatureChart.data.labels.push(timeStr);
            temperatureChart.data.datasets[0].data.push(temperature);
            if (temperatureChart.data.labels.length > 20) {
                temperatureChart.data.labels.shift();
                temperatureChart.data.datasets[0].data.shift();
            }
            temperatureChart.update();

            pressureChart.data.labels.push(timeStr);
            pressureChart.data.datasets[0].data.push(pressure);
            if (pressureChart.data.labels.length > 20) {
                pressureChart.data.labels.shift();
                pressureChart.data.datasets[0].data.shift();
            }
            pressureChart.update();

            temperatureList.unshift(`${timeStr} - ${temperature}°C`);
            if (temperatureList.length > 10) temperatureList.pop();
            document.getElementById('temperatureList').innerHTML = temperatureList.map(item => `<li>${item}</li>`).join('');

            pressureList.unshift(`${timeStr} - ${pressure} hPa`);
            if (pressureList.length > 10) pressureList.pop();
            document.getElementById('pressureList').innerHTML = pressureList.map(item => `<li>${item}</li>`).join('');

            if (data.prediction) {
                document.getElementById('predictionResult').textContent = `Dự đoán: ${data.prediction}`;
            }
        })
        .catch(error => {
            console.error('Lỗi khi lấy dữ liệu:', error);
        })
        .finally(() => {
            setTimeout(updateChart, 500);
        });
}

updateChart();