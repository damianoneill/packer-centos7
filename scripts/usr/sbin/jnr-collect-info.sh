#!/bin/bash
# A Linux Shell script to collect information on your network configuration.

FILEPARAMETER=$1


#####################
### Main Function ###
#####################
main(){
	chk_root
	getOutputFile
  dump_info
}

#####################################
### Must execute as the root user ###
#####################################
chk_root(){
	local meid=$(id -u)
	if [ $meid -ne 0 ];
	then
		reportError "You must be root user to run this tool"
	fi
}

#####################################
### Writes the output file header ###
#####################################
write_header(){
	echo "---------------------------------------------------" >> $OUTPUT
	echo "$@" >> $OUTPUT
	echo "---------------------------------------------------"  >> $OUTPUT
}

#####################################
### Writes the output file footer ###
#####################################
write_footer(){
	echo "---------------------------------------------------" >> $OUTPUT
	echo >> $OUTPUT
	echo >> $OUTPUT
}

#################################################################
### Grabs relevent system information using builtin utilities ###
#################################################################
dump_info(){

	write_header "System information" >$OUTPUT
	  uname -a >> $OUTPUT
  write_footer
	write_header "Hardware" >>$OUTPUT
	  lshw -short >> $OUTPUT
  write_footer
	write_header "Block Devices" >>$OUTPUT
	  lsblk >> $OUTPUT
  write_footer
	write_header "Ethernet Interface" >>$OUTPUT
		ifconfig eth0 >> $OUTPUT
	write_footer

	write_header "Base Disk IO read performance" >>$OUTPUT
	  hdparm -t /dev/vda >> $OUTPUT
	write_footer
	write_header "Base Disk IO write performance" >>$OUTPUT
		dd if=/dev/zero of=/tmp/zero.dat bs=64k oflag=direct count=1000 2>>$OUTPUT
	  rm -f /tmp/zero.dat
	write_footer


	write_header "Collection complete"
	echo "The Network Configuration Info written To $OUTPUT."

}


########################################
### Set the output filename if given ###
########################################
getOutputFile() {

	if [ "${FILEPARAMETER}" != "" ]; then
	    OUTPUT="${FILEPARAMETER}"
	else
		OUTPUT="$(hostname).$(date +'%d-%m-%y').info.txt"
	fi

	touch ${OUTPUT} || reportError "Can't create output file ${OUTPUT}"
}

########################################
### Reports error condition and exit ###
########################################
reportError() {
    echo $* >&2
    exit 1
}

main $*
