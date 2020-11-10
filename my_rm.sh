#!/bin/sh
# by vegetablebird last modified 2020.08.21
# USAGE: (1) ln -s $PWD/my_rm.sh ~/.local/bin/rm
#	 (2) export PATH=~/.local/bin:$PATH
#	 (3) which rm

#FEATURE: Try to create a new trash directory for each rm command
#         but not guaranteed if two rm commands is committed at a same time
#FEATURE: If two files(directores) are removed with same name by a single rm command,
#         they will be put into different trash directories
#FEATURE: There is a log_file in the corresponding trash directory,
#         unless removing a file with the same name as log_file (without warning message throwing)

#Bug1: not support space. e.g.: rm -rf arch\ final\ project/
#Bug2: mv: cannot move ‘../results/My-mix33/m5out/’ to ‘/home/vegetablebird/.trash/2017-08-06/21:03:15.99453/m5out’: Directory not empty // IGNORE??

#TODO: /home/vegetablebird/.local/bin/rm: unimplemented arg: -fr, use /bin/rm
#TODO: log_file=original_command -> log_file=rm_cmd (cmd, remove_command)
#TODO: add undo command (restore removed data)

ori_rm=/bin/rm
trash_dir=/home/vegetablebird/.trash
preserve_days=90
log_file=original_command

function actually_rm
{
	if [ "`ps -A | grep rm  | wc -l`" -gt "2" ] || [ -f $trash_dir/rming ]
	then
#		echo $0: rm is running, skipping actually_rm
#		ps -A | grep rm
		exit
	fi

	touch $trash_dir/rming

	cur_year=`date +%Y`
	cur_month=`date +%m`
	cur_day=`date +%d`

	cd $trash_dir
	for f in `ls -d * | grep '[0-9]\+-[0-9]\+-[0-9]\+'`
	do
		file_year=`echo $f | sed 's/\([0-9]\+\)-[0-9]\+-[0-9]\+/\1/g'`
		file_month=`echo $f | sed 's/[0-9]\+-\([0-9]\+\)-[0-9]\+/\1/g'`
		file_day=`echo $f | sed 's/[0-9]\+-[0-9]\+-\([0-9]\+\)/\1/g'`

		diff_year=$(( 10#$cur_year - 10#$file_year ))
		diff_month=$(( 12*$diff_year + 10#$cur_month - 10#$file_month ))
		diff_day=$(( 30*$diff_month + 10#$cur_day - 10#$file_day ))

		if [ "$diff_day" -gt "$preserve_days" ]
		then
			$ori_rm -rf $f
		fi
	done

	$ori_rm $trash_dir/rming
}

force=false
recursive=false
files=""
directories=""
not_exists=""
for arg in $@
do
	if [[ $arg == -* ]]
	then
		if [ "$arg" == "-h" ] || [ "$arg" == "-help" ] || [ "$arg" == "--help" ]
		then
			echo -e "Usage: $0 [OPTION]... FILE..."
			echo -e "Move the FILE(s) to trash_dir($trash_dir)."
			echo -e "Check and Delete the files in trash_dir longer than $preserve_days days."
			echo
			echo -e "  -f, --force\t\tignore nonexistent files and arguments"
			echo -e "  -r, -R, --recursive\tremove directories and their contents recursively"
			echo -e "  -h, -help, --help\tdisplay this help and exit"
			echo -e "\t\t\tuse '$ori_rm --help' for the conventional rm help"
			echo
			echo -e "Created by vegetablebird"
			exit 0
		elif [ "$arg" == "-f" ] || [ "$arg" == "--force" ]
		then
			force=true
		elif [ "$arg" == "-r" ] || [ "$arg" == "-R" ] || [ "$arg" == "--recursive" ]
		then
			recursive=true
		elif [ "$arg" == "-rf" ]
		then
			force=true
			recursive=true
		else
			echo "$0: unimplemented arg: $arg, use $ori_rm"
			$ori_rm $@
			exit $?
		fi
	elif [ -f "$arg" ] || [ -L "$arg" ]
	then
		files="$files $arg"
	elif [ -d "$arg" ]
	then
		directories="$directories $arg"
	else
		not_exists="$not_exists $arg"
	fi
done

# Check the operands
if [ "$files" == "" ] && [ "$directories" == "" ] && [ "$not_exists" == "" ]
then
	echo "$0: missing operand"
	exit 1
fi
if [ "$force" = false ] && [ "$not_exists" != "" ]
then
	for f in $not_exists
	do
		echo "$0: cannot remove '$f': No such file or directory"
	done
	exit 1
fi
if [ "$recursive" = false ] && [ "$directories" != "" ]
then
	for f in $directories
	do
		echo "$0: cannot remove '$f': Is a directory"
	done
	exit 1
fi

# Move files to a directory in .trash
rm_dir=""
for f in $files $directories
do
	filename=`echo $f | sed -e 's/^.*\/\([^\/]\+\)\/\?$/\1/g'`
	if [ "$rm_dir" == "" ] || [ -f $rm_dir/$filename ] || [ -d $rm_dir/$filename ]
	then
		rm_dir=$trash_dir/`date +%F/%T.%5N`
		if [ -f $rm_dir/$f ] || [ -d $rm_dir/$f ]
		then
			echo "$0: cannot find a valid trash directory"
			exit 1
		fi
		mkdir -p $rm_dir
		echo "$LOGNAME@$HOSTNAME:`pwd`$ $0 $@" >> $rm_dir/$log_file
	fi
	mv $f $rm_dir
	if [ "$?" == "1" ]
	then
		echo "GET Bug2: mv: cannot move ‘...’ to ‘...’: Directory not empty"
	fi
done

# Actually rm the old files
actually_rm &

exit 0
