
##########################################
# Author: Shabani Biboze
# Date: 05/01/2026
#
# This script outputs the node health
#
#Version: v1
########################################

echo "Print the disk space"
df -h

echo "Print the memory"
free -g

echo "Print the cpu"
nproc
