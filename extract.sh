#!/usr/bin/bash

set -e

function help() {
    >&2 echo "Usage:"
    >&2 echo "  "$(basename $0)" all"
    >&2 echo "  "$(basename $0)" [file.ipk]"
    >&2 echo "  "$(basename $0)" [file.ipk] [extractDir]"
}

function extractIpk() {
    local ipkFile=$1
    local extractDir=$2
    if [ "$ipkFile" == "" ]; then
        echo "a file is required as argument"
        help
        exit 1
    fi

    ipkFile=$(readlink -f $ipkFile)
    test -f $ipkFile || (echo $ipkFile" is not a file" && exit 1)

    if [ "$extractDir" == "" ]; then
        extractDir=${ipkFile/.ipk/}
    fi
    mkdir -p $extractDir
    test -d $extractDir || (echo $extractDir" is not a directory" && exit 1)

    # Extract files
    (
        cd $extractDir
        ar x $ipkFile
        mkdir -p data
        (
            cd data
            tar xvf ../data.tar.gz
        )
        local i=0
        for imgFile in $(find data -name '*.img'); do
            mkdir -p img-$i
            unsquashfs -f -d img-$i $imgFile
            i=$(( i + 1 ))
        done
    )

    # Extract information
    t=$(mktemp)
    ipkInfoFile=${ipkFile/.ipk/.info.txt}
    rm -f $ipkInfoFile
    touch $ipkInfoFile

    echo -e "Application information appinfo.json:" >> $ipkInfoFile
    find $extractDir -name appinfo.json -exec cat {} \; > $t
    (test -z "$(cat $t)" && echo "No appinfo.json file found" || jq -r < $t) >> $ipkInfoFile

    echo -e "\nApplication information packageinfo.json:" >> $ipkInfoFile
    find $extractDir -name packageinfo.json -exec cat {} \; > $t
    (test -z "$(cat $t)" && echo "No packageinfo.json file found" || jq -r < $t) >> $ipkInfoFile

    echo -e "\nApplication information resourceinfo.json:" >> $ipkInfoFile
    find $extractDir -name resourceinfo.json -exec cat {} \; > $t
    (test -z "$(cat $t)" && echo "No resourceinfo.json file found" || jq -r < $t) >> $ipkInfoFile

    echo -e "\nBuild information on cobalt:" >> $ipkInfoFile
    find $extractDir -name build_info -exec cat {} \; > $t
    (test -z "$(cat $t)" && echo "No build_info file found" || cat $t) >> $ipkInfoFile

    echo -e "\nInternal build information on cobalt:" >> $ipkInfoFile
    find $extractDir -type f -name cobalt -exec strings {} \; | grep sb_api | head -n 1 | jq -r > $t
    (test -z "$(cat $t)" && echo "No cobalt file found" || cat $t) >> $ipkInfoFile
    
    echo -e "\nInternal build information on libcobalt.so:" >> $ipkInfoFile
    find $extractDir -type f -name libcobalt.so -exec strings {} \; | grep sb_api | head -n 1 | jq -r > $t
    (test -z "$(cat $t)" && echo "No libcobalt.so file found" || cat $t) >> $ipkInfoFile

    rm $t
}


function main() {
    if [ "$1" == "all" ]; then
        root=$(readlink -f $(dirname $0))
        (
            cd $root
            for i in $(ls *.ipk); do
                extractIpk $i
            done
        )
    else
        extractIpk "$@"
    fi
}

main "$@"
