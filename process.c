// Nguyễn Châu Tấn Cường - 23146007
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <string.h>

#define DEVICE_PATH "/dev/bmp180"

#define BMP180_IOCTL_MAGIC 'b'
#define BMP180_IOCTL_READ_TEMP  _IOR(BMP180_IOCTL_MAGIC, 1, int)
#define BMP180_IOCTL_READ_PRESS _IOR(BMP180_IOCTL_MAGIC, 2, int)

#define SAMPLE_COUNT 5

int main() {
    int fd;
    int raw_temp, raw_press;

    int AC1 = 8492, AC2 = -1056, AC3 = -14273;
    unsigned int AC4 = 33682, AC5 = 25835, AC6 = 15882;
    int B1 = 6515, B2 = 36, MB = -32768, MC = -11786, MD = 2311;

    int temp_buffer[SAMPLE_COUNT] = {0};
    int press_buffer[SAMPLE_COUNT] = {0};
    int initialized = 0;

    fd = open(DEVICE_PATH, O_RDONLY);
    if (fd < 0) {
        perror("Failed to open the device");
        return errno;
    }

    printf("Starting BMP180 continuous reading (Press Ctrl+C to stop)...\n");

    while (1) {
        if (ioctl(fd, BMP180_IOCTL_READ_TEMP, &raw_temp) < 0 ||
            ioctl(fd, BMP180_IOCTL_READ_PRESS, &raw_press) < 0) {
            perror("Failed to read data");
            break;
        }

        if (initialized < SAMPLE_COUNT) {
            temp_buffer[initialized] = raw_temp;
            press_buffer[initialized] = raw_press;
            initialized++;
        } else {
            memmove(&temp_buffer[0], &temp_buffer[1], (SAMPLE_COUNT - 1) * sizeof(int));
            memmove(&press_buffer[0], &press_buffer[1], (SAMPLE_COUNT - 1) * sizeof(int));
            temp_buffer[SAMPLE_COUNT - 1] = raw_temp;
            press_buffer[SAMPLE_COUNT - 1] = raw_press;
        }

        if (initialized == SAMPLE_COUNT) {
            int sum_temp = 0, sum_press = 0;
            for (int i = 0; i < SAMPLE_COUNT; i++) {
                sum_temp += temp_buffer[i];
                sum_press += press_buffer[i];
            }
            int avg_temp = sum_temp / SAMPLE_COUNT;
            int avg_press = sum_press / SAMPLE_COUNT;

            long X1, X2, B5, B6, X3, B3, p;
            unsigned long B4, B7;
            int temp;
            int oss = 0;

            X1 = ((avg_temp - AC6) * AC5) >> 15;
            X2 = (MC << 11) / (X1 + MD);
            B5 = X1 + X2;
            temp = (B5 + 8) >> 4;

            B6 = B5 - 4000;
            X1 = (B2 * ((B6 * B6) >> 12)) >> 11;
            X2 = (AC2 * B6) >> 11;
            X3 = X1 + X2;
            B3 = (((AC1 * 4 + X3) << oss) + 2) >> 2;

            X1 = (AC3 * B6) >> 13;
            X2 = (B1 * ((B6 * B6) >> 12)) >> 16;
            X3 = ((X1 + X2) + 2) >> 2;
            B4 = (AC4 * (unsigned long)(X3 + 32768)) >> 15;

            B7 = ((unsigned long)avg_press - B3) * (50000 >> oss);

            if (B7 < 0x80000000)
                p = (B7 * 2) / B4;
            else
                p = (B7 / B4) * 2;

            X1 = (p >> 8) * (p >> 8);
            X1 = (X1 * 3038) >> 16;
            X2 = (-7357 * p) >> 16;
            p = p + ((X1 + X2 + 3791) >> 4);

            printf("Temp: %.1f °C | Pressure: %.2f hPa\n", temp / 10.0, p / 100.0);
        } else {
            printf("Collecting sample %d/%d...\n", initialized, SAMPLE_COUNT);
        }

        usleep(500000); 
    }

    close(fd);
    return 0;
}
