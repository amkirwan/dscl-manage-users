#!/bin/bash 

# Add Augmented Users to Open Directory from Partners AD
# Usage:
#		[-h] help
#		[-v] version
#		[-a] make user an admin by adding to /Local/Defaults admin group along with 
#			 the /LDAPv3/127.0.0.1 admin group and bwanadmingroup	
#		[-u] Partners username to augments, add multiple with ""
#		[-g[ Extra groups to add to user, automatically added to workgroup
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
			[-a] make user an admin
			[-u] Partners username(s) to add
			[-g] additional group(s)
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

create_account()
{
		
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid RealName $RealName
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid GeneratedUID $GeneratedUID
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid PrimaryGroupID 20
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid UserShell /usr/bin/false
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid NFSHomeDirectory /var/empty
	dscl -u $DIRADMIN -P $DIRADMINPW /LDAPv3/127.0.0.1 -create /Augments/Users:$partners_uid UniqueID $UniqueID
	echo "########################################################"
	echo "Created augmented records for: $RealName"

}

add_to_groups()
{
	dseditgroup -u $DIRADMIN -P $DIRADMINPW -o edit -n /LDAPv3/127.0.0.1 -a $partners_uid -t user $DEFAULT_GROUP
	echo "########################################################"
	echo "## Added to group: $DEFAULT_GROUP"

	groups_proc=`echo $groups | sed 's/,//g'`
	for group in $groups_proc
	do
		if [[ $group != $DEFAULT_GROUP ]]; then
				if [[ `dscl /LDAPv3/127.0.0.1 -read /Groups/$group 2>/dev/null | grep -c RecordName:` -eq 1 ]]; then
					dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /LDAPv3/127.0.0.1 -a $partners_uid -t user $group
					echo "## Added to group: $group"
				else
					echo "################################"
					echo "The group $group does not exist."
				fi
		fi
	done

	if $make_admin; then
		dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /LDAPv3/127.0.0.1 -a $partners_uid -t user $ADMIN_GROUP
		dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /LDAPv3/127.0.0.1 -a $partners_uid -t user $LDAP_ADMIN_GROUP
		sudo dseditgroup -u $DIRADMIN -P $DIRADMINPW  -o edit -n /Local/Default -a $partners_uid -t user $LOCAL_ADMIN_GROUP
		echo "########################################################"
		echo "Added user: $partners_uid to admin group"
	fi

	dsmemberutil flushcache
}

create_homedir()
{
	if [[ ! -d /PHShome/$partners_uid ]]; then
		mkdir /PHShome/$partners_uid
		sudo chown $partners_uid /PHShome/$partners_uid
		sudo chmod 700 /PHShome/$partners_uid
		sudo chmod +a "$partners_uid allow list,add_file,search,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,readsecurity,file_inherit,directory_inherit" /PHShome/$partners_uid
		echo "## Created homedir in /PHShome/$partners_uid"
	else
		echo "## Homedir in /PHShome/$partners_uid already exists"
	fi

}

if [ $# -eq 0 ]; then
	usage_and_exit 1
fi

users=
groups= 
make_admin=false

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
	a)  make_admin=true
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
	if [[ `dscl /Active\ Directory/All\ Domains -read /Users/$partners_uid 2>/dev/null | grep -c RealName:` -eq 1 ]]; then
		if [[ `dscl /Search read /Augments/Users:$partners_uid 2>/dev/null | grep -c RealName:` -eq 0 ]]; then
			
			user_info=(`dscl /Active\ Directory/All\ Domains -read /Users/$partners_uid GeneratedUID RealName UniqueID | cut -d : -f 2 | sed 's/, /,/g'`)
			GeneratedUID=${user_info[0]}
			RealName=${user_info[1]}
			UniqueID=${user_info[2]}
			
			echo "############################################"
			echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
			echo "############################################"
			echo -n "Are you sure you want to create an augmented record for user: $partners_uid, \"$RealName\" (yes, no)? "
			read response
	
			if  yes_no $response -eq 0 ; then
				create_account 
				add_to_groups
				create_homedir
			fi
	 	else
			echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
			echo "Augmented record $partners_uid already exists"
			echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		fi
	else
		echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		echo "Cannot find the user $partners_uid in Active Directory"
		echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	fi	
done

exit 0
