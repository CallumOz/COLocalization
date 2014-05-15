#!/bin/sh
#
# This Script exports the strings from the storyboard and
# merges them with the strings files it finds in the lproj
# folders
#
# Make sure all existing strings files are in UTF-8 format
# or they will be erased
# This can be verified with : file $filePath
# or looking at the encoding in Xcode
#

folder="."
baseStringsPath="Localizable.strings"
localeDirExt="lproj"
stringsExt=".strings"
newStringsExt=".strings.new"
oldStringsExt=".strings.old"
storyboardExt=".storyboard"

stringsFile=$(basename "$baseStringsPath")
newBaseStringsPath=$(echo "$baseStringsPath" | sed "s/$stringsExt/$newStringsExt/")

function usage()
{
	echo "Extract Strings from Objective-C source files, XIBs and Storyboards."
    echo ""
    echo "USAGE $0"
    echo "\t-h --help"
    echo "\t-f --folder <folder>: Folder to search through"
    echo "\t-o --objective-c: Search through Objective-C source files"
    echo "\t-s --storyboard: Search through Storyboard files"
    echo "\t-x --xib: Search through XIB files"
    echo "\t-a --all: Search through all files"
    echo ""
}

# Takes just 1 Arg, the value to check
function check_value()
{
	if [ "$1" == "" ]; then
		echo "ERROR: Missing value"
		usage
		exit
	fi
}

# Takes 2 Args, the 2 files t
function update_strings_file()
{
	oldLocaleStringsPath=$(echo "$1" | sed "s/$stringsExt/$oldStringsExt/")
	cp "$1" "$oldLocaleStringsPath"

	# Merge baseStringsPath to localeStringsPath
	awk -f "merge_strings_file.awk" "$oldLocaleStringsPath" "$2" > "$1"

	rm "$oldLocaleStringsPath"
}

while [ "$1" != "" ]; do
    param="$1"
    value="$2"
    case "$param" in
        -h | --help)
            usage
            exit
            ;;
        -f | --folder)
			check_value "$value"
            folder="$value"
            shift
            ;;
        *)
            echo "ERROR: unknown parameter \"$param\""
            usage
            exit 1
            ;;
    esac
    shift
done

# Search for all Objective-C source files in $folder
find "$folder" -type f -name '*.m' -print0 | xargs -0 genstrings

# Continue only if genstrings succeeded
if [ $? -eq 0 ]; then
    mv "$baseStringsPath" "$newBaseStringsPath"

    iconv -f UTF-16 -t UTF-8 "$newBaseStringsPath" > "$baseStringsPath"
    rm "$newBaseStringsPath"

    # Get all locale strings folder
    find $folder -type d -name "*$localeDirExt" -print0 | while IFS= read -r -d $'\0' localeStringsDir;
    do
		localeStringsPath="$localeStringsDir/$stringsFile"

        # Just copy base strings file on first time
		if [ ! -e "$localeStringsPath" ]; then
            cp "$baseStringsPath" "$localeStringsPath"
		else
			# Look for the encoding of the strings file found
		    file -b --mime "$localeStringsPath" | grep utf-8 > /dev/null

	  		if [ $? -eq 0 ]; then
	  			update_strings_file "$localeStringsPath" "$baseStringsPath"
		    else
				echo "${localeStringsPath} isn't in UTF-8 Format"
	 	 	fi
		fi
    done
fi

# Delete the file generated by genstrings
rm $baseStringsPath

# Extract strings from storyboards

# Find storyboard file full path inside project folder
find $folder -type f -iname "*$storyboardExt" -print0 | while IFS= read -r -d $'\0' storyboardPath;
do
    # Get Base strings file full path
    baseStringsPath=$(echo "$storyboardPath" | sed "s/$storyboardExt/$stringsExt/")

    # Create base strings file if it doesn't exist
    if ! [ -f "$baseStringsPath" ]; then
      touch -r "$storyboardPath" "$baseStringsPath"
      # Make base strings file older than the storyboard file
      touch -A -01 "$baseStringsPath"
    fi
    
    # Create strings file only when storyboard file newer
    if find "$storyboardPath" -prune -newer "$baseStringsPath" -print | grep -q .; then
        # Get storyboard file name and folder 
        storyboardFile=$(basename "$storyboardPath")
        storyboardDir=$(dirname "$storyboardPath")

        # Get New Base strings file full path and strings file name
        newBaseStringsPath=$(echo "$storyboardPath" | sed "s/$storyboardExt/$newStringsExt/")
        stringsFile=$(basename "$baseStringsPath")
        ibtool --export-strings-file "$newBaseStringsPath" "$storyboardPath"
        
        # ibtool sometimes fails for unknown reasons with "Interface Builder could not open 
        # the document XXX because it does not exist."
        # (maybe because Xcode is writing to the file at the same time?)
        # In that case, abort the script.
        if [[ $? -ne 0 ]] ; then
            echo "Exiting due to ibtool error. Please run `killall -9 ibtoold` and try again."
            exit 1
        fi
        
        # Only run iconv if $newBaseStringsPath exists to avoid overwriting existing
        if [ -f "$newBaseStringsPath" ]; then
        	iconv -f UTF-16 -t UTF-8 "$newBaseStringsPath" > "$baseStringsPath"
        	rm "$newBaseStringsPath"
        fi

        # Get all locale strings folder
		find $folder -type d -name "*$localeDirExt" -print0 | while IFS= read -r -d $'\0' localeStringsDir;
		do
            # Skip Base strings folder
            if [ "$localeStringsDir" != "$storyboardDir" ]; then
                localeStringsPath="$localeStringsDir/$stringsFile"

                # Just copy base strings file on first time
                if [ ! -e "$localeStringsPath" ]; then
                    cp "$baseStringsPath" "$localeStringsPath"
                else
                    # Look for the encoding of the strings file found
				    file -b --mime "$localeStringsPath" | grep utf-8 > /dev/null

			  		if [ $? -eq 0 ]; then
			  			update_strings_file "$localeStringsPath" "$baseStringsPath"
				    else
						echo "${localeStringsPath} isn't in UTF-8 Format"
			 	 	fi
                fi
            fi
        done
    else
        echo "$storyboardPath file not modified."
    fi
done