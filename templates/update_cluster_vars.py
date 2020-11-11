import ipaddress
import os


# Terraform VARs
PRIV_SUBNET = '${private_subnet}'
NUM_MASTERS = ${master_count}
NUM_WORKERS = ${worker_count}
CLUSTER_NAME = '${cluster_name}'

num_total = NUM_MASTERS + NUM_WORKERS
master_string = ''
worker_string = ''

for i in range(0, NUM_MASTERS):
    master_string += "      - address: {}\n".format(list(ipaddress.ip_network(PRIV_SUBNET).hosts())[i+1].compressed)

for i in range(NUM_MASTERS, num_total):
    worker_string += "  - address: {}\n".format(list(ipaddress.ip_network(PRIV_SUBNET).hosts())[i+1].compressed)

cluster_vip = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-1].compressed
ingress_vip = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-2].compressed
lb_vip_end = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-2].compressed
lb_vip_start = list(ipaddress.ip_network(PRIV_SUBNET).hosts())[-155].compressed
lb_vip_range = "{}-{}".format(lb_vip_start, lb_vip_end)

file_path = "/root/baremetal/bmctl-workspace/{0}/{0}.yaml".format(CLUSTER_NAME)
# String Replacements
os.system("sed -i 's|      - address: <Machine 1 IP>|{}|g' {}".format(master_string,
          file_path).encode("unicode_escape").decode("utf-8"))
os.system("sed -i 's|  - address: <Machine 2 IP>|{}|g' {}".format(worker_string,
          file_path).encode("unicode_escape").decode("utf-8"))
os.system("sed -i 's|controlPlaneVIP: 10.0.0.8|controlPlaneVIP: {}|g' {}".format(cluster_vip, file_path))
os.system("sed -i 's|ingressVIP: 10.0.0.2|ingressVIP: {}|g' {}".format(ingress_vip, file_path))
os.system("sed -i 's|10.0.0.1-10.0.0.4|{}|g' {}".format(lb_vip_range, file_path))
