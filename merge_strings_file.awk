#
# This script reads through 2 strings files used for localization
#

#
# Set the Field seperator
#
BEGIN {
	FS=" = ";
}

#
# Empty the comment at the start of a new comment
#
/^\/\*/ {
	com = "";
}

#
# Read full comment
#
/^\/\*/,/\*\/$/ {
	com = com ? com"\n"$0 : $0;
	next;
}

#
# Read original key value pairs
#
NR == FNR && /^"/ {
	a[$1] = $2;
	v[$1] = com"\n"$1" = "$2"\n";

	com = "";

	next;
}

#
# Read the keys from the second file
#
/^"/ {
	$2 = a[$1] ? a[$1] : $2;

	print com;
	print $1" = "$2"\n";

	com = "";
	v[$1] = "";
}

#
# Find all pairs that haven't been printed and add them at the end
#
END{
	first  = "true";

	for (i in v) {

		if (i != "" && v[i] != "") {
			if (first) {
				print "/* OLD VALUES */\n";
				first = "";
			}
	
			print v[i];
		}
	}
}