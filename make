#!/bin/bash
# Script to compile latex documents which has to be seperated in one main document and dependend sections in different files.
# Figures are expected in a directory pictures_src.
# Original graphics in vector formates will be converted into pdf and moved to pictures directory.
# Graphics in pdf or bitmap formats will be linked into a directory pictures.
# The compiled document will automatically opened with okular if installed.
# There is also an option to compress the file.
# Function declarations
function findMain {
     if([ ! $file ]); then
        if([ ! ${1} ]); then
            echo "Provide base file name or press ENTER."
            read file
            echo $file
            if [[ -z ${file} ]]; then
                echo "Assuming file:"
                file=`grep -lr --include="*.tex" "begin{document}" .`
            fi
        fi
     fi
     if([ ! -e $file ]); then
         echo "$File does not exist!"
         exit 1
     fi
    echo "==> $file"
    file=`basename $file .tex `
    # Find name of bib file used in main document
    bib_file="`grep -oP '.*\K(?<={)\w+(?=.bib})' $file.${suffix[0]}`.bib"
    bib_dir=`find . -name ${bib_file} | head -1`
    if [[ ! -e $bib_file ]]; then
        ln -s $bib_dir $bib_file
    fi
}

function findUpToDate {
# if there are no changes to any .tex file or to .bib
# script will exit
    changes=$1;
    if [[ $changes -gt 0 ]]; then
        rm $file.${clear_suff[0]}
    fi
   
    for i in `find . -name \*.${suffix[0]} | xargs`;
    do
        if [[ ${i} -ot $file.${suffix[4]} ]]; then
            echo "No changes to `basename ${i}`"
        else
            changes=$(($changes + 1))
        fi
    done
    
    if [[ ${bib_file} -ot $file.${suffix[4]} ]]; then 
        echo "No changes to ${bib_file}."
    else
        changes=$(($changes + 1))
        rm ${file}.${suffix}[4]
    fi
    if [[ $changes -eq 0 ]]; then
        echo "Nothing to do."
        if [[ ${1} -eq ${options[0]} ]]; then
            echo "Will open $file.${suffix[3]}."
            openPdf
        fi
        exit
    fi
}

function makeBib {
    
    if ([ `grep -c --exclude=*.sh "LaTeX Warning: There were undefined references." $file.${suffix[1]}` > 0 ] || [ -e $file.${suffix[2]} ]) ; then
        if [[ `grep -c --exclude=*.sh "biber" $file.${suffix[0]}`> 0 ]]; then
            biber $file
        else
            bibtex $file.${suffix[4]}
        fi
        pdflatex $directory/$file.${suffix[0]}
        pdflatex $directory/$file.${suffix[0]}
    fi
    if ([ `grep -c --exclude=*.sh "LaTeX Warning: Label(s) may have changed." $file.${suffix[1]}` -gt 0 ]); then
        
        pdflatex $directory/$file.${suffix[0]}
       
    fi
}

function makeGlossaries {
    if [[ `grep -c --exclude=*.sh "glossaries" $file.${suffix[0]}`> 0 ]]; then
            makeglossaries $file
            pdflatex $directory/$file.${suffix[0]}
    fi
}

function makeLineno {
    if ([ `grep -c --exclude=*.sh "Package lineno Warning: Linenumber reference failed" $file.${suffix[1]}` -gt 0 ] || [ -e $file.${suffix[2]} ]) ; then
        pdflatex $directory/$file.${suffix[0]}
    fi
}

function makePic {
    targetPath=pictures
    path=pictures_src
    if([ -d $path ]); then 
        if([ ! -d $targetPath ]); then
            mkdir $targetPath
            echo "Created directory $targetPath."
        fi
    fi
    updatedPics=0;
    for i in `ls $path | xargs`; do
        srcFile=${i}
        if ([ "$srcFile" != "${srcFile/%eps}" ]); then
            # Deal with eps
            targetFile=$targetPath/`basename $srcFile .eps`.pdf
            if [[ -e $targetFile ]]; then
                if [ $(stat -c '%Z' $path/$srcFile) -gt  $(stat -c '%Z' $targetFile) ]; then
                    rm $targetFile
                fi
            fi
            if [[ ! -e $targetFile ]]; then
                #echo $targetFile
                `epstopdf $path/$srcFile`
                echo "Converted $srcFile to eps."
                mv $path/`basename $targetFile` $targetPath
                echo "Moved `basename $targetFile` to $targetPath."
                updatedPics=$(($updatedPics + 1))
            fi
        fi
        if ([ "$srcFile" != "${srcFile/%svg}" ]); then
            # Deal with svg
            targetFile=$targetPath/`basename $srcFile .svg`.pdf
            if [[ -e $targetFile ]]; then
                if [ $(stat -c '%Z' $path/$srcFile) -gt  $(stat -c '%Z' $targetFile) ]; then
               rm $targetFile
                fi
            fi
            if [[ ! -e $targetFile ]]; then
                `inkscape -z --file=$path/$srcFile --export-pdf=$targetFile` 
                echo "Created `basename $targetFile`"  
                updatedPics=$(($updatedPics + 1))
            fi
        else
            # Deal with pdf and png...
            targetFile=$targetPath/$srcFile
            if( [ ! -e $targetFile ] || [ $(stat -c '%Z' $path/$srcFile) -gt  $(stat -c '%Z' $targetFile) ]); then
                # Don't know why, but link needs to be realative.
                cd $targetPath
                ln -s "../$path/$srcFile" $srcFile
                echo "Created symbolic link for $srcFile in $targetPath."
                cd ..
                updatedPics=$(($updatedPics + 1))
            fi
        fi
    done

    echo "Pictures updated: $updatedPics"
}

