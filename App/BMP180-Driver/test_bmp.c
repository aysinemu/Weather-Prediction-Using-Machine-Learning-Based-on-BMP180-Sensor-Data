//Nguyễn Châu Tấn Cường - 23146007
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <errno.h>

#define DEVICE_PATH "/dev/bmp180"

#define BMP180_IOCTL_MAGIC 'b'
#define BMP180_IOCTL_READ_TEMP  _IOR(BMP180_IOCTL_MAGIC, 1, int)
#define BMP180_IOCTL_READ_PRESS _IOR(BMP180_IOCTL_MAGIC, 2, int)

int main() {
    int fd;
    int data;

    fd = open(DEVICE_PATH, O_RDONLY);
    if (fd < 0) {
        perror("Failed to open the device");
        return errno;
    }

    if (ioctl(fd, BMP180_IOCTL_READ_TEMP, &data) < 0) {
        perror("Failed to read temperature");
        close(fd);
        return errno;
    }
    printf("Temperature (raw): %d\n", data);

    if (ioctl(fd, BMP180_IOCTL_READ_PRESS, &data) < 0) {
        perror("Failed to read pressure");
        close(fd);
        return errno;
    }
    printf("Pressure (raw): %d\n", data);

    close(fd);
    return 0;
}
