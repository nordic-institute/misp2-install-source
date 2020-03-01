#!/bin/bash

function git_clone {
	local repo_url="$1"
	local repo_path="$2"
	local repo_branch="$3"
	if [ ! -d "$repo_path" ]
	then
		echo "Cloning '$repo_url' to '$repo_path'."
		git clone "$repo_url" "$repo_path"
	fi
	
	echo "Checking out '$repo_branch' of '$repo_path'."
	cd "$repo_path"
	git checkout "$repo_branch" 
	cd ..
}

function expand_path {
	local path="$1"
	eval echo "$path"
}

# Fail on error
set -e

# Do not allow to run as root
if [ "$EUID" == "0" ]
then
	echo "This script should not be initially run as root,"
	echo "otherwise created files would have root as owner."
	echo "When executed, the script will ask for root only where needed."
	exit 1
fi

if [ "$1" == "" ]
then
	echo "This scripts sets up MISP2 build environment."
	echo
fi

git_dir_path="~/git"
git_dir=$(expand_path "$git_dir_path")

script_path="$(realpath "$0")"

# If one of the command line arguments is gnupg, check GnuPG conf 
gnupg_dir_path="~/.gnupg"
gnupg_dir=$(expand_path "$gnupg_dir_path")


if [ ! -d "$gnupg_dir" ] || [ -z "$(find "$gnupg_dir" -type f)" ]
then
	echo "WARNING: GnuPG directory '$gnupg_dir_path/' is missing or empty, will not be able to sign Debian packages."
fi

# Make Git directory if missing
if [ ! -d "$git_dir/" ]
then
	echo "Creating directory '$git_dir_path/'."
	mkdir "$git_dir/"
fi

# Clone MISP2 repos if missing
cd "$git_dir/"

# Avoid repeatedly asking for Git credentials (cache for 5 min)
git config --global credential.helper 'cache --timeout=300'

repo_url_prefix=https://github.com/ria-ee

install_source_url=$repo_url_prefix/MISP2-install-source.git
install_source_dir=MISP2-install-source
install_source_branch=master
git_clone "$install_source_url" "$install_source_dir" "$install_source_branch"

misp2_webapp_url=$repo_url_prefix/MISP2-web-app.git
misp2_webapp_dir=MISP2-web-app
misp2_webapp_branch=master
git_clone "$misp2_webapp_url" "$misp2_webapp_dir" "$misp2_webapp_branch"

orbeon_war_url=$repo_url_prefix/MISP2-orbeon-war.git
orbeon_war_dir=MISP2-orbeon-war
orbeon_war_branch=master
git_clone "$orbeon_war_url" "$orbeon_war_dir" "$orbeon_war_branch"

# On login, go straight to MISP2-install-source directory
startup_conf_path="~/.bashrc"
startup_conf=$(expand_path "$startup_conf_path")
install_source_dir_full="$git_dir_path/$install_source_dir"
startup_comment="## Added by setup script"
if ! grep -q "$startup_comment" "$startup_conf"
then
	echo                                                            >> "$startup_conf"
	echo "$startup_comment"                                         >> "$startup_conf"
	
	echo "Setting '$install_source_dir' as initial directory in '$startup_conf_path'."
	echo "# Change directory to $install_source_dir"                >> "$startup_conf"
	echo "cd $install_source_dir_full"                              >> "$startup_conf"
	echo                                                            >> "$startup_conf"

	echo "Adding '$install_source_dir' to PATH in '$startup_conf_path'."
	echo "# Add '$install_source_dir' to PATH."                     >> "$startup_conf"
	echo "export PATH=\"$install_source_dir_full:\$PATH\""          >> "$startup_conf"
	echo                                                            >> "$startup_conf"

	tab_complete_script="resources/tab-complete-build.sh"
	echo "Setting up tab-complete script"\
         "'$install_source_dir/$tab_complete_script' in '$startup_conf_path'"
	echo "# Set up bash tab-complete for the build script."         >> "$startup_conf"
	echo "source $install_source_dir_full/$tab_complete_script"     >> "$startup_conf"

	echo "$startup_comment - ends"                                  >> "$startup_conf"
	echo                                                            >> "$startup_conf"

	echo "In order to apply $startup_conf_path configuration, try logging out and in again."
fi


set +e; # Do not fail, if some dependencies were uninstalled or not removed
# Install debian package build dependencies
echo "Installing build dependencies (sudo needed)..."
sudo apt -y install build-essential fakeroot dpkg-dev debhelper gawk
sudo apt -y remove openjdk-11-jre-headless 
#  (maven for building MISP2 webapp, ant for building Orbeon war)
sudo apt -y install openjdk-8-jdk maven ant

