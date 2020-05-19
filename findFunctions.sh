#Please note that the GNU Grep is required. POSIX utilities does not support Perl regex.

#Set the folder name of the root path here
#example /Users/JoeBob/VM/Linux/coolsite.co/app/assets
rootPath="coolsite.co"
cfcAssets="assets"

findFunctionByType(){
	type="$2"
	#Note: must install GNU Grep for grep -P - Perl based regex, it has better features
	cfscriptMatch=$(grep -oP "($type\s.*?function\s).*?(?=\s?\()" "$1" | awk 'NF>1{print $NF}' | awk -v RS="" -v OFS='|' '$1=$1')
	cfmlMatch=$(sed -n '/<cffunction/,/">/p' "$1" | tr -d "\t" | tr "\r\n" " " | awk '{ gsub("<cff","\n<cff",$0); print $0 }' | grep "$type" | grep -oP "(cffunction\s?\sname\=\").*?(?=\")" | awk -F'\"' '{print $2}')

	if [[ ! -z $cfmlMatch && ! -z $cfscriptMatch ]]; then
		theFunctions="$cfmlMatch|$cfscriptMatch"
	elif [[ ! -z $cfscriptMatch ]]; then
		theFunctions="$cfscriptMatch"
	elif [[ ! -z $cfmlMatch ]]; then
		theFunctions="$cfmlMatch"
	else
		return 1
		#echo "No Matches found. Exiting"
		#exit
	fi

	echo "$theFunctions"
}

escapeSymbol(){
	if [[ $1 = "arrPublic" ]]; then
		printf "%s\s?\(|" ${arrPublic[*]} | sed s'/.$//'
	elif [[ $1 = "arrRemote" ]]; then
		printf "%s\s?\(|" ${arrRemote[*]} | sed s'/.$//'
	elif [[ $1 = "arrPrivate" ]]; then
		printf "%s\s?\(|" ${arrPrivate[*]} | sed s'/.$//'
	elif [[ $1 = "js" ]]; then
		printf "%s\s?\(|" ${arrRemote[*]} | sed s'/.$//'
	fi

}

createURLMethodArray(){
	declare -a arrURLMethodCalls
	num=0
	appendMethod="\?method\="
	for i in "${arrRemote[@]}"
	do
		arrURLMethodCalls[$num]="$(echo $appendMethod${i})"
		num=$((num+1))
	done
	printf "%s|" ${arrURLMethodCalls[*]} | awk '{print substr($0, 1, length($0)-1)}'
}

listFunctions(){
	echo
	echo "Functions in file $urlCall"
	echo " "
	echo "${#arrPublic[@]}" Public Functions found
	echo "${#arrRemote[@]}" Remote Functions found
	echo "${#arrPrivate[@]}" Private Functions found
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo "** Public Functions **"
	echo " "
	printf "%s \n" ${arrPublic[*]}
	echo " "
	echo "** Remote Functions **"
	echo " "
	printf "%s \n" ${arrRemote[*]}
	echo " "
	echo "** Private Functions **"
	echo " "
	printf "%s \n" ${arrPrivate[*]}
	echo "-------------------------------------------------------------------------------------------------------"
}

