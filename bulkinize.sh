

OIFS=$IFS;
IFS="|";
CFCs=$(find "$1" -name '*.cfc' | xargs -0 | grep -v "raygun" | awk '{print $0"|"}')
arrCFCs=($CFCs)
IFS=$OIFS;

totalCFCs=$(echo "${#arrCFCs[@]}")
# echo "${arrCFCs[0]}"
echo $totalCFCs

num=0
for i in "${arrCFCs[@]}"
do
	fullFilename=$(echo "$i" | tr -d '\n')
	folderPath="$2"
	#if [[ $num -lt 6 ]]; then
		sh ./findFunctions.sh "$fullFilename" "$folderPath"
	#fi
	num=$((num+1))
done

