
findMatches(){
	cfmlMatch=$(grep -E "cffunction\s+\w" "$1" | grep -vE "<\!--|//|\* @|init" | awk -F'"' '$0=$2' | awk '$1="\."$1"\("' | awk -v RS="" -v OFS='|' '$1=$1')
	cfscriptMatch=$(grep -E " function\s+\w" "$1" | grep -vE "<\!--|//|\* @|init" | grep -Eo " function .*\(" | awk -F'(' '{print $1}' | awk -F"function " '{print $2"\("}' | awk '$1="\."$1' | awk -v RS="" -v OFS='|' '$1=$1')

	if [[ ! -z $cfmlMatch && ! -z $cfscriptMatch ]]; then
		allFunctions="$cfmlMatch|$cfscriptMatch"
	elif [[ ! -z $cfscriptMatch ]]; then
		allFunctions="$cfscriptMatch"
	elif [[ ! -z $cfmlMatch ]]; then
		allFunctions="$cfmlMatch"
	else
		return 1
		#echo "No Matches found. Exiting"
		#exit
	fi
	echo $allFunctions
}

escapeSymbol(){
	printf %s $1 | awk '{gsub(/[ \(]/,"\\(");print}'
}

createURLMethodArray(){
	declare -a arrURLMethodCalls
	num=0
	appendMethod="$(echo $1 | grep -Eo '[^/]+/?$' | cut -d / -f1)?method="
	for i in "${arrFunctions[@]}"
	do
		arrURLMethodCalls[$num]="$(echo $appendMethod${i:1}|sed 's/.$//')"
		num=$((num+1))
	done
	printf "%s|" ${arrURLMethodCalls[*]} | awk '{print substr($0, 1, length($0)-1)}'
}

listFunctions(){
	echo
	echo Functions found
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	printf %s ${allFunctions[*]} | awk '{gsub(/[ \(]/,"");print}'
	echo "-------------------------------------------------------------------------------------------------------"
}

externalSimilar(){
	grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedAllFunctions | sed 's/\./function /g')|$(echo $escapedAllFunctions | sed 's/\./name=\\\"/g' | sed 's/[\\(]//g')" "$2"
}

displaySimilarFunctions(){
	echo
	echo External files with SIMILAR named functions to $urlCall ...
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	printf %s "${externalSimilar}"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
}

internalCalls(){
	internalCalls=$(grep -EnH "$escapedAllFunctions" "$1" | grep -vE "<\!--|//|\* @|function| name=")
	revisedInternal=$internalCalls
	for i in "${arrFunctions[@]}"
	do
		if [[ $revisedInternal == *${i:1}* ]]; then
			revisedInternal=$(printf %s "$revisedInternal" | grep -vi "* "${i:1})
		fi
	done
	echo "${revisedInternal}"
}


displayInternalCalls(){
	internalCalls=$1
	echo
	echo "Functions being called within itself $urlCall if any..."
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo "${internalCalls}"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
}

