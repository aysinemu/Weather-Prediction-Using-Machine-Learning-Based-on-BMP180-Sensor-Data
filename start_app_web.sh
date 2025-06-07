cd ~/Desktop/App/BMP180-Driver/

source web/bin/activate

sudo rmmod bmp280_i2c
sudo rmmod bmp280_spi
sudo rmmod bmp280
sudo insmod bmp180_driver.ko
sudo rmmod bmp280_i2c
sudo rmmod bmp280

sudo /home/pi/Desktop/App/BMP180-Driver/web/bin/uvicorn web:app --host 0.0.0.0 --port 8000 --reload &

sleep 30

ngrok http http://localhost:8000
