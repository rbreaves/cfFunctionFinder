cfmlMatch=$(grep -E "cffunction\s+\w" "$1" | grep -vE "<\!--|//|\* @|init" | awk -F'"' '$0=$2' | awk '$1="\."$1"\("' | awk -v RS="" -v OFS='|' '$1=$1')
cfscriptMatch=$(grep -E " function\s+\w" "$1" | grep -vE "<\!--|//|\* @|init" | grep -Eo " function .*\(" | awk -F'(' '{print $1}' | awk -F"function " '{print $2"\("}' | awk '$1="\."$1' | awk -v RS="" -v OFS='|' '$1=$1')

if [[ ! -z $cfmlMatch && ! -z $cfscriptMatch ]]; then
	allFunctions="$cfmlMatch|$cfscriptMatch"
elif [[ ! -z $cfscriptMatch ]]; then
	allFunctions="$cfscriptMatch"
elif [[ ! -z $cfmlMatch ]]; then
	allFunctions="$cfmlMatch"
else
	echo "No Matches found. Exiting"
	exit
fi

escapedAllFunctions=$(printf %s ${allFunctions} | awk '{gsub(/[ \(]/,"\\(");print}')

arrFunctions=(${allFunctions//|/ })
declare -a arrURLMethodCalls
echo ${arrFunctions[*]}

num=0
appendMethod="$(echo $1 | grep -Eo '[^/]+/?$' | cut -d / -f1)?method="
for i in "${arrFunctions[@]}"
do
	arrURLMethodCalls[$num]="$(echo $appendMethod${i:1}|sed 's/.$//')"
	num=$((num+1))
done
urlMethodCalls=$(printf "%s|" ${arrURLMethodCalls[*]} | awk '{print substr($0, 1, length($0)-1)}')
#echo ${arrURLMethodCalls[*]}
#exit

urlCall=$(echo $1 | awk -F"assets" '{print $2}')

echo
echo Functions found
echo
echo "-------------------------------------------------------------------------------------------------------"
printf %s ${allFunctions[*]} | awk '{gsub(/[ \(]/,"");print}'
echo "-------------------------------------------------------------------------------------------------------"

echo
echo External files with SIMILAR named functions to $urlCall ...
echo
echo "-------------------------------------------------------------------------------------------------------"
#echo grep --exclude="\"$1\"" --include=*.{cfc,cfm} -ErnH "$(echo $escapedAllFunctions | sed 's/\./function /g')|$(echo $escapedAllFunctions)" "\"$2\""
#exit
externalFiles=$(grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedAllFunctions | sed 's/\./function /g')|$(echo $escapedAllFunctions | sed 's/\./name=\\\"/g' | sed 's/[\\(]//g')" "$2")
echo
printf %s "${externalFiles}"
echo
echo "-------------------------------------------------------------------------------------------------------"
echo

echo "Functions being called within itself $urlCall if any..."
echo
echo "-------------------------------------------------------------------------------------------------------"
internalCalls=$(grep -EnH "$escapedAllFunctions" "$1" | grep -vE "<\!--|//|\* @|function| name=")
echo $internalCalls
revisedInternal=$internalCalls
for i in "${arrFunctions[@]}"
do
	if [[ $revisedInternal == *${i:1}* ]]; then
		#echo "line number"
		revisedInternal=$(printf %s "$revisedInternal" | grep -vi "* "${i:1})
		#printf %s "$revisedInternal"
		#exit
	fi
done
printf %s "${revisedInternal}"
echo
echo "-------------------------------------------------------------------------------------------------------"
echo
echo External files referencing functions inside $urlCall ...
echo
echo "-------------------------------------------------------------------------------------------------------"
externalFiles=$(grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedAllFunctions | sed 's/\./\\./g')|$urlMethodCalls" "$2")
echo
printf %s "${externalFiles}"
echo
echo "-------------------------------------------------------------------------------------------------------"

echo
declare -a notFound
declare -a funcFoundOut
declare -a funcFoundIn
for i in "${arrFunctions[@]}"
do
        if [[ $externalFiles == *${i:0}* ]]; then
                funcFoundOut+=$(echo "${i:0}" | sed 's/.$/ /')
        elif [[ $revisedInternal == *${i:1}* ]]; then
		funcFoundIn+=$(echo "${i:1}" | sed 's/.$/ /')
	else
                notFound+=$(echo "${i:1}" | sed 's/.$/ /')
        fi
done

num=0
for i in "${arrURLMethodCalls[@]}"
do
        if [[ $externalFiles == *${i}* ]]; then
                funcFoundOut+=$(echo "${i}" | sed 's/.$/ /')
		deleteFunc=$(echo ${arrFunctions[$num]} | awk '{print substr($1,2); }')
		notFound=$(echo "${notFound[@]/$deleteFunc}" | sed 's/.$/ /')
        elif [[ $revisedInternal == *${i:1}* ]]; then
                funcFoundIn+=$(echo "${i}" | sed 's/.$/ /')
        fi
	num=$((num+1))
done

echo
echo
echo "Files that instantiate or call $urlCall directly..."
echo
echo "-------------------------------------------------------------------------------------------------------"
whatCalls=$(echo $1 | awk -F"assets" '{print "assets"$2}' | awk -F"." '{print $1}' | awk -F"/" -v OFS="." '$1=$1')
echo $whatCalls
grep --exclude="$1" --include=*.{cfc,cfm,js} -ErnH "$whatCalls|urlCall" "$2"
echo fuzzy matching....
fuzzyCalls=$(echo $1 | awk -F"/" '{print $NF}' |  awk -F"." '{print $1"\\\("}')
grep --exclude="$1" --include=*.{cfc,cfm,js} -ErnH "$fuzzyCalls" "$2"| grep --exclude="$1" --include=*.{cfc,cfm,js} -vi "$whatCalls|urlCall"
echo 
echo "-------------------------------------------------------------------------------------------------------"
echo
echo Functions searched 
echo
echo "-------------------------------------------------------------------------------------------------------"
printf %s ${allFunctions[*]} | sed 's/[.(]//g' 
echo "-------------------------------------------------------------------------------------------------------"
echo
echo Functions found externally that are called
echo
echo "-------------------------------------------------------------------------------------------------------"
echo ${funcFoundOut[*]}
echo "-------------------------------------------------------------------------------------------------------"
echo
echo Functions found internally that are called
echo
echo "-------------------------------------------------------------------------------------------------------"
echo ${funcFoundIn[*]}
echo "-------------------------------------------------------------------------------------------------------"
echo
echo Functions NOT called by anything anywhere
echo "-------------------------------------------------------------------------------------------------------"
echo ${notFound[*]}
echo "-------------------------------------------------------------------------------------------------------"
echo
