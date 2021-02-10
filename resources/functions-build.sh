#!/bin/bash

##
# Replace naming conventions in a given file
# @param file_path path to a file where substitutions are made
##
function replace_naming_conventions {
	local file_path=$1
	perl -pi -e "s/$template_prefix/$new_prefix/g" $file_path
	perl -pi -e "s/$template_appname/$new_appname/g" $file_path
	perl -pi -e "s/$template_xroad/$new_xroad/g" $file_path
}

##
# Crop changelog entries to given version and add initial comment to oldest log entry.
# Assumes current directory is package source root directory.
# @param last_version oldest log entry version to be shown
# @param comment comment to be added to oldest changelog entry
##
function modify_changelog {
	local last_version=$1
	local comment=$2
	local last_version_regex="${last_version//./\\.}"; # Escape '.' character in version number
	# Remove all older versions than last_version
	perl -0777 -ni -e "print \"$&\n\" if /(?s).*?$last_version_regex.*?--.*?\n\n?/g" debian/changelog
	# Add initial comment to the beginning of oldest version block
	perl -pi -e "BEGIN{undef $/;} s/([^\n]+$last_version_regex[^\n]+\s+)/\1* $comment\n  /smg" debian/changelog
	
	# Replace naming conventions in changelog: X-Road not replaced with RoksNet in changelog, otherwise it looks incomprehensible
	perl -pi -e "s/$template_prefix/$new_prefix/g" debian/changelog
	perl -pi -e "s/$template_appname/$new_appname/g" debian/changelog
}

##
# Add application package conf.cfg replacement instruction that is run during package update.
# @param replacee text replaced
# @param replacement replacement text
# @param version package version where replacement applies (optional)
##
function add_config_replacement {
	local replacee="$1"
	local replacement="$2"
	local version="$3"
	local last_version="$(get_last_version)"	
	if [ "$version" == "" -o "$version" == "$last_version" ]
	then
		search_str='# config.cfg replacements done'
		cmd="perl -pi -e 's/$replacee/$replacement/g' /tmp/config.cfg.bkp"
		replacement_full=$'\t'"$cmd"$'\n'"$search_str"
		echo "Replacing '$search_str' with '$cmd'"
		perl -pi -e 'BEGIN {undef $/; $text = q{'"$search_str"'}; $text2=q{'"$replacement_full"'}
			} s/\Q$text\E/$text2\n\1/g' install-misp2-application.sh
	fi
}

##
# Add comment (as last entry) to changelog block with given version.
# Assumes current directory is package source root directory.
# @param version block version to be added the comment to
# @param comment comment to be added to the changelog block
##
function add_to_changelog {
	local version=$1
	local comment=$2
	local version_regex="${version//./\\.}"; # Escape '.' character in version number
	# Add comment to the end of changelog block with given version
	perl -pi -e "BEGIN{undef $/;} s/([^\n]+$version_regex.*?)(\s+--)/\1\n  * $comment\2/smg" debian/changelog
}

##
# Remove changelog comment (as last entry) to changelog block with given version.
# Assumes current directory is package source root directory.
# @param comment segment to be removed
##
function remove_changelog {
	local comment=$1
	perl -pi -e "BEGIN{undef $/;} s/(\s*\*[^\*]*$comment.*?)(\s*\*|\s*--)/\2/smg" debian/changelog
}

##
# Find if a whitespace-separated word list contains given word.
# E.g. 
# $ contains_word "firstword secondword thirdword" "secondword"
#   @returns true (status code 0)
# $ contains_word "firstword secondword thirdword" "secondw"
#   @returns false (status code 1), because 'secondw' does not match a full word in the list.
##
function contains_word {
	local content="$1"
	local search_term="$2"
	if echo $content | tr ' ' '\n' | grep -qw -- "$search_term"
	then
		return 0
	else
		return 1
	fi
}

##
# Find latest package version from changelog
# @param changelog file path (optional, if not given look from debian/changelog directory)
##
function get_last_version {
	local changelog_file="$1"
        if [ "$changelog_file" == "" ]
        then
            changelog_file="debian/changelog"
        fi
	local changelog_version=$(perl -p -e "BEGIN{undef $/;} s/^.*? \(([^\)]+).*$/\1/smg" "$changelog_file")
	echo "$changelog_version"
}

