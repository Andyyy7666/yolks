#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Auto update server from git.
if [ "${GIT_ENABLED}" == "true" ] || [ "${GIT_ENABLED}" == "1" ]; then

	# Pre git stuff
	echo "Wait, preparing to pull or clone from git."

	mkdir -p /home/container
	cd /home/container

	# Git stuff
	if [[ ${GIT_REPOURL} != *.git ]]; then # Add .git at end of URL
		GIT_REPOURL=${GIT_REPOURL}.git
	fi

	if [ -z "${GIT_USERNAME}" ] && [ -z "${GIT_TOKEN}" ]; then # Check for git username & token
		echo -e "git Username or git Token was not specified."
	else
		GIT_REPOURL="https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e ${GIT_REPOURL} | cut -d/ -f3-)"
	fi

	if [ "$(ls -A /home/container)" ]; then # Files exist in server folder, pull
		echo -e "Files exist in /home/container/. Attempting to pull from git repository."

		# Get git origin from /home/container/.git/config
		if [ -d .git ]; then
			if [ -f .git/config ]; then
				GIT_ORIGIN=$(git config --get remote.origin.url)
			fi
		fi

		# Check if we have a shallow clone and need to maintain it
		is_shallow=$(git rev-parse --is-shallow-repository 2>/dev/null || echo "false")

		# If git origin matches the repo specified by user then pull
		if [ "${GIT_ORIGIN}" == "${GIT_REPOURL}" ]; then
			# Override local changes
			# echo "Overriding local changes..."
			# git clean -fd

			# Fetch latest changes (shallow if original clone was shallow)
			echo "Fetching latest changes..."
			if [ "$is_shallow" = "true" ]; then
				git fetch --depth 1 origin "${GIT_BRANCH}" && echo "Finished fetching /home/container/ from git." || echo "Failed fetching /home/container/ from git."
			else
				git fetch origin "${GIT_BRANCH}"
			fi

			# Force reset to match remote branch (this will override any local edits)
			echo "Updating to match remote branch..."
			git reset --hard "origin/${GIT_BRANCH}" && echo "Finished updating /home/container/ from git." || echo "Failed updating /home/container/ from git."
		else
			echo -e "git repository in /home/container/ does not match user provided configuration. Failed pulling /home/container/ from git."
		fi
	else # No files exist in server folder, clone
		echo -e "Server directory is empty. Attempting to clone git repository."

		if [ -z ${GIT_BRANCH} ]; then
			echo -e "Cloning default branch into /home/container/."
			git clone --single-branch --depth 1 ${GIT_REPOURL} . && echo "Finished cloning into /home/container/ from git." || echo "Failed cloning into /home/container/ from git."
		else
			echo -e "Cloning ${GIT_BRANCH} branch into /home/container/."
			git clone --single-branch --branch ${GIT_BRANCH} --depth 1 ${GIT_REPOURL} . && echo "Finished cloning into /home/container/ from git." || echo "Failed cloning into /home/container/ from git."
		fi
	fi

	# Post git stuff
	cd /home/container
fi

# Print Java version
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"
java -version

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
eval ${PARSED}