externalSimilar(){
	#echo $escapedAllFunctions
	grep --include=*.{cfc,cfm} -ErnH "$(printf "function %s\s?\(|" ${arrPublic[*]}"|"${arrRemote[*]}"|"${arrPrivate[*]} | sed s'/.$//')" "$2" | grep -vE "$urlCall"
}

displaySimilarFunctions(){
	echo
	numSimilar=$(echo "${externalSimilar}" | wc -l)
	echo External files with $numSimilar SIMILAR named functions to "$urlCall" ...
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	printf %s "${externalSimilar}"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
}

internalCalls(){
	internalPrivate=$(printf %s"\s?\(|" "${arrPrivate[@]}" | sed s'/.$//')
	internalPublic=$(printf %s"\s?\(|" "${arrPublic[@]}" | sed s'/.$//')
	internalRemote=$(printf %s"\s?\(|" "${arrRemote[@]}" | sed s'/.$//')

	tokenString="\\s?\("

	if [[ "$internalPrivate" != "$tokenString" && "$internalPublic" != "$tokenString" && "$internalRemote" != "$tokenString" ]]; then
		allInternalCalls=$(printf %s "$internalPrivate|$internalPublic|$internalRemote")
	elif [[ "$internalPrivate" != "$tokenString" ]]; then
		allInternalCalls=$(printf %s "$internalPrivate")
		if [[ "$internalRemote" != "$tokenString" ]]; then
			allInternalCalls+=$(printf %s "|$internalRemote")
		elif [[ "$internalPublic" != "$tokenString" ]]; then
			allInternalCalls+=$(printf %s "|$internalPublic")
		fi
	elif [[ "$internalRemote" != "$tokenString" ]]; then
		allInternalCalls=$(printf %s "$internalRemote")
		if [[ "$internalPrivate" != "$tokenString" ]]; then
			allInternalCalls+=$(printf %s "|$internalPrivate")
		elif [[ "$internalPublic" != "$tokenString" ]]; then
			allInternalCalls+=$(printf %s "|$internalPublic")
		fi
	elif [[ "$internalPublic" != "$tokenString" ]]; then
		allInternalCalls=$(printf %s "$internalPrivate")
		if [[ "$internalRemote" != "$tokenString" ]]; then
			allInternalCalls+=$(printf %s "|$internalRemote")
		elif [[ "$internalPrivate" != "$tokenString" ]]; then
			allInternalCalls+=$(printf %s "|$internalPrivate")
		fi
	fi

	if [[ "$allInternalCalls" != "$tokenString" ]]; then
		#echo "grep -PnH \"$allInternalCalls\" \"$1\" | grep -vE \"<\!--|//|\* @|public|private|remote| name=\""
		internalCalls=$(grep -PnH "$allInternalCalls" "$1" | grep -vE "<\!--|//|\* @|public|private|remote| name=")
		revisedInternal=$internalCalls
		for i in "${allInternalCalls[@]}"
		do
			if [[ $revisedInternal == *${i}* ]]; then
				revisedInternal=$(printf %s "$revisedInternal" | grep -vi "* "${i})
			fi
		done
		echo "${revisedInternal}"
	fi
}


displayInternalCalls(){
	internalCalls=$1
	echo
	printf %"s\n" "$(printf "${internalCalls}" | wc -l) Internal functions being called inside $urlCall if any..."
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo "${internalCalls}"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
}

externalCalls(){
	functionSet=""
	if [[ ! -z "${instantiateCheck}" ]]; then
		fileNames=$(echo "$instantiateCheck" | awk -F":" '{print $1}' | tr '\n' '|' | sed s'/.$//')
		fileTypes=$(echo "$instantiateCheck" | awk -F":" '{print $1}' | awk -F"." '{print $NF}' | tr '\n' '|' | sed s'/.$//')
		methodName=$(echo "$instantiateCheck" | awk -F":" '{print $NF}' | awk -F"var" '{print $NF}' |  awk -F"=" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | tr '\n' '|' | sed s'/.$//' | tr -d '[[:space:]]')

		if [[ ! -z "${fileTypes}" && ! -z "${methodName}" ]]; then
			OIFS=$IFS;
			IFS="|";
			arrMethodName=($methodName)
			arrFileTypes=($fileTypes)
			arrFileNames=($fileNames)
			IFS=$OIFS;


			if [[ "${#arrMethodName[@]}" != "${#arrFileTypes[@]}" ]]; then
				echo "An error has occurred, every method should have a filetype associated as it changes how it is implemented"
			else
				if [[ "${#arrMethodName[@]}" -gt 1 ]]; then
					num=0
					extFunction=""
					for i in "${arrMethodName[@]}"
					do
						num2=0
						for c in "${arrPublic[@]}"
						do
							#echo num
							#echo "${fileTypes[0]}"
							if [[ "${arrFileTypes[$num]}" == "js" ]]; then
								if [[ num -eq 0 && num2 -eq 0 ]]; then
									extFunctions="${i}.*?\+.*?\?method\=${c}"
								else
									extFunctions+="|${i}.*?\+.*?\?method\=${c}"
								fi
							else
								if [[ num -eq 0 && num2 -eq 0 ]]; then
									extFunctions=" ${i}.${c}"
								else
									extFunctions+="| ${i}.${c}"
								fi
							fi
							num2=$((num+1))
						done
						num2=0
						for c in "${arrRemote[@]}"
						do
							if [[ "${arrFileTypes[$num]}" == "js" ]]; then
								if [[ num -eq 0 && num2 -eq 0 ]]; then
									extFunctions="${i}.*?\+.*?\?method\=${c}"
								else
									extFunctions+="|${i}.*?\+.*?\?method\=${c}"
								fi
							else
								if [[ num -eq 0 && num2 -eq 0 ]]; then
									extFunctions=" ${i}\.${c}"
								else
									extFunctions+="| ${i}\.${c}"
								fi
							fi
							num2=$((num+1))
						done
						#echo "grep -PnH --include=*.{cfc,cfm,js} \"$extFunctions\" \"${arrFileNames[$num]}\""
						if [[ "$extFunctions" != "" ]]; then
							functionSet+=$(grep -PnH --include=*.{cfc,cfm,js} "$extFunctions" "${arrFileNames[$num]}")
						fi
						num=$((num+1))
					done
				fi
				printf %"s\n" "$functionSet"
			fi
		else
			echo "No known files instantiate $urlCall"
		fi
	fi
	#echo "ext"
	#echo "$functionSet"
}

fuzzyExternalCalls(){

	if [[ ! -z "$fuzzyMatch" ]]; then
		methodName=$(echo "$fuzzyMatch" | awk -F"var" '{print $NF}' |  awk -F"=" '{print $1}' | awk -F, '{gsub(/ /, "");print}' | awk -v RS="" -v OFS='|' '$1=$1')

		if [[ ! -z "${methodName}"  && "${#methodName[@]}" -gt 1 ]]; then
			arrMethodName=(${methodName//|/ })
			num=0
			for i in "${arrMethodName[@]}"
			do
				num2=0
				for c in "${arrPublic[@]}"
				do
					if [[ num -eq 0 && num2 -eq 0 ]]; then
						allExtFunctions="${i}.${c}"
					else
						allExtFunctions+="|${i}.${c}"
					fi
					num2=$((num+1))
				done
				num2=0
				for c in "${arrRemote[@]}"
				do
					if [[ num -eq 0 && num2 -eq 0 ]]; then
						allExtFunctions="${i}.${c}"
					else
						allExtFunctions+="|${i}.${c}"
					fi
					num2=$((num+1))
				done
				num=$((num+1))
			done
			escapedExtFunctions=$(escapeSymbol "$allExtFunctions")
			grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedExtFunctions | sed 's/\./\\./g')""" "$2"
		elif [[ ! -z "${methodName}"  && "${#methodName[@]}" = 1 ]]; then
			num2=0
			for c in "${arrPublic[@]}"
			do
				if [[ num2 -eq 0 ]]; then
					allExtFunctions=" $methodName.${c}"
				else
					allExtFunctions+="| $methodName.${c}"
				fi
				num2=$((num+1))
			done
			num2=0
			for c in "${arrRemote[@]}"
			do
				if [[ num2 -eq 0 ]]; then
					allExtFunctions=" $methodName.${c}"
				else
					allExtFunctions+="| $methodName.${c}"
				fi
				num2=$((num+1))
			done
			escapedExtFunctions=$(escapeSymbol "$allExtFunctions")
			grep --exclude="$1" --include=*.{cfc,cfm} -ErnH "$(echo $escapedExtFunctions | sed 's/\./\\./g')""" "$2"
		else
			echo "Nothing found"
		fi
	fi
}



displayExternalCalls(){
	externalFiles=$1
	echo
	printf %"s\n" "$(printf "${externalCalls}" | wc -l) External files referencing functions from $urlCall ..."
	echo "-------------------------------------------------------------------------------------------------------"
	echo
	echo "${externalCalls}"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
}


checkResults(){
	externalCallResults=$(echo "${externalCalls}" | tr '\n' '|' | sed s'/.$//')
	internalCallResults=$(echo "${internalCalls}" | tr '\n' '|' | sed s'/.$//')

	for i in "${arrPublic[@]}"
	do
		match=$(echo "${externalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" == *${i}* ]]; then
                extPublicFound+=($(echo "${i}"))
		else
                extPublicNotFound+=($(echo "${i}"))
        fi
        match=$(echo "${internalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" == *${i}* ]]; then
                intPublicFound+=($(echo "${i}"))
		else
                intPublicNotFound+=($(echo "${i}"))
        fi
        match=$(echo "${externalCallResults[*]} ${internalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" != *${i}* ]]; then
        	publicNotFound+=($(echo "${i}"))
        fi
	done

	for i in "${arrRemote[@]}"
	do
		match=$(echo "${externalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" == *${i}* ]]; then
                extRemoteFound+=($(echo "${i}"))
		else
                extRemoteNotFound+=($(echo "${i}"))
        fi
        match=$(echo "${internalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" == *${i}* ]]; then
                intRemoteFound+=($(echo "${i}"))
		else
                intRemoteNotFound+=($(echo "${i}"))
        fi
        match=$(echo "${externalCallResults[*]} ${internalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" != *${i}* ]]; then
        	remoteNotFound+=($(echo "${i}"))
        fi
	done

	for i in "${arrPrivate[@]}"
	do
		match=$(echo "${externalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" == *${i}* ]]; then
                extPrivateFound+=($(echo "${i}"))
		else
                extPrivateNotFound+=($(echo "${i}"))
        fi
        match=$(echo "${internalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" == *${i}* ]]; then
                intPrivateFound+=($(echo "${i}"))
		else
                intPrivateNotFound+=($(echo "${i}"))
        fi
        match=$(echo "${externalCallResults[*]} ${internalCallResults[*]}" | grep -oP "${i}[\\\"\'\(\&\s\n\r]" | head -1)
        if [[ "${match}" != *${i}* ]]; then
        	#echo "hello"
        	privateNotFound+=($(echo "${i}"))
        	#echo "\"${externalCallResults[*]} ${internalCallResults[*]} | grep -oP \"${i}[\"\'\(\&\s\n\r]\" | head -1"
        fi
	done

	displayAllResults "${extRemoteFound}" "${extRemoteNotFound}" "${intRemoteFound}" "${intRemoteNotFound}" "${extPublicFound}" "${extPublicNotFound}" "${intPublicFound}" "${intPublicNotFound}" "${extPrivateFound}" "${extPrivateNotFound}" "${intPrivateFound}" "${intPrivateNotFound}" "${remoteNotFound}" "${publicNotFound}" "${privateNotFound}"
}