##
# Check WAR POM version if it matches application package version.
# If it matches, show message, if versions do not match, prompt user whether to continue with the build.
# Assumes current directory is located directly within package source root directory. 
# Current directory should also contain the WAR file.
# @param war_file_name WAR file name, like 'misp2.war'
# @param package_name name of currently built package, like 'xtee-misp2-application'
##
function check_war_version {
	local war_file_name=$1
	local package_name=$2
	local command_line_input="$3"
	
	if contains_word "$command_line_input" "-y"
	then
		echo "Skipping WAR version check because of '-y' argument"
		return
	else
		echo "Performing WAR check"
	fi

	local pom_path="META-INF/maven/misp2/misp2/pom.xml"
	jar -xf ${war_file_name} $pom_path
	# find WAR POM version by taking text between first found 'version>' and '<' 
	local pom_version=$(perl -p -e "BEGIN{undef $/;} s/^.*?version[^<]*>([^<]+).*$/\1/smg" $pom_path)
	rm -rf META-INF
	# take top version entry from changelog: text between first found ' (' and ')'
	local changelog_version=$(get_last_version ../debian/changelog)
	if [ "$pom_version" != "$changelog_version" ] 
	then
		echo
		echo -n "WARNING: Latest $package_name changelog version $changelog_version "
		echo "is different to WAR POM version $pom_version "
		echo -n "Continue (y/n)? [default: y] "
		read user_continue < /dev/tty
		if [ "$user_continue" != "" ] && [ "$user_continue" != "y" ] && [ "$user_continue" != "Y" ]
		then
			echo "Exiting build process."
			exit 0
		fi
	else
		echo "WAR version and $package_name changelog versions are both $changelog_version "
	fi
}

##
# Delete package files with given prefix from current working directory.
# @param prefix package prefix, e.g. 'xtee-misp2'
##
function clean_up {
	local prefix=$1
	echo "Cleaning $prefix package files from $(pwd) directory."
	rm -f $prefix-postgresql*.* $prefix-base*.* $prefix-orbeon*.* $prefix-application*.*
	echo "Remove $prefix packages .debhelper/ directories."
	rm -rf $prefix-{base,postgresql,orbeon,application}/debian/.debhelper/
}

##
# Read from $command_line_input whether given package should be built or not.
#
# Compilation is needed if $command_line_input does not contain any parameters or
# if the package name suffix is contained in command line input.
#
# Example usage:
# compile_needed "postgresql" $command_line_input $prefix
#
# @param package_suffix package name without prefix, e.g. 'orbeon', 'application'
# @param command_line_input user input string consisting of list of package_suffices
#        the user wants to build e.g. 'orbeon base'.
#        Can be empty, in that case all packages need to be compiled.
# @param package_prefix package name without suffix, e.g. 'roksnet' or 'xtee-misp2'.
#        package_prefix and suffix are joined to package name by '-'
# @return success code (0) if compilation of given package is needed
#         and error code (1) when compilation should be skipped
##
function compile_needed {
	local package_suffix=$1
	local command_line_input=$2
	local package_prefix=$3

	# In case there are no package names in user input parameters, include all packages for compilation
	if ! has_package_names "$command_line_input" 
	then
		if [ "$package_constraints_displayed" == "" ]
		then
			package_constraints_displayed="true"
			echo "(no specific package constraints)" >> /dev/stderr
		fi
		echo -n "+ $package_prefix-$package_suffix  ">> /dev/stderr
		#echo "(building all)" >> /dev/stderr
		echo >> /dev/stderr
		return 0
	fi

	# In case of user input parameters, check if input contains package name suffix. If it does, include package.
	if echo $command_line_input | grep -q -- $package_suffix 
	then
		echo -n "+ $package_prefix-$package_suffix  " >> /dev/stderr
		#echo "(building, because '$package_suffix' was included in command line input '$command_line_input')" >> /dev/stderr
		echo >> /dev/stderr
		return 0
	else
		echo -n "- $package_prefix-$package_suffix  " >> /dev/stderr
		#echo "(excluding because '$package_suffix' was not included in command line input '$command_line_input')" >> /dev/stderr
		echo >> /dev/stderr
		return 1
	fi
}

