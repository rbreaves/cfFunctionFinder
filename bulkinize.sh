

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
	fullFilename=$(echo "$i" | tr -d '\n')
	folderPath="$2"
	sh ./findFunctions.sh "$fullFilename" "$folderPath"
	num=$((num+1))
done

