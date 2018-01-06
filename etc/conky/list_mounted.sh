#!/bin/bash
# Thanks to lancasrj:
# http://www.linuxforums.org/forum/ubuntu-linux/169744-conky-display-all-mounted-drives-post944444.html#post944444

cat /proc/mounts |  awk '{
   if ( $1 ~ /\/dev/ )
   {
      num_elem = split($2,str_array,"/")
      if (str_array[num_elem] == "")
      {
         str_array[num_elem] = "/";
      }
      printf "%.5s:${goto 40}${fs_type %s}${goto 80}${fs_bar 8,50 %s}${alignr}${fs_used %s} / ${fs_size %s} [${fs_used_perc %s}%]${voffset -2}\n", str_array[num_elem], $2, $2, $2, $2, $2, $2
   }
}'
