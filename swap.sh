#!/bin/sh

apt-get install -y iproute2

mkdir -p /user/.ssh
chmod 700 /user/.ssh
if [ ! -f /user/.ssh/id_docker ]; then
echo -e "\n\n\n" | ssh-keygen -N "" -f /user/.ssh/id_docker
echo "=> Updating Authorized Keys"
touch /user/.ssh/authorized_keys
chmod 600 /user/.ssh/authorized_keys
cat /user/.ssh/id_docker.pub >> /user/.ssh/authorized_keys
fi
DOCKER_HOST=$(ip route|awk '/default/ { print $3  }')
echo "=> Creating swap on ${DOCKER_HOST}"
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker fallocate -l 8G /swapfile
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker chmod 600 /swapfile
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mkswap /swapfile
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker swapon /swapfile
echo "=> Setting sysctl on ${DOCKER_HOST}"
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.swappiness=67
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.vfs_cache_pressure=83
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.page-cluster=1
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.dirty_background_ratio=18
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.dirty_ratio=18
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl kernel.yield_type=1
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl kernel.io_delay_type=2
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl net.ipv4.tcp_congestion_control=bbr

echo "=> try enable zswap and tune on ${DOCKER_HOST}"
echo "mount 0 \/";mount
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker apt-get install -y jitterentropy-rngd
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount -o remount,rw /
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker modprobe zswap
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mkdir /var/msys
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount -rw -t sysfs sysfs /var/msys
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo zsmalloc > /var/msys/module/zswap/parameters/zpool
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo lz4 > /var/msys/module/zswap/parameters/compressor
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo Y > /var/msys/module/zswap/parameters/enabled
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mkdir /var/mdebug
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount -rw -t debugfs debugfs /var/mdebug
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 2 > /var/mdebug/sched/tunable_scaling
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 4100000 > /var/mdebug/sched/latency_ns
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 620000 > /var/mdebug/sched/min_granularity_ns
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 360000 > /var/mdebug/sched/wakeup_granularity_ns
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 400000 > /var/mdebug/sched/migration_cost_ns
echo "mount 1 \/";mount
exit 0