externalCalls(){
	methodName=$(echo $instantiateCheck | awk -F"var" '{print $NF}' |  awk -F"=" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')
	#fileNames=$(echo $instantiateCheck | awk -F":" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')
	#fuzzyMethodName=$(echo $fuzzyMatch | awk -F"var" '{print $NF}' |  awk -F"=" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')
	#fuzzyFileNames=$(echo $fuzzyMatch | awk -F":" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')
	#if [[ ! -z $methodName && ! -z $fuzzyMethodName ]]; then
	#	methodName+="|$fuzzyMethodName"
	#elif [[ ! -z $fuzzyMethodName ]]; then
	#	methodName="$fuzzyMethodName"
	#fi

	arrMethodName=(${methodName//|/ })
	num=0
	for i in "${arrMethodName[@]}"
	do
		num2=0
		for c in "${arrFunctions[@]}"
		do
			if [[ num -eq 0 && num2 -eq 0 ]]; then
				allFunctions="${i}${c}"
			else
				allFunctions+="|${i}${c}"
			fi
			num2=$((num+1))
		done
		num=$((num+1))
	done
	escapedExtFunctions=$(escapeSymbol "$allFunctions")
	grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedExtFunctions | sed 's/\./\\./g')""|$urlMethodCalls" "$2"
}

fuzzyExternalCalls(){
	methodName=$(echo $fuzzyMatch | awk -F"var" '{print $NF}' |  awk -F"=" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')

	arrMethodName=(${methodName//|/ })
	num=0
	for i in "${arrMethodName[@]}"
	do
		num2=0
		for c in "${arrFunctions[@]}"
		do
			if [[ num -eq 0 && num2 -eq 0 ]]; then
				allFunctions="${i}${c}"
			else
				allFunctions+="|${i}${c}"
			fi
			num2=$((num+1))
		done
		num=$((num+1))
	done
	escapedExtFunctions=$(escapeSymbol "$allFunctions")
	grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedExtFunctions | sed 's/\./\\./g')""" "$2"
}



displayExternalCalls(){
	externalFiles=$1
	echo
	echo External files referencing functions inside $urlCall ...
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo "${externalCalls}"
	echo "fuzzy matching..."
	echo "${fuzzyExternalCalls}"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
}


checkResults(){
	fuzzyExternalResults=$(echo "${fuzzyExternalCalls}" | awk -F":" '{print $NF}' |  awk -F"(" '{print $1}' | awk '{$1=$1};1' | sort | uniq | awk -v RS="" -v OFS='|' '$1=$1')
	externalCallResults=$(echo "${externalCalls}" | awk -F":" '{print $NF}' |  awk -F"(" '{print $1}' | awk '{$1=$1};1' | sort | uniq | awk -v RS="" -v OFS='|' '$1=$1')

	internalCallResults=$(echo "${internalCalls}" | awk -F"(" '{print $1}' | awk -F" " '{print $NF}' | awk '{$1=$1};1' | sort | uniq | awk -v RS="" -v OFS='|' '$1=$1')

	#echo "fuzzy: " "$fuzzyExternalResults" " external: " "$externalCallResults" " internalCallResults: " "$internalCallResults"

	declare -a notFound
	declare -a notFoundFuzzy
	declare -a funcFoundOut
	declare -a funcFuzzyFoundOut
	declare -a funcFoundIn

	echo "$fuzzyExternalResults"

	for i in "${arrFunctions[@]}"
	do
			oneFunction=$(echo "${i}" | sed s/.$//)
	        if [[ "$externalCallResults" == *$oneFunction* ]]; then
	                funcFoundOut+=$(echo "${i:0}" | sed 's/.$/ /')
	                #echo "${i:0} external "
	        elif [[ "$fuzzyExternalResults" == *$oneFunction* ]]; then
					funcFuzzyFoundOut+=$(echo "${i:1}" | sed 's/.$/ /')
					#echo "${i:0} fuzzy "
			elif [[ "$internalCallResults" == *${oneFunction:1}* ]]; then
					funcFoundIn+=$(echo "${i:1}" | sed 's/.$/ /')
					#echo "${i:0} internal "
			else
	                notFound+=$(echo "${i:1}" | sed 's/.$/ /')
	                #echo "${i:0} notfound  $internalCallResults ${oneFunction:1}"
	        fi
	done

	displayAllResults "$funcFoundOut" "$funcFuzzyFoundOut" "$funcFoundIn" "$notFound"
}

instantiateCheck(){
	grep --exclude="$1" --include=*.{cfc,cfm,js} -ErnH "$fullCFCPath|$urlCall" "$2"
}

fuzzyMatch(){
	fuzzyCalls=$(echo $1 | awk -F"/" '{print $NF}' |  awk -F"." '{print $1"\\\("}')
	grep --exclude="$1" --include=*.{cfc,cfm,js} -ErnH "$fuzzyCalls" "$2" | grep -vE "$fullCFCPath|$urlCall"
	#allFuzzyMatches=$(echo $fuzzyMatch | awk -F"var " '{print $2}' | awk -F"=" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')
}

displayInstantiateCheck(){
	echo
	echo "Files that instantiate or call $urlCall directly..."
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo "$instantiateCheck"
	echo fuzzy matching....
	echo "$fuzzyMatch"
	echo 
	echo "-------------------------------------------------------------------------------------------------------"
}

displayAllResults(){
	funcFoundOut=$1
	funcFuzzyFoundOut=$2
	funcFoundIn=$3
	notFound=$4
	echo
	echo Functions searched 
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	printf %s ${allFunctions[*]} | sed 's/[.(]//g' 
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo Fuzzy functions found externally that are called
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo "${funcFuzzyFoundOut[*]}"
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo Functions found externally that are called
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo "${funcFoundOut[*]}"
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo Functions found internally that are called
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo "${funcFoundIn[*]}"
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo Functions NOT called by anything anywhere
	echo "-------------------------------------------------------------------------------------------------------"
	echo "${notFound[*]}"
	echo "-------------------------------------------------------------------------------------------------------"
	echo
}

#echo findMatches
allFunctions=$(findMatches "$1" "$2")
escapedAllFunctions=$(escapeSymbol "$allFunctions")
arrFunctions=(${allFunctions//|/ })

#echo createURLMethodArray
urlMethodCalls=$(createURLMethodArray "$1")
urlCall=$(echo $1 | awk -F"assets" '{print $2}')

#echo listFunctions
listFunctions
externalSimilar=$(externalSimilar "$1" "$2")
displaySimilarFunctions

#echo instantiateCheck
fullCFCPath=$(echo $1 | awk -F"assets" '{print "assets"$2}' | awk -F"." '{print $1}' | awk -F"/" -v OFS="." '$1=$1')
instantiateCheck=$(instantiateCheck "$1" "$2")
fuzzyMatch=$(fuzzyMatch "$1" "$2")
displayInstantiateCheck

#echo externalCalls
externalCalls=$(externalCalls "$1" "$2")
fuzzyExternalCalls=$(fuzzyExternalCalls "$1" "$2")
displayExternalCalls

#echo internalCalls
internalCalls=$(internalCalls "$1")
displayInternalCalls "$internalCalls"

#echo checkResults
checkResults