##
# Run 'dpkg-buildpackage' without signing when
# package is not added to repo.
# @param add_to_repo true if package should be signed,
#	any other value otherwise.
##
function dpkg_build {
	local add_to_repo=$1
	local distro=$2
	# CI version update
	if [ "$CI_BUILD" ]
	then 
		changelog=$dir/changelog
		commitdate=$(git show -s --format=%ct)
		formatted_commit_date="$(date --utc --date @$commitdate +'%Y%m%d%H%M%S')"
		githash=$(git show -s --format=git%h --abbrev=7)
		version="$(dpkg-parsechangelog --show-field Version )"
		local_version="${formatted_commit_date}${githash}"
		echo "CI build - version:$local_version"
		dch --preserve --local "$local_version" "CI Build at commit: $githash"
		dch --preserve --distribution ${distro} --release ""
	fi 
	if [ "$add_to_repo" == "true" ]
	then
		dpkg-buildpackage -rfakeroot	
	else # if -nosign is defined, do not exit
		echo "Skipping signing"
		# Collect dpkg-buildpackage log info to a temporary log file
		local build_log="/tmp/dpkg-build-log"
		# Build packages without signing them
		dpkg-buildpackage -rfakeroot --no-sign | tee "$build_log"
		
		local build_dir_start=$(pwd)
		cd ..
		# Find deb package file from log

		local bin_dir=$(awk '/BinDirectory/ {gsub(/"$|^"/, "", $2); print $2;}' \
			"$repo_name/apt-ftparchive-ee-repo.conf")
		target_repo_dir="repo-unsigned"
		local target_dir="$target_repo_dir/$bin_dir/"
		mkdir -p "$target_dir"
		
		# Find a wildcard without extension corresponding to deb file in log
		local package_file=$(awk -F"'" '/dpkg-deb:/{print $4;}' "$build_log")
		local package_with_ver_arch=$(echo "$package_file"     |
			awk '{gsub(/^[.][.][/]|[.]deb$/, "", $0); print $0;}')
		local package_with_ver=$(echo "$package_with_ver_arch" |
			awk '{gsub(/_[a-z0-9]+$/, "", $0); print $0;}')
		local arch=$(echo "$package_with_ver_arch" | sed --regexp-extended  's/^.*_([a-z0-9.]+)$/\1/')
		
		# Move compiled *.deb file to 'repo-unsigned' directory
		local build_result_files_copied=$(find . -maxdepth 1 -type f -name "$package_with_ver_arch.deb")
		mv -v $build_result_files_copied "${target_dir}/${package_with_ver}_${distro}_${arch}.deb";
		
		# Remove the other build files files
		local build_result_files_deleted=$(find . -maxdepth 1 -type f \
			-name "$package_with_ver.dsc"           -o            \
			-name "$package_with_ver.tar.gz"        -o            \
			-name "$package_with_ver_arch.deb"      -o            \
			-name "$package_with_ver_arch.changes"  -o            \
			-name "$package_with_ver_arch.buildinfo" 
		)
		rm -v $build_result_files_deleted
		
		# Remove temporary log file
		rm "$build_log"
		cd "$build_dir_start"
	fi
}

##
# Get package names from command line input.
# If command line input is empty, defaults all packages.
# Otherwise, get only the packages specified with 'command_line_input' argument.
# @param command_line_input command line arguments of currently run bash script.
#	 Command line input is forwarded in an unaltered manner to 'compile_needed' function.
#	 Command line input can be empty, but can also contain package names without prefix, e.g. 'application orbeon'.
# @param prefix package name prefix, e.g 'xtee-misp2' or 'roksnet'
##
function get_packages {
	local command_line_input=$1
	local prefix=$2
	echo "Build list (+ build, - exclude):" >> /dev/stderr

	if compile_needed "postgresql" "$command_line_input" "$prefix"
	then
		echo $prefix-postgresql
	fi

	if compile_needed "base" "$command_line_input" "$prefix"
	then
		echo $prefix-base
	fi

	if compile_needed "orbeon" "$command_line_input" "$prefix"
	then
		echo $prefix-orbeon
	fi

	if compile_needed "application" "$command_line_input" "$prefix"
	then
		echo $prefix-application
	fi
}