function makeClean {
    echo "Clean directory."

    for i in ${clear_suff[@]}; do
        echo "Remove ${file}.${i}."
        rm  *.${i} 
    done
    if([ -d pictures ]); then
        rm -r pictures
    fi
    exit
}

function openPdf {
    if [ `grep -c "Output written on." $file.${suffix[1]}` -eq 0 ]; then
        echo "Exit."
        #exit
        #not nice but seems to do the job
    elif ([ ! `ps -f | grep -c $file.${suffix[3]}` -gt 1 ]); then
        if [ -z `which okular` ];  then
            evince $file.${suffix[3]} 
        else
            okular $file.${suffix[3]} 
        fi
    else
        echo "$file.${suffix[3]} is already running."
    fi
}

function spellCheck {
    for i in `find . -name \*.${suffix[0]} | xargs`;
    do
        if [[ ${1} = "de" ]]; then
            aspell -t -x -c --lang de_DE-neu ${i}
        else
            aspell -t -x -c ${i}
        fi
    done
    exit
}

function compress {
    compressedFile="$file-compressed.${suffix[3]}"
    if ([ -f $file.${suffix[3]} ]); then
        `gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$compressedFile $file.${suffix[3]}`
    fi
}

function getWarnings {
    WARNINGS=`grep -c "[W/w]arning" $file.${suffix[1]}`
    echo "++++"
    echo "There occurred $WARNINGS warning(s):"
    if ([ $WARNINGS -le 10 ]); then
        grep -s -n --color "[W/w]arning" $file.${suffix[1]}
    fi
    echo "++++"
}

function getErrors {
    echo "++++"
    echo "There occurred `grep -c "[E/e]rror" $file.${suffix[1]}` error(s):"
    grep -s -n --color "[E/e]rror" $file.${suffix[1]}
    echo "++++"
}

function getOverFlow {
    OVERWARNINGS=`grep -c "[o,O]verfull" $file.${suffix[1]}`
    echo "++++"
    echo "There occurred $OVERWARNINGS box overflow(s)."
    if ([ $OVERWARNINGS -le 10 ]); then
        grep -s -n --color "[o,O]verfull" $file.${suffix[1]}
    fi
    echo "++++"
}

function getUnderFlow {
    UNDERWARNINGS=`grep -c "[u,U]nderfull" $file.${suffix[1]}`
    echo "++++"
    echo "There occurred $UNDERWARNINGS box underflow(s)."
    if ([ $UNDERWARNINGS -le 10 ]); then
        grep -s -n --color "[u,U]nderfull" $file.${suffix[1]}
    fi
    echo "++++"
}

function makeCopy {
    target=${1}
    echo "++++"
    echo "Copying ${file}.${suffix[3]} to given destination:"
    echo "${target}"
    echo "++++"
    cp ${file}.${suffix[3]} ${target}
}

function makeReview {
    echo "++++"
    echo "Preparing abstract."
    echo "Zipping figures."
    echo "++++"
    pdfseparate -f 1 -l 1 ${file}.${suffix[3]} ${file}_abstract.${suffix[3]}
    zip figures -xi fig*
}

### MAIN ###

suffix=( tex log bib pdf aux )
pic_suff=( pdf jpg jpeg png bmp tiff pnm )
clear_suff=( acn acr alg aux bbl bcf blg glg glo gls glsdefs ist run.xml out log toc )
directory=`pwd`
options=( "open" "clean" "check" "pic" "compress" "copy" "review")

# in any case
findMain

case ${1} in
    "")
        makePic
        findUpToDate $updatedPics
        pdflatex -halt-on-error $directory/$file.${suffix[0]}
        makeGlossaries
        makeBib
        makeLineno
        getWarnings
        getOverFlow
        getUnderFlow
        getErrors
        openPdf
        ;;
    ${options[1]})
        makeClean ${2}
        exit
        ;;
    ${options[2]})
        spellCheck ${2}
        exit
        ;;
    ${options[0]})
        openPdf
        exit
        ;;
    ${options[3]})
        makePic
        exit
        ;;
    ${options[4]})
        compress
        exit
        ;;
    ${options[5]})
        makeCopy ${2}
        exit
        ;;
    ${options[6]})
        makeReview
        exit
        ;;
    *)
        echo "Options" 
        echo ${options[@]}
        exit
esac
