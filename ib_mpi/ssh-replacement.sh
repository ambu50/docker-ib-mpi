#!/bin/bash
# is /usr/bin/ssh inside a docker container
# 05/11/2016 Antoine Schonewille
# 05/18/2016 Revision -A

# works with openssh supplied in RHEL 6 and 7

_LOCALHOST='localhost'
_LOCALIP='127.0.0'
_HOSTNAME=`hostname --short`
_HAS_PARAMS="bcDeFIiLlmOopRSWw"

while (( "$#" )); do
        _ONE=`echo $@|cut -f1 -d' '`
        _TWO=`echo $@|cut -f2 -d' '`
        # easy. if a word starts with an hyphen it's an option and it might come with a parameter
        if [ "`echo $_ONE | cut -b1`" == "-" ]; then
                _PARAM=$_PARAM' '$_ONE
                _PREV='option'
		if [ "$(echo $_HAS_PARAMS | grep `echo $_ONE | cut -b2`)" ] && [ "`echo $_ONE | cut -b3`" == "" ]; then
			_PARAM=$_PARAM' '$_TWO
			shift
		fi
        else
                # if the current word does not have a hyphen (no option) then we have two possibilities
                #  a: previous word wasn't an option (hyphen) 
		#  b: or the second word doesn't have a hyphen (part of command)
                # both cases then assume that the host must be the first word 
                if [ "$_PREV" != "option" ] || [ "`echo $_TWO | cut -b1`" != "-" ]; then 
                        _HOST=$_ONE
                        shift
                        _COMMAND=$@
                        break
                else
                        _PARAM=$_PARAM' '$_ONE
                        _PREV=''
                fi
        fi
        shift
done

#echo 'SSH = ssh ['$_PARAM'] ['$_HOST'] ['$_COMMAND']'

if [ "$_HOST" == "$_HOSTNAME" ] || [ "$_HOST" == "$_LOCALIP" ] || [ "$_HOST" == "$_LOCALHOST" ]; then
#        echo '-> LAUNCHING LOCAL <-'
        ~/docker/command $_COMMAND
        exit $?
else
#        echo '-> LAUNCHING REMOTELY '$_HOST' <-'
#        echo '-> '"$_COMMAND"
        _COMMAND=`echo $_COMMAND | sed -e 's/;/\\\;/g' | tr '"' "'"`
        /usr/bin/ssh_real $_PARAM $_HOST ~/docker/job "$_COMMAND"
        exit $?
fi

