#!/usr/bin/env bash
createlvm=true
deletelvm=false
dsksize="0"
disks=$(lsblk -f -d -b -n  -oNAME,SIZE,FSTYPE| egrep -v "xfs|ext3|ext4|btrfs|sr0")
while IFS= read -r line
do
tmpsize=$(echo $line|awk {'print $2'})
tmpname=$(echo $line|awk {'print $1'})
  if [[ "$dsksize" = "0" ]]
    then
      dsksize=$tmpsize
      dskname=$tmpname
  elif [[ "$dsksize" -gt "$tmpsize" ]]
    then
      dsksize=$tmpsize
      dskname=$tmpname
  fi
done <<< "$disks"
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