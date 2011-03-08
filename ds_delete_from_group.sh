#!/bin/bash 

# Delete Augmented user to OD group
# Usage:
#		[-h] help
#		[-v] version
#		[-a] delete user from admin group by deleting from /Local/Defaults admin group along with 
#			 the /LDAPv3/127.0.0.1 admin group and bwanadmingroup	
#		[-u] Partners username to augments, add multiple with ""
#		[-g[ Groups to delete user from 
#

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
			[-a] remove user from admin group
			[-u] Partners username(s) to use
			[-g] Group(s) to remove from
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

delete_from_group()
{
	groups_proc=`echo $groups | sed 's/,//g'`
	for group in $groups_proc
	do
		if [[ `dscl /LDAPv3/127.0.0.1 -read /Groups/$group 2>/dev/null | grep -c RecordName:` -eq 1 ]]; then
			if [[ `dseditgroup -o checkmember -n /LDAPv3/127.0.0.1 -m $partners_uid -t user $group | grep -c '^yes'` -eq 1 ]]; then
				echo "## Deleting user from group: $group"
				dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /LDAPv3/127.0.0.1 -d $partners_uid -t user $group
			else
				echo "## The $partners_uid is not a member of $group"
			fi
		else
			echo "################################"
			echo "The group $group does not exist."
		fi
	done

	if $remove_admin; then
		echo "########################################################"
		echo "Adding user: $partners_uid to admin group"

		dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /LDAPv3/127.0.0.1 -d $partners_uid -t user $ADMIN_GROUP
		dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /LDAPv3/127.0.0.1 -d $partners_uid -t user $LDAP_ADMIN_GROUP
		sudo dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /Local/Default -d $partners_uid -t user $LOCAL_ADMIN_GROUP
	fi

	dsmemberutil flushcache
}

users=
groups= 
remove_admin=false

while getopts :hvau:g: opt
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
	a)  remove_admin=true
		;;
	'?') echo "$0: invalid opton -$OPTARG" >&2
		 usage_and_exit 0
		 exit 1
		 ;;	
	esac
done
	
## remove any commas put in to seperate users in " "
users_proc=`echo $users | sed 's/,//g'`
for partners_uid  in $users_proc
do 
	if [[ `dscl /Search -read /Augments/Users:$partners_uid 2>/dev/null | grep -c RealName:` -eq 1 ]]; then
			
		user_info=(`dscl /Active\ Directory/All\ Domains -read /Users/$partners_uid GeneratedUID RealName UniqueID | cut -d : -f 2 | sed 's/, /,/g'`)
		GeneratedUID=${user_info[0]}
		RealName=${user_info[1]}
		UniqueID=${user_info[2]}

		echo "############################################"
		echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		echo "############################################"
		echo -n "Are you sure you want to delete $partners_uid from the group(s) [ $groups ] (yes,no)? "
		read response

		if  yes_no $response -eq 0 ; then
			delete_from_group		
		fi
	else
		echo "############################################"
		echo "Augmented record $partners_uid doesn't exist"
		echo "############################################"
	fi	
done

exit 0