instantiateCheck(){
	#echo "grep --exclude=\"$1\" --include=*.{cfc,cfm,js} -PrnH \"$fullCFCPath|$urlCall|$createObject\" \"$2\" | grep -vE \"\.git\""
	grep --exclude="$1" --include=*.{cfc,cfm,js} -PrnH "$fullCFCPath|$urlCall|$createObject" "$2" | grep -vE "\.git|<\!--|//|\* @"
}

fuzzyMatch(){
	fuzzyCalls=$(echo $1 | awk -F"/" '{print $NF}' |  awk -F"." '{print $1"\\\(\\\)"}')
	grep --exclude="$1" --include=*.{cfc,cfm,js} -ErnH "$fuzzyCalls" "$2" | grep -vE "$fullCFCPath|$urlCall|\.git"
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

clearNum(){
	element=($1)
	if [[ "${#element[@]}" == 1 &&  "${element[@]}" == "" ]]; then
		elementCount=0
	else
		elementCount="${#element[@]}"
	fi

	echo "$elementCount"
}

displayAllResults(){
	extRemoteFound="${1}"
	extRemoteNotFound="${2}"
	intRemoteFound="${3}"
	intRemoteNotFound="${4}"
	extPublicFound="${5}"
	extPublicNotFound="${6}"
	intPublicFound="${7}"
	intPublicNotFound="${8}"
	extPrivateFound="${9}"
	extPrivateNotFound="${10}"
	intPrivateFound="${11}"
	intPrivateNotFound="${12}"
	remoteNotFound="${13}"
	publicNotFound="${14}"
	privateNotFound="${15}"

	#Proper counts are set here, otherwise empty arrays appear to have a length of 1

	remoteCount=$(clearNum "${arrRemote[*]}") 
	publicCount=$(clearNum "${arrPublic[*]}")
	privateCount=$(clearNum "${arrPrivate[*]}")
	totalCount=$((remoteCount+publicCount+privateCount))

	extRemoteCount=$(clearNum "${extRemoteFound[*]}")
	extRemoteNFCount=$(clearNum "${extRemoteNotFound[*]}")
	intRemoteCount=$(clearNum "${intRemoteFound[*]}")
	intRemoteNFCount=$(clearNum "${intRemoteNotFound[*]}")

	extPublicCount=$(clearNum "${extPublicFound[*]}")
	extPublicNFCount=$(clearNum "${extPublicNotFound[*]}")
	intPublicCount=$(clearNum "${intPublicFound[*]}")
	intPublicNFCount=$(clearNum "${intPublicNotFound[*]}")

	extPrivateCount=$(clearNum "${extPrivateFound[*]}")
	extPrivateNFCount=$(clearNum "${extPrivateNotFound[*]}")
	intPrivateCount=$(clearNum "${intPrivateFound[*]}")
	intPrivateNFCount=$(clearNum "${intPrivateNotFound[*]}")

	extTotal=$((extPrivateCount+extRemoteCount+extPublicCount))
	intTotal=$((intPrivateCount+intRemoteCount+intPublicCount))

	remoteNFCount=$(clearNum "${remoteNotFound[*]}")
	publicNFCount=$(clearNum "${publicNotFound[*]}")
	privateNFCount=$(clearNum "${privateNotFound[*]}")
	totalNotFound=$((remoteNFCount+publicNFCount+privateNFCount))

	echo
	echo "$totalCount Functions searched" 
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	if [[ $totalCount -gt 0 ]]; then
		echo " "
		if [[ $remoteCount -gt 0 ]]; then
			echo " ** $remoteCount Remote **"
			echo " "
			printf %s" " ${arrRemote[*]}
			echo " "
		fi
		if [[ $publicCount -gt 0 ]]; then
			echo " ** $publicCount Public **"
			echo " "
			printf %s" " ${arrPublic[*]}
			echo " "
		fi
		if [[ $privateCount -gt 0 ]]; then
			echo " ** $privateCount Private **"
			echo " "
			printf %s" " ${arrPrivate[*]}
			echo " "
		fi
		echo "-------------------------------------------------------------------------------------------------------"
	fi
	echo 
	echo "$extTotal Functions found externally"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	if [[ $extTotal -gt 0 ]]; then
		echo
		if [[ $extRemoteCount -gt 0 ]]; then
			echo " ** $extRemoteCount Remote **"
			echo
			echo "${extRemoteFound[*]}"
			echo
		fi
		if [[ $extPublicCount -gt 0 ]]; then
			echo " ** $extPublicCount Public **"
			echo
			echo "${extPublicFound[*]}"
			echo
		fi
		if [[ $extPrivateCount -gt 0 ]]; then
			echo " ** $extPrivateCount Private **"
			echo 
			echo "${extPrivateFound[*]}"
			echo 
		fi
		echo "-------------------------------------------------------------------------------------------------------"
	fi
	echo
	echo "$intTotal Functions found internally that are called"
	echo
	echo "-------------------------------------------------------------------------------------------------------"
	if [[ $intTotal -gt 0 ]]; then
		echo
		if [[ $intRemoteCount -gt 0 ]]; then
			echo " ** $intRemoteCount Remote **"
			echo
			echo "${intRemoteFound[*]}"
			echo
		fi
		if [[ $intPublicCount -gt 0 ]]; then
			echo " ** $intPublicCount Public **"
			echo
			echo "${intPublicFound[*]}"
			echo
		fi
		if [[ $intPrivateCount -gt 0 ]]; then
			echo " ** $intPrivateCount Private **"
			echo 
			echo "${intPrivateFound[*]}"
			echo 
		fi
		echo "-------------------------------------------------------------------------------------------------------"
	fi
	echo
	echo "$instantiatedTotal Instantiations"
	echo "$fuzzyTotal Fuzzy instantiations"
	echo "$totalNotFound Functions out of $totalCount NOT called by anything anywhere in $urlCall"
	echo 
	if [[ $totalNotFound -gt 0 ]]; then
		echo "-------------------------------------------------------------------------------------------------------"
		echo
		if [[ $remoteNFCount -gt 0 ]]; then
			echo " ** $remoteNFCount Remote **"
			echo
			echo "${remoteNotFound[*]}"
			echo
		fi
		if [[ $publicNFCount -gt 0 ]]; then
			echo " ** $publicNFCount Public **"
			echo
			echo "${publicNotFound[*]}"
			echo
		fi
		if [[ $privateNFCount -gt 0 ]]; then
			echo " ** $privateNFCount Private **"
			echo 
			echo "${privateNotFound[*]}"
			echo 
		fi
		echo "-------------------------------------------------------------------------------------------------------"
	fi
	echo
	
	printf '%s\n' "$filename,$folderpath,$lines,$instantiatedTotal,$totalCount,$remoteCount,$remoteNFCount,$publicCount,$publicNFCount,$privateCount,$privateNFCount" >> summary.csv

}

if [ -f "$1" ]; then

filename=$(echo "$1" | awk -F"/" '{print $NF}')
folderpath=$(echo "$1" | awk -F"$rootPath" '{print $2}' | awk -v f="$filename" '{gsub(f, "");print}')
lines=$(wc -l < "$1" | tr -d '[[:space:]]')

publicFunctions=$(findFunctionByType "$1" "public")
remoteFunctions=$(findFunctionByType "$1" "remote")
privateFunctions=$(findFunctionByType "$1" "private")
arrPublic=(${publicFunctions//|/ })
arrRemote=(${remoteFunctions//|/ })
arrPrivate=(${privateFunctions//|/ })
escapedPublic=$(escapeSymbol "arrPublic")
escapedRemote=$(escapeSymbol "arrRemote")
escapedPrivate=$(escapeSymbol "arrPrivate")

#echo createURLMethodArray
urlMethodCalls=$(createURLMethodArray "$1")
urlCall=$(echo "$1" | awk -F"$rootPath/$cfcAssets" '{print $2}')
createObject=$(echo $filename | awk -F"." '{print "CreateObject\\\(\'\''component\'\'','\''.*?"$1}')

#echo listFunctions
listFunctions

#externalSimilar=$(externalSimilar "$1" "$2")
#displaySimilarFunctions
#exit

#echo instantiateCheck
fullCFCPath=$(echo $1 | awk -F"$rootPath/" '{print $2}' | awk -F"." '{print $1}' | awk -F"/" -v OFS="." '$1=$1')
instantiateCheck=$(instantiateCheck "$1" "$2")
fuzzyMatch=$(fuzzyMatch "$1" "$2")
if [[ "$instantiateCheck" == "" ]]; then
	instantiatedTotal=0
else
	instantiatedTotal=$(echo "$instantiateCheck" | wc -l | tr -d '[[:space:]]')
fi
if [[ "$fuzzyMatch" == "" ]]; then
	fuzzyTotal=0
else
	fuzzyTotal=$(echo "$fuzzyMatch" | wc -l | tr -d '[[:space:]]')
fi
displayInstantiateCheck

#echo externalCalls
externalCalls=$(externalCalls "$1" "$2")
#fuzzyExternalCalls=$(fuzzyExternalCalls "$1" "$2")
#echo "$fuzzyExternalCalls"
displayExternalCalls

#echo internalCalls
internalCalls=$(internalCalls "$1")
displayInternalCalls "$internalCalls"

#echo checkResults
checkResults

else
	echo "File does not exist!"
fi
