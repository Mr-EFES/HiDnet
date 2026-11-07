package packetpipe

import (
	"errors"
	"io"
	"os"
	"syscall"
	"time"
)

func Open() (*os.File, *os.File, error) {
	device, fd, err := OpenDescriptor()
	if err != nil {
		return nil, nil, err
	}
	return device, os.NewFile(uintptr(fd), "hidnet-gateway"), nil
}

func OpenDescriptor() (*os.File, int, error) {
	fds, err := syscall.Socketpair(syscall.AF_UNIX, syscall.SOCK_DGRAM, 0)
	if err != nil {
		return nil, -1, err
	}
	for _, fd := range fds {
		syscall.CloseOnExec(fd)
		if err := syscall.SetNonblock(fd, true); err != nil {
			syscall.Close(fds[0])
			syscall.Close(fds[1])
			return nil, -1, err
		}
	}
	return os.NewFile(uintptr(fds[0]), "hidnet-device"), fds[1], nil
}

func Read(file *os.File, target []byte) (int, error) {
	if err := file.SetReadDeadline(time.Now().Add(250 * time.Millisecond)); err != nil {
		return 0, err
	}
	n, err := file.Read(target)
	if errors.Is(err, os.ErrDeadlineExceeded) {
		return 0, nil
	}
	return n, err
}

func Write(file *os.File, packet []byte) (int, error) {
	if len(packet) < 20 || len(packet) > 1500 {
		return 0, errors.New("invalid packet length")
	}
	if packet[0]>>4 == 6 {
		return len(packet), nil
	}
	if packet[0]>>4 != 4 {
		return 0, errors.New("invalid IP version")
	}
	if err := file.SetWriteDeadline(time.Now().Add(100 * time.Millisecond)); err != nil {
		return 0, err
	}
	n, err := file.Write(packet)
	if err == nil && n != len(packet) {
		err = io.ErrShortWrite
	}
	return n, err
}
