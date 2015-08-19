# Colons cannot be escaped in the PATH, and therefore
# a colon ALWAYS separates PATH components.

escape () {
	# escape text to be embeded in single quotes
	if [ "${0##*/}" == "bash" ]; then
		echo "${1//\'/\\\'}"
	else
		echo "$1"|sed -e "s/'/\\\'/g"
	fi
}

pathappend () {
	# Ensures a directory is appended to a PATH-like variable,
	# specified on the second argument. If the second argument
	# is unspecified, PATH is assumed.
	# Double entries are suppressed.
	local newpath
	local variable
	local original
	variable=${2:-PATH};
	local IFS=':'
	for part in $(eval "echo \"\$$variable\""); do
		if [ "$part" != "$1" ]; then
		newpath=${newpath:+$newpath:}$part
		fi
	done

	# Append to the clean PATH
	newpath=${newpath+$newpath:}$1
	eval "export $variable=\$newpath"
}

pathprepend () {
	# Ensures a directory is prepended to a PATH-like variable,
	# specified on the second argument. If the second argument
	# is unspecified, PATH is assumed.
	# Double entries are suppressed.
	
	local newpath
	local variable
	variable=${2:-PATH};
	local IFS=':'
	for part in $(eval "echo \"\$$variable\""); do
		if [ "$part" != "$1" ]; then
		newpath=${newpath:+$newpath:}$part
		fi
	done

	# Prepend to the clean PATH
	newpath=$1${newpath+:$newpath}
	eval "export $variable=\$newpath"
}

# Set up paths
LOCAL_ROOT=$HOME/local
pathprepend $HOME/local/bin:$HOME/extra/MyFiles/Documents/Programming/Shell
pathprepend $LOCAL_ROOT/lib:$LOCAL_ROOT/usr/lib LD_LIBRARY_PATH
pathprepend $LOCAL_ROOT/include:$LOCAL_ROOT/usr/include CPATH


# Deprecated newer version of Perl. Now deleted.
if false; then
	PERL_ROOT=$HOME/perl5
	pathprepend $PERL_ROOT/bin
	pathprepend $PERL_ROOT/lib/perl5 PERL5LIB
	pathprepend $PERL_ROOT PERL_LOCAL_LIB_ROOT
	PERL_ROOT_ESCAPED=$(escape $PERL_ROOT)
	export PERL_MB_OPT="--install_base \'$PERL_ROOT_ESCAPED\'"
	export PERL_MM_OPT="INSTALL_BASE=\'$PERL_ROOT_ESCAPED\'"
fi

pathappend $LOCAL_ROOT/usr/lib/java/"*" CLASSPATH

# Set up environments
export MAIL="$HOME/Maildir"

[ -r ~/.bashrc ] && source ~/.bashrc
