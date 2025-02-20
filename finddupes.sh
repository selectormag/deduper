#!/bin/ash

#Find duplicates
UPDATED="2018-01-12"
# I skipped a lot of best practices in here in order to get it working for my purposes more quickly. I may never get back to fix this for public consumption, though I'd like to. We shall see.

echo "Duplicate Finder, last updated ${UPDATED}"

### What kind of duplicate finding do we want to do?

function selection {
	read -p "What kind of duplicate finding would you like to execute? (S)ubdirectories, (D)irectory, (I)ndices, (U)sage: " TYPE

	shopt -s nocasematch
	case ${TYPE} in 
		s|subdirectories)
			subdirectories
		;;
		d|directory)
			directory
		;;
		u|usage)
			usage
		;;
		i|indices)
			indices
		;;
		*)
			echo "Sorry, I don't recognize your selection. Try again."
			selection
		;;
	esac
}

function subdirectories {
	echo
	echo "This will recursively check for any and all duplicates using the specified index or indices. This could take quite some time depending on how many entries are in your selected index."
	read -p "Please enter the name of the index you would like to use: " SUBINDEX
	while read -r MD5LINE; do
		#MD5HASH=$(echo ${MD5HASH} | awk '{print $1}')
		MD5HASH=$(echo "${MD5LINE}" | cut -d ' ' -f 1)
		MD5LIST=$(grep ${MD5HASH} ./${SUBINDEX}-md5index.db)
		DUPENUM=$(echo "${MD5LIST}" | wc -l)
		echo "Iteration for ${MD5HASH} complete."
		if [[ ${DUPENUM} -gt 1 ]]; then
			EXISTS=$(grep ${MD5HASH} ./${SUBINDEX}-duplicates.results)
			if [[ -n "${EXISTS}" ]]; then
				echo "Duplicate found for ${MD5HASH}, but this one has already been added to the duplicates results file. Skipping..."
				continue
			fi
			echo "Hash ${MD5HASH} has duplicates. Adding its group to the list..."
			echo "############ Duplicate report for hash ${MD5HASH} ############" | tee -a ./${SUBINDEX}-duplicates.results
			echo "${MD5LIST}" | tee -a ./${SUBINDEX}-duplicates.results
			echo "##############################################################" | tee -a ./${SUBINDEX}-duplicates.results
			echo "" | tee -a ./${SUBINDEX}-duplicates.results
		fi
	done < ./${SUBINDEX}-md5index.db

	echo
	echo "Duplicate searching complete! Duplicate groups can be found in the file ${SUBINDEX}-duplicates.results."
}

function directory {
	## FIND DUPLICATES FROM SPECIFIC DIRECTORY ONLY
	
	read -p "Please enter the path to the directory you wish to check: " SRCPATH
	read -p "Please enter the name of the index you wish to use to compare against: " INDEX
	#echo "Creating database of md5 hashes for all files under ${FINDPATH}..."
	#find ${FINDPATH} -type f -exec /bin/md5sum '{}' \; | tee ./md5list.db
	
	echo "Removing source directory from hash database: ${SRCPATH}..."
	cp -f ${INDEX}-md5index.db ${INDEX}-md5index.db.tmp
	sed -i ':$SRCPATH:d' ${INDEX}-md5index.db.tmp
	
	echo "Beginning hash comparison of all files under ${SRCPATH}..."
	mkdir -vp "${SRCPATH}/dupes"
	for i in "${SRCPATH}"/*; do
		echo "Verifying current item $i is NOT a directory..."
		if [[ -d $i ]]; then
			echo "$i is a directory! Skipping and moving on to next item..."
			continue
		fi
		echo "Calculating hash for ${i}..."
		HASH=$(/bin/md5sum "${i}" | awk '{print $1}')
		echo "Hash calculated for ${i}, and it is ${HASH}."
		echo "Searching for duplicates for ${HASH}..."
		CHECK=$(grep ${HASH} ./${INDEX}-md5index.db.tmp)
		if [[ -n "$CHECK" ]]; then
			echo "${i} has a duplicate at ${CHECK}. Moving to ${SRCPATH}/dupes/ so you can choose to easily delete or keep this set..." | tee -a ./finddupes.log
			mv -v "${i}" "${SRCPATH}/dupes/"
		else
			echo "!!!!!!!!!!!!! ${i} does NOT have a duplicate." | tee -a ./nodupes.log
		fi
		echo "Search for duplicates for ${HASH} complete. Moving on..."
	done
	
	#declare -a FILEARRAY=$(cat duplicate_file.csv | grep -a 'C.u.r.a.t.e.d. .J.u.l.i.e' | awk -F $'\t' '{print $3}')
	
	#echo "Parsing Curated Julie dupe paths from duplicate_file.csv..."
	#rm -vf tmp.db tmp2.db
	#cat ./duplicate_file.csv | grep -a 'C.u.r.a.t.e.d. .J.u.l.i.e' | awk -F $'\t' '{print $3}' >> tmp.db
	
	#while read RAWPATH; do 
	#	echo "Removing quotes from path parsed from duplicate_file.csv: ${RAWPATH}"
	#	RAWPATH="${RAWPATH%\"}"
	#	NEWPATH="${RAWPATH#\"}"
	#	echo ${NEWPATH} >> tmp2.db
	#done < tmp.db
	
	#while read DELPATH; do
	#	echo "Removing duplicate file: ${DELPATH}..."
		# rm -vf ${DELPATH}
		#done < tmp2.db
}

function indices {
	read -p "What would you like to do? (L)ist indices, (C)reate index, (A)ppend to existing index: " INDTYPE
	shopt -s nocasematch
	case ${INDTYPE} in
		l|list|"list indices")
			ls -l ./*md5index.db
		;;
		c|create|"create index")
			read -p "What is the path for the index you'd like to create? " INDPATH
			read -p "What would you like to name this index? " INDNAME
			echo "Creating database of md5 hashes for all files under ${INDPATH}. Please wait; this could take quite some time..."
			find ${INDPATH} -type f -exec /bin/md5sum '{}' \; | tee ./${INDNAME}-md5index.db
			echo "Index creation is complete. The index is ${INDNAME}-md5index.db."
		;;
		a|append|"append to existing"|"append to existing index")
			read -p "What is the path for the index you'd like to add? " INDPATH
			read -p "What existing index would you like to append to? " INDNAME
			echo "Making a backup of existing index, just in case..."
			cp -v ./${INDNAME}-md5index.db ./${INDNAME}-md5index.bak
			echo "Creating database of md5 hashes for all files under ${INDPATH}. Please wait; this could take quite some time..."
			find ${INDPATH} -type f -exec /bin/md5sum '{}' \; | tee -a ./${INDNAME}-md5index.db
			echo "Index creation is complete. The index is ${INDNAME}-md5index.db."
		;;
	esac
}

function usage {
	echo "Subdirectories (or type 's') --  this will check the database for duplicates of any and all files under a giv en directory recursively."
	echo "Directory (or type 'd') -- this will compare only files within a certain directory, skipping subdirectories, and check for duplicates in the index."
	echo "Indices (or type 'i') -- this will give you the option to print out existing indices for given paths or create a new index. It's recommended to just create an index of your entire directory tree to ensure all possible duplicates can be found, but indices for specific directories can be made if desired."
	echo "Usage (or type 'u') -- prints this usage message."
}

selection
