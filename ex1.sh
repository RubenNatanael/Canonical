#!/bin/bash

set -e

main_dir="ex1"
image_path="$main_dir/image"

function dependencies {
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install qemu-system-x86 build-essential busybox-static curl -y
}

echo "Starting script..."

mkdir -p "$image_path"

dependencies


# Create initramfs root filesystem
mkdir -p $image_path/{bin,dev,etc,home,lib,sbin,tmp,var,proc,sys,usr/bin,usr/sbin}

# Creati character devices
sudo mknod -m 660 "$image_path/dev/mem" c 1 1
sudo mknod -m 660 "$image_path/dev/tty2" c 4 2
sudo mknod -m 660 "$image_path/dev/tty3" c 4 3
sudo mknod -m 660 "$image_path/dev/tty4" c 4 4
sudo mknod -m 622 "$image_path/dev/console" c 5 1
sudo mknod -m 666 "$image_path/dev/null" c 1 3

sudo mknod -m 666 "$image_path/dev/ttyS0" c 4 64

# Create the init script
cat > $image_path/init << 'EOF'
#!/bin/sh
set -e

mount -t proc none /proc
mount -t sysfs none /sys

echo "hello world"
exec /bin/sh
EOF
chmod +x $image_path/init

# Copy busybox
cp /bin/busybox $image_path/bin/
chroot_path=$(realpath "$image_path")
sudo busybox --install "$chroot_path/bin"

# Build the initramfs
cd "$image_path"
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../image.cpio.gz
cd -

# Run QEMU
kernel_path=$(ls /boot/vmlinuz-* | grep -m1 "amd64\|generic")
echo "$kernel_path"

sudo qemu-system-x86_64 \
  -kernel "$kernel_path" \
  -initrd "$main_dir/image.cpio.gz" \
  -nographic \
  -append "console=ttyS0 init=/init"