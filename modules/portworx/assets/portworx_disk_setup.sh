#!/usr/bin/env bash
createlvm=true
deletelvm=false
dsksize="0"

function largest_free_disk {
  lsblk -f -d -b -n -oNAME,SIZE | while read disk size; do
    # ignore disks with filesystems
    if ! lsblk -f -b -n  -oNAME,SIZE,FSTYPE -i /dev/$disk | egrep "xfs|ext3|ext4|btrfs|sr0" >/dev/null; then
      echo -en "$disk $size"
    fi
  done | sort -n -k2 | head -n1 | cut -f1 -d" "
}


dskname=$(largest_free_disk)
echo "Will use $dskname for Portworx KVDB LVM by running the following commands(will only run if createlvm=true)"
dev="/dev/$dskname"
echo "pvcreate $dev"
echo "vgcreate pwx_vg $dev"
echo "lvcreate -l 100%FREE -n pwxkvdb pwx_vg"
if $createlvm; then
    pvcreate $dev
    vgcreate pwx_vg $dev
    lvcreate -l 100%FREE -n pwxkvdb pwx_vg
fi
if $deletelvm; then
   lvremove /dev/pwx_vg/pwxkvdb
   vgremove pwx_vg
   pvremove $dev
   wipefs -a $dev
fi