##
# Compile packages with dpkg-buildpackage.
# If command line input is empty, compile all packages.
# Otherwise, compile only the packages specified with 'command_line_input' argument.
# @param packages whitespace separated list of compiled package names 
# @param add_to_repo if true, sign and add packages to repo; do not do that otherwise 
# @return result in compiled_packages global
##
function compile_packages {
	local packages=$1
	local add_to_repo=$2
	local distro=$3
	
	# Global variable set in this function
	compiled_packages=""

	echo "Compiling packages: $packages for distro: $distro"
	for package in $(echo $packages)
	do
		cd $package
		dpkg_build "$add_to_repo" "$distro"
		compiled_packages="${compiled_packages}'$package' "
		rm debian/$package/ -rf
		cd ..
	done
	echo "Packages compiled: $packages"
}

##
# Echo space-separated list of supported Ubuntu distribution code names to standard out.
##
function get_supported_distros {
	echo "xenial bionic"
}

##
# Adjust distro-related parameters package source to current Ubuntu distribution
# or the distribution given from command line.
# When 'adjust_to_distro' is called without arguments, it defaults to current distribution and 
# 'xtee-misp' packages.
# 
# Example usage: adjust_to_distro "xenial" "Ubuntu 16.04 Xenial Xerus" "repo" "xtee-misp2"
# @param distro_codename Ubuntu distribution codename, e.g. 'trusty' or 'xenial'.
#	 By default takes the codename of current distribution.
# @param repo_name repository directory name, e.g. 
#	 Default value is 'repo'.
# @param prefix package name prefix, by default 'xtee-misp2'
# @param packages whitespace separated package names for compiled packages 
##
function adjust_to_distro {
	# Assign input arguments
	local distro_codename=$1
	local repo_name=$2
	local prefix=$3
	local packages=$4
	local add_to_repo=$5

	# Set default values to input arguments
	if [ "$distro_codename" == "" ]
	then
		local distro_codename=$(lsb_release -cs)
	fi
	echo "adjust_to_distro: Distribution codename '$distro_codename'"

	if [ "$repo_name" == "" ]
	then
		local repo_name=repo
	fi
	echo "adjust_to_distro: Repo name '$repo_name'"

	if [ "$prefix" == "" ]
	then
		local prefix=xtee-misp2
	fi
	echo "adjust_to_distro: Prefix '$prefix'"	

	# Set distribution-specific variables
	if [ "$distro_codename" == "trusty" ]
	then
		local distro_full_name="Ubuntu 14.04 Trusty Tahr"
		local new_postgresql_version=9.3
		local new_tomcat_version=7
	elif [ "$distro_codename" == "xenial" ]
	then
		local distro_full_name="Ubuntu 16.04 Xenial Xerus"
		local new_postgresql_version=9.5
		local new_tomcat_version=7
	elif [ "$distro_codename" == "bionic" ]
	then
		local distro_full_name="Ubuntu 18.04 Bionic Beaver"
		local new_postgresql_version=10
		local new_tomcat_version=8
	else
		echo "adjust_to_distro: Distribution '$distro_codename' not implemented."
		exit 1
	fi
	echo "adjust_to_distro: Distribution full name '$distro_full_name'"

	# Make replacements

	# Replace Ubuntu distro codename (like trusty or xenial) with current Ubuntu version shortname
	perl -pi -e "s/(dists\/|Suite \"|Codename \")[a-z]+/\1$distro_codename/g" $repo_name/apt-ftparchive-ee-repo.conf
	perl -pi -e "s/(dists\/)[a-z]+/\1$distro_codename/g" $repo_name/make-ee-repo.sh

	# Replace Ubuntu full name
	perl -pi -e "s/Ubuntu [^\"]+/$distro_full_name/g" $repo_name/apt-ftparchive-ee-repo.conf

	# Make repo package directory if it doesn't already exist
	mkdir -p $repo_name/dists/$distro_codename/main/binary-amd64/

	if contains_word "$packages" "$prefix-postgresql"
	then
		echo "adjust_to_distro: PostgreSQL version $new_postgresql_version"
		# Replace postgresql version dependency
		local package_source_dir=$prefix-postgresql

		# Replace version number in text with the following format:
		# 'PostgreSQL 9.3', 'postgresql-9.3' and 'postgresql/9.3/'
		# using a single regex (exact version number may differ).
		# On perl regex substitution, instead of referring to regex match group \1, use \${1}
		# to avoid problems concatinating number to the paremter.
		perl -pi -e "s/(PostgreSQL |postgresql[\/-])[0-9\.]+/\${1}$new_postgresql_version/g" \
			$package_source_dir/debian/control \
			$package_source_dir/install-misp2-postgresql-debconf.sh \
			$package_source_dir/README

		# Make a superficial check to see if PostgreSQL version number was substituted
		if ! (grep -q "postgresql-$new_postgresql_version" $package_source_dir/debian/control && \
			grep -q "postgresql/$new_postgresql_version/" $package_source_dir/install-misp2-postgresql-debconf.sh)
		then
			echo "PostgreSQL version substitution (to $new_postgresql_version) appears to have failed."
			exit 1
		else
			echo "Successfully substituted PostgreSQL version to $new_postgresql_version."
		fi
	fi

	# Change Tomcat version

	if   contains_word "$packages" "$prefix-postgresql" \
	  || contains_word "$packages" "$prefix-base" \
	  || contains_word "$packages" "$prefix-orbeon" \
	  || contains_word "$packages" "$prefix-application" 
	then
		local package_filter_regex="$(join_regex "$packages")"
		echo "Package filter regex '$package_filter_regex'"
		local files="$(find . -type f -regex "$package_filter_regex" -exec grep -l 'tomcat[0-9]' {} + \
			| grep -v '/changelog$' \
			| grep $prefix)"

		if [ "$files" != "" ]
		then
			echo "Tomcat version substitution (to $new_tomcat_version) in $files"
			perl -pi -e "s/tomcat[0-9]/tomcat$new_tomcat_version/g" $files
		else
			echo "Tomcat replacement file list is empty."
		fi
	fi
	if contains_word "$packages" "$prefix-base"
	then
		# Adjust Tomcat server.xml according to Tomcat version
		local server_xml=$prefix-base/conf/server.xml
		if [ $new_tomcat_version -gt 7 ]
		then
			echo "Adapting to Tomcat version $new_tomcat_version."
			echo "Commenting out Jasper listener in $server_xml."
			perl -pi -e 's/.*JasperListener.*/  <!--  <Listener className="org.apache.catalina.core.JasperListener" \/>-->/g' \
				$server_xml
		else	
			echo "Tomcat $new_tomcat_version -> Keeping Jasper listener conf in $server_xml."
			perl -pi -e 's/.*JasperListener.*/  <Listener className="org.apache.catalina.core.JasperListener" \/>/g' \
				$server_xml

		fi
	fi
	if contains_word "$packages" "$prefix-application"
	then
		# Update logging conf file in WAR with the correct Tomcat version
		echo "Replacing Tomcat log dir reference in misp2.war with tomcat$new_tomcat_version."
		local war_internal_files="WEB-INF/classes/log4j2.xml"
		local war_dir="$prefix-application/war"
		# Delete possible temporary jar extraction files (exist if extraction has been forcably interrupted)
		find "$war_dir" -type f -name "jartmp*.tmp" -exec rm {} +
		local war_file="$war_dir/misp2.war"
		jar xfv "$war_file" $war_internal_files
		perl -pi -e "s/tomcat[0-9]/tomcat$new_tomcat_version/g" $war_internal_files
		jar -uvf "$war_file" $war_internal_files
		rm -r "WEB-INF"
	fi
	if contains_word "$packages" "$prefix-orbeon"
	then
		# Update logging conf file in WAR with the correct Tomcat version
		echo "Replacing Tomcat log dir reference in orbeon.war with tomcat$new_tomcat_version."
		local war_internal_files="WEB-INF/resources/config/log4j.xml"
		local war_file=$prefix-orbeon/war/orbeon.war
		jar xfv "$war_file" $war_internal_files
		perl -pi -e "s/tomcat[0-9]/tomcat$new_tomcat_version/g" $war_internal_files
		jar -uvf "$war_file" $war_internal_files
		rm -r "WEB-INF"
	fi
	return 0
}

