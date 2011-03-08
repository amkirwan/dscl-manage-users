#!/bin/bash 

# Add OD group
# Usage:
#		[-h] help
#		[-v] version
#		[-g[ Group(s) to delete
#		[-n] Nodename default is /LDAPv3/127.0.0.1

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
DIRADMIN="diradmin"
DIRADMINPW="onetime"
DEFAULT_GROUP="workgroup"
ADMIN_GROUP="bwanadmingroup"
LDAP_ADMIN_GROUP="admin"
LOCAL_ADMIN_GROUP="admin"

export PATH
shopt -s nocasematch

EXITCODE=0
PROGRAM=`basename $0`
VERSION=1.0

error()
{
	echo "$@" 1>&2
	usage_and_exit 1
}

usage()
{
	cat <<EOF
Usage:
	$PROGRAM
			[-h] help
			[-v] version
			[-g] Group(s) to delete
			[-n] Nodename default is /LDAPv3/127.0.0.1
EOF
}

usage_and_exit()
{
	usage
	exit $1
}

version()
{
	echo "$PROGRAM version $VERSION"
}

warning()
{
	echo "$@" 1>&2
	EXITCODE=`expr $EXITCODE + 1`
}


yes_no()
{
	case $1 in
	yes | y)
		return 0
		;;
	no | n)
		return 1
		;;
	-*) error "Unrecognized option: $1"
		return 1
		;;
	*)
		break
		;;
	esac
}

delete_group()
{
	dscl -u $DIRADMIN -P $DIRADMINPW $nodename -delete /Groups/$group 
	dsmemberutil flushcache
	echo "## Deleted the group $group in the directory $nodename"
}

users=
groups= 
make_admin=false
nodename='/LDAPv3/127.0.0.1'

while getopts :hvu:g:n: opt
do
	case $opt in
	h)	usage_and_exit 0
		;;
	v)	version
		exit 0
		;;
	g)	groups=$OPTARG
	 	;;  
	n)  nodename=$OPTARG
		;;
	'?') echo "$0: invalid opton -$OPTARG" >&2
		 usage_and_exit 0
		 exit 1
		 ;;	
	esac
done


group_proc=`echo $groups | sed 's/,//g'`
for group in $group_proc
do
	if [[ `dscl $nodename -read /Groups/$group 2>/dev/null | grep -c RecordName:` -eq 1 ]]; then
		members=`dscl $nodename -read /Groups/$group GroupMembership | cut -d : -f 2`
		num_members=`dscl $nodename -read /Groups/$group GroupMembership | cut -d : -f 2 | wc -w`
		echo "############################################"
		echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		echo "############################################"
		echo "## Members of \"$group\": $members"
		echo -n "Are you sure you want to delete the group: \"$group\" with $num_memembers members(yes,no)? "
		read response
		
		if yes_no $response -eq 0; then
			delete_group
		fi
	else
		echo "############################################"
		echo "$group does not exist with that RecordName:"
		echo "############################################"
	fi	
done

exit 0
