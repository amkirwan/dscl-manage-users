#!/bin/bash 

# Delete Augmented Users in Open Directory 
# Usage:
#		[-h] help
#		[-v] version
#		[-u] Parnters username to remove from Open Directory
#		[-t] Do not archive users home directory
#

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
			[-u] Partners username to remove from Open Directory
			[-t] Do not archive users home directory
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



delete_from_groups()
{
	echo "########################################################"

	group_list=`dscl /LDAPv3/127.0.0.1 -list /Groups`
	for group in $group_list
	do
		group_members=`dscl /LDAPv3/127.0.0.1 -read /Groups/$group GroupMembership 2>/dev/null`
		if [ `echo $group_membership | grep -c 'GroupMembership: '` -ne 0 ]; then
			group_members=`echo $group_members | sed -e 's/.*GroupMembership: //'`
			echo "$group: $group_members"
		fi
	
		for member in $group_members
		do
			if [ "$member" = "$partners_uid" ]; then
				echo "Removing user $partners_uid from group: $group"
				dseditgroup -u $DIRADMIN -P $DIRADMINPW -o edit -n /LDAPv3/127.0.0.1 -d $partners_uid -t user $group
			fi
		done
	done
		
	# remove from local admin group if admin
	if [ `dseditgroup -o checkmember -n /Local/Default -m ak730 $LOCAL_ADMIN_GROUP | grep -c "yes"` -eq 1 ]; then
		echo "############################################"
		echo "Removing user from local admin group"
		dseditgroup -u $DIRADMIN -P $DIRADMINPW -o edit -n /Local/Default -d $partners_uid -t user $LOCAL_ADMIN_GROUP
	fi
}

delete_account()
{
	echo "########################################################"
	echo "Deleting user: $partners_uid"

	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -delete /Augments/Users:$partners_uid
	dsmemberutil flushcache
}

archive_homedir()
{
	if $archive; then
		if [[ -d /PHShome/$partners_uid ]]; then
			echo "############################################"
			echo "Archiving users home directory: /PHShome/$partners_uid"
			cd /PHShome
			sudo zip -r ${partners_uid}.zip $partners_uid
			sudo rm -rf /PHShome/$partners_uid
		fi
	fi	
}



if [ $# -eq 0 ]; then
	usage_and_exit 1
fi

users=
archive=true
while getopts :hvtu: opt
do
	case $opt in
	h)	usage_and_exit 0
		;;
	v)	version
		exit 0
		;;
	u)  users=$OPTARG
		;;
	t)	archive=false
	 	;;  
	'?') echo "$0: invalid opton -$OPTARG" >&2
		 usage_and_exit 0
		 exit 1
		 ;;	
	esac
done
		
## remove any commas put in to seperate users in " "
users_proc=`echo $users | sed 's/,//g'`
for partners_uid in $users_proc
do 
	if [[ `dscl /Search read /Augments/Users:$partners_uid 2>/dev/null | grep -c RealName:` -eq 1 ]]; then
			
		user_info=(`dscl /Active\ Directory/All\ Domains -read /Users/$partners_uid GeneratedUID RealName UniqueID | cut -d : -f 2 | sed 's/, /,/g'`)
		GeneratedUID=${user_info[0]}
		RealName=${user_info[1]}
		UniqueID=${user_info[2]}

		echo "############################################"
		echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		echo "############################################"
		echo -n "Are you sure you want to DELETE the augmented record for user: $partners_uid, $RealName (yes, no)? "
		read response

		if  yes_no $response -eq 0 ; then
			delete_from_groups 
			delete_account
			archive_homedir
		fi
	else
		echo "############################################"
		echo "Augmented record $partners_uid does not exists"
		echo "############################################"
	fi
done


exit 0
