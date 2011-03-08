#!/bin/bash 

# Add OD group
# Usage:
#		[-h] help
#		[-v] version
#		[-u] Partner(s) username(s) to add to the group
#		[-g[ Group(s) to add
#		[-n] Nodename default is /LDAPv3/127.0.0.1

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
DIRADMIN="diradmin"
DIRADMINPW="CHANGE_ME"
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
			[-u] Partner(s) Augmented username(s) to add to the group
			[-g] Group(s) to add
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

create_group()
{
	dseditgroup -u $DIRADMIN -P $DIRADMINPW -o create -n $nodename -r $group $group
	dscl -u $DIRADMIN -P $DIRADMINPW $nodename -create /Groups/$group OwnerGUID $owner_guid
	echo "## Created the group $group in the directory $nodename"
}

add_users_to_group()
{
	if [[ `dscl $nodename -read /Groups/$group 2>/dev/null | grep -c "^RecordName:"` -eq 1 ]]; then
		for user in $users
		do
			dseditgroup -u $DIRADMIN -P $DIRADMINPW -o edit -n $nodename -a $user -t user $group
			echo "## Added user $user to the group $group"
		done
	fi
}

users=
groups= 
nodename='/LDAPv3/127.0.0.1'

while getopts :hvu:g:n: opt
do
	case $opt in
	h)	usage_and_exit 0
		;;
	v)	version
		exit 0
		;;
	u)  users=$OPTARG
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


## create groups
group_proc=`echo $groups | sed 's/,//g'`
for group in $group_proc
do
	if [[ `dscl $nodename -read /Groups/$group 2>/dev/null | grep -c RecordName:` -eq 0 ]]; then
		echo "############################################"
		echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		echo "############################################"
		echo -n "Are you sure you want to create the group: $group (yes,no)? "
		read response
		
		if yes_no $response -eq 0; then
			user=`whoami`
		
			owner_guid=(`dscl /Search -read /Users/$user GeneratedUID | cut -d : -f 2 | sed 's/ //'`)
			create_group
			add_users_to_group
		fi
	else
		echo "############################################"
		echo "RecordName: $group already exists!"
		echo "############################################"
	fi	
done

exit 0
