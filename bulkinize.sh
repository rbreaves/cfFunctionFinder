

OIFS=$IFS;
IFS="|";
exceptions="raygun"
CFCs=$(find "$1" -name '*.cfc' | xargs -0 | grep -Ev "$exceptions" | awk '{print $0"|"}')
arrCFCs=($CFCs)
IFS=$OIFS;

totalCFCs=$(echo "${#arrCFCs[@]}")

num=0
unset arrCFCs[${#arrCFCs[@]}-1]
for i in "${arrCFCs[@]}"
do
	echo "$num $i"
	num=$((num+1))
done
num=0
for i in "${arrCFCs[@]}"
do
	#if [[ "$num" -gt "4" ]]; then
		fullFilename=$(echo "$i" | tr -d '\n')
		folderPath="$2"
		sh ./findFunctions.sh "$fullFilename" "$folderPath"
		numNext=$((num+1))
	#	read -p "Press [Enter] key to continue to next function $numNext..."
	#fi
	num=$((num+1))
done