##
# Join together white-space separated name list with regex "OR"-separator,
# add regex any-string descriptor around each name in the list.
# @param names white-space separated string
# @return 0, echo out the result 
##
function join_regex {
	local names="$1"
	
	local first="true"
	for name in $(echo $names)
	do
		if [ "$first" == "true" ]
		then
			local first="false"
		else
			echo -n "\|"	

		fi
		echo -n ".*$name.*"

	done
	echo
	return 0
}

##
# Check, if command line input has other parameters than supported distro names. 
# If it has, return 0, otherwise return 1.
# @param command_line_input command line arguments of currently executing bash script
# @return 0, if command line input has package names, 1 if not
##
function has_package_names {
	local command_line_input=$1
	# loop over command line arguments
	for arg in $(echo $command_line_input)
	do
		# If command line argument is not among supported distribution names and
		# argument does not begin with '-', it must be a package name
		if ! (get_supported_distros | grep -q -- "$arg") && ! (echo "$arg" | grep -q -- "^-")
		then
			#echo "Package name '$arg' found in '$command_line_input'."
			return 0
		fi
	done
	# No arguments that were package names were found
	#echo "No package names in '$command_line_input'."
	return 1
}

##
# Get newline-separated list of distribution codenames to which packages are built for.
# Distribution codenames are read from command line input. Command line input just has to contain
# distro codename, the argument order does not matter.
# 
# Example usage: $(get_distros "application trusty")
# @param command_line_input command line arguments of currently executing bash script
#	 in an unaltered form. Current method parses out supported distribution codenames and echoes
#	 them separated by newline.
#	 Parameter can be empty, in this case '
#	  trusty
#	  xenial
#	 ' is echoed out.
##
function get_distros {
	local command_line_input=$1

	local found_distros="false"
	for distro in $(get_supported_distros)
	do
		if echo $command_line_input | grep -q -- "$distro" 
		then
			echo "$distro"
			local found_distros="true"
		fi
	done

	# Default, when no parameters are given, return all supported distributions
	if [ "$found_distros" == "false" ]
	then
		get_supported_distros
	fi
	return 0
}

##
# Display build summary
# 
# Example usage: display_build_summary "xtee-misp2-postgresql xtee-misp2-application" "repo"
# @param distro_codename codename for Ubuntu distribution
# @param compiled_packages space-separated list of compiled package names
# @param repo_name repository directory name
##
function display_build_summary {
	local distro_codename=$1
	local compiled_packages=$2
	local repo_name=$3
	local add_to_repo=$4
	
	echo -n "Distro '$distro_codename': "

	# Count spaces in $compiled_packages: that corresponds to number of packages compiled
	local count_packages_built=$(echo "$compiled_packages" | grep -o " " | wc -l)
	# Show suitable information message depending on the number of compiled packages
	if [ $count_packages_built == "0" ]
	then
		echo "regenerated $repo_name. Did not build packages."
	elif [ $count_packages_built == "1" ]
	then
		echo -n "built package ${compiled_packages}"
		if [ "$add_to_repo" == "true" ]
		then
			echo -n " and added it to $repo_name"
		fi
		echo "."
	else
		echo -n "built packages ${compiled_packages}"
		if [ "$add_to_repo" == "true" ]
		then
			echo -n " and added them to $repo_name"
		fi
		echo "."
	fi

}

