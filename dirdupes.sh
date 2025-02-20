#!/bin/bash

## Directory dupes
## Using finddupes.sh, create an index
## Create a file containing paths to all directories you'd like to check for duplicates (this will skip subdirectories because I'm lazy)
## Execute dirdupes.sh pointing at the file references on the previous line
## Dirdupes will move all duplicate files into "dupes" directories within their respective directories so you can choose whether to still keep those files or delete them yourself

echo "This will check for duplicates AND move any duplicates found into a "dupes" folder WITHIN THE DIRECTORY THE DUPLICATE WAS FOUND IN. Please note that if a file has a duplicate somewhere under the path you specify, that will be ignored, meaning duplicates without a match OUTSIDE of this specified path and its subdirectories WILL NOT be moved to a dupes folder."
echo
read -p "Please enter the path you'd like to check for duplicates: " PPATH
if [[ ! -d "$PPATH" ]]; then
	echo "The path you entered does not exist or is not a directory. Try, try again."
	exit 1
fi
read -p "Please enter the index against which you'd like to check: " INDEX
read -p "Please supply comma-delimited list of keywords to use to ignore specific directories: " IGNORELIST

echo "Turning off history expansion..."
set +H

if [[ -z ${IGNORELIST} ]]; then
	echo "Ignore list is empty."
	IGNORELIST="xxxThisShouldntMatchAnythingWhatsoeverxxx802903e023480jdh023j0djfh2498hd0q98jdsousehf89400"
else
	IGNORELIST=$(echo ${IGNORELIST} | tr , "|")
fi

echo "Creating list of subpaths to search..."
find "${PPATH}" -type d | egrep -v "#recycle|eaDir|dupes|SynoResource|SynoEAStream" > ./dupepaths.list.tmp
echo "DONE"

echo "Removing source directory from hash database: ${PPATH}..."
egrep -v "${PPATH}|eaDir|dupes|SynoResource|SynoEAStream" ${INDEX}-md5index.db > ${INDEX}-md5index.db.tmp
#cp -f ${INDEX}-md5index.db ${INDEX}-md5index.db.tmp
#sed -i ":${PPATH}:d" ${INDEX}-md5index.db.tmp

echo "DONE"

STAMP=$(date +%Y-%m-%d)

echo "Creating a new removal script at ${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh..."
SCRIPTCHECK=$(ls "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh" 2>/dev/null)
if [[ -z "${SCRIPTCHECK}" ]]; then
	echo "#!/bin/bash" > "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh"
	echo "### Run this script to move the duplicate files found back to their original locations ###" >> "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh"
	echo "### THIS SCRIPT WAS AUTOMATICALLY GENERATED ###" >> "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh"
	chmod +x "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh"
else
	echo "Removal script already exists. We will just append instead."
fi
mkdir -vp "${PPATH}/dupes_${INDEX}_${STAMP}"

while read SRCPATH; do
	echo "Verifying whether directory ${SRCPATH} is on the ignore list..."
	IGNORE=$(echo "${SRCPATH}" | egrep "${IGNORELIST}")
	if [[ ! -z ${IGNORE} ]]; then
		echo "This directory ${SRCPATH} is on the ignore list. Ignoring its contents and moving on..."
		continue
	fi
	echo "Verifying whether directory ${SRCPATH} is empty..."
	EMPTCHECK=$(ls "${SRCPATH}")
	if [[ -z "${EMPTCHECK}" ]]; then
		echo "Directory is empty. Skipping to next record..."
		continue 2
	fi
	echo "Beginning hash comparison of all files under ${SRCPATH}..."
	for i in "${SRCPATH}"/*; do
		echo "Verifying current item $i is NOT a directory..."
		if [[ -d "$i" ]]; then
			echo "$i is a directory! Skipping and moving on to next item..."
			continue
		fi
		echo "Getting just the filename for ${i} for later..."
		FILENAME=$(echo "${i}" | sed '/\n/!G;s/\(.\)\(.*\n\)/&\2\1/;//D;s/.//'| cut -d'/' -f 1 | sed '/\n/!G;s/\(.\)\(.*\n\)/&\2\1/;//D;s/.//')
		echo "Filename is ${FILENAME}."
		echo "Calculating hash for ${i}..."
		HASH=$(/bin/md5sum "${i}" | awk '{print $1}')
		echo "Hash calculated for ${i}, and it is ${HASH}."
		echo "Searching for duplicates for ${HASH}..."
		CHECK=$(grep "${HASH}" "./${INDEX}-md5index.db.tmp")
		if [[ -n "$CHECK" ]]; then
			echo "${i} has a duplicate at ${CHECK}. Moving to ${PPATH}/dupes_${INDEX}_${STAMP}/ so you can choose to easily delete or keep this set..."
			mv -v "${i}" "${PPATH}/dupes_${INDEX}_${STAMP}/"
			echo -e "$(date +%Y-%m-%d\ %H:%M:%S) Original: ${i}\tDupe: ${CHECK}\t Moved to: ${PPATH}/dupes_${INDEX}_${STAMP}/" >> "${PPATH}/dupes.log"
			echo "Adding moved file to undo script, just in case..."
			echo "mv -v \"${PPATH}/dupes_${INDEX}_${STAMP}/${FILENAME}\" \"${i}\"" >> "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh"
			echo "Removing file reference from index and adding to undo script, just in case..."
			INDUNDO=$(grep "${i}" "${INDEX}-md5index.db")
			### I need to replace ${INDEX}-md5index.db references with a variable with the full path to the index
			echo "echo \"${INDUNDO}\" >> \"${INDEX}-md5index.db\"" >> "${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh"
			grep -v "${INDUNDO}" "${INDEX}-md5index.db" > "${INDEX}.tmp"
		else
			echo "${i} does NOT have a duplicate."
		fi

		echo "Search for duplicates for ${HASH} complete. Moving on..."
	 done
	 echo "Done parsing through ${SRCPATH}. Good job, huh?"
done < dupepaths.list.tmp

echo "Cleaning up..."
rm -rvf "${INDEX}-md5index.db.tmp" dupepaths.list.tmp
mv -fv "${INDEX}.tmp" "${INDEX}-md5index.db"

SSPACE=$(du -xh --max-depth=1 "${PPATH}/dupes_${INDEX}_${STAMP}" | awk '{print $1}')
NUMITEMS=$(ls "${PPATH}/dupes_${INDEX}_${STAMP}" | wc -l)

echo "Duplicate finding complete."
echo "${NUMITEMS} duplicates were found, saving you ${SSPACE} disk space. NOTE: You must manually delete ${PPATH}/dupes_${INDEX}_${STAMP} in order to actually reclaim this space. Also, if you find you actually need these duplicates, you can put them all back in place by executing ${PPATH}/undo-dupes_${INDEX}_${STAMP}.sh."
echo
echo "DONE"
