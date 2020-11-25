import ipaddress
import os


# Terraform VARs
PRIV_SUBNET = '${private_subnet}'
NUM_CPS = ${cp_count}
NUM_WORKERS = ${worker_count}
CLUSTER_NAME = '${cluster_name}'

num_total = NUM_CPS + NUM_WORKERS
cp_string = ''
worker_string = ''

for i in range(0, NUM_CPS):
    cp_string += "      - address: {}\n".format(list(ipaddress.ip_network(PRIV_SUBNET).hosts())[i].compressed)

for i in range(NUM_CPS, num_total):
    worker_string += "  - address: {}\n".format(list(ipaddress.ip_network(PRIV_SUBNET).hosts())[i].compressed)

cluster_vip = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-1].compressed
ingress_vip = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-2].compressed
lb_vip_end = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-2].compressed
lb_vip_start = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-155].compressed
lb_vip_range = "{}-{}".format(lb_vip_start, lb_vip_end)

file_path = "/root/baremetal/bmctl-workspace/{0}/{0}.yaml".format(CLUSTER_NAME)
# String Replacements
os.system("sed -i 's|      - address: <Machine 1 IP>|{}|g' {}".format(cp_string,
          file_path).encode("unicode_escape").decode("utf-8"))
os.system("sed -i 's|  - address: <Machine 2 IP>|{}|g' {}".format(worker_string,
          file_path).encode("unicode_escape").decode("utf-8"))
os.system("sed -i 's|controlPlaneVIP: 10.0.0.8|controlPlaneVIP: {}|g' {}".format(cluster_vip, file_path))
os.system("sed -i 's|# ingressVIP: 10.0.0.2|ingressVIP: {}|g' {}".format(ingress_vip, file_path))
os.system("sed -i 's|#   - 10.0.0.1-10.0.0.4|  - {}|g' {}".format(lb_vip_range, file_path))

