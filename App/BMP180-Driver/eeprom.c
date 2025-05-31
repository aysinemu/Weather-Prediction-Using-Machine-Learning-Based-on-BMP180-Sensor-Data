#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>

#define BMP180_ADDR 0x77
#define CALIB_START 0xAA
#define CALIB_BYTES 22

int16_t read16(const unsigned char *buf, int idx) {
    return (buf[idx] << 8) | buf[idx + 1];
}

int main() {
    int file;
    const char *dev = "/dev/i2c-1";
    unsigned char calib_data[CALIB_BYTES];

    if ((file = open(dev, O_RDWR)) < 0) {
        perror("Failed to open I2C bus");
        return 1;
    }

    if (ioctl(file, I2C_SLAVE, BMP180_ADDR) < 0) {
        perror("Failed to connect to BMP180");
        close(file);
        return 1;
    }

    unsigned char reg = CALIB_START;
    if (write(file, &reg, 1) != 1) {
        perror("Failed to write calibration start register");
        close(file);
        return 1;
    }

    if (read(file, calib_data, CALIB_BYTES) != CALIB_BYTES) {
        perror("Failed to read calibration data");
        close(file);
        return 1;
    }

    int16_t AC1 = read16(calib_data, 0);
    int16_t AC2 = read16(calib_data, 2);
    int16_t AC3 = read16(calib_data, 4);
    uint16_t AC4 = read16(calib_data, 6);
    uint16_t AC5 = read16(calib_data, 8);
    uint16_t AC6 = read16(calib_data, 10);
    int16_t B1  = read16(calib_data, 12);
    int16_t B2  = read16(calib_data, 14);
    int16_t MB  = read16(calib_data, 16);
    int16_t MC  = read16(calib_data, 18);
    int16_t MD  = read16(calib_data, 20);

    printf("Calibration coefficients:\n");
    printf("AC1 = %d\n", AC1);
    printf("AC2 = %d\n", AC2);
    printf("AC3 = %d\n", AC3);
    printf("AC4 = %u\n", AC4);
    printf("AC5 = %u\n", AC5);
    printf("AC6 = %u\n", AC6);
    printf("B1  = %d\n", B1);
    printf("B2  = %d\n", B2);
    printf("MB  = %d\n", MB);
    printf("MC  = %d\n", MC);
    printf("MD  = %d\n", MD);

    close(file);
    return 0;
}

// Calibration coefficients:
// AC1 = 8492
// AC2 = -1056
// AC3 = -14273
// AC4 = 33682
// AC5 = 25835
// AC6 = 15882
// B1  = 6515
// B2  = 36
// MB  = -32768
// MC  = -11786
// MD  = 2311
