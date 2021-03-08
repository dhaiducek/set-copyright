#!/bin/bash
# Copyright Contributors to the Open Cluster Management project

# TESTED ON MAC!

# NOTE: If the community copyright gets injected at the bottom of the file, check that
# the Red Hat copyright is padded with spaces between the comment character(s)

TMP_FILE="tmp_file"

EXCLUDE_DIR_PREFIX=(
    "\."                # Hidden directories
    "node_modules"      # Node modules
    "build-harness"     # Build harness
    "vbh"               # Vendorized build harness
    ".*_generated\.*"   # Generated files
    )

FILTER_PATTERN=$(for i in "${!EXCLUDE_DIR_PREFIX[@]}"; do
    printf "^\./${EXCLUDE_DIR_PREFIX[i]}"
    if (( i < ${#EXCLUDE_DIR_PREFIX[@]} - 1 )); then
        printf "\|";
    fi
done)

ALL_FILES=$(find . -name "*" | grep -v "${FILTER_PATTERN}")

DRY_RUN=${DRY_RUN:-true}

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

COMMUNITY_COPY_HEADER_FILE="$SCRIPT_DIR/copyright-header.txt"

if [ ! -f $COMMUNITY_COPY_HEADER_FILE ]; then
  echo "File $COMMUNITY_COPY_HEADER_FILE not found!"
  exit 1
fi

RH_COPY_HEADER=()
for year in {2020..2021}; do
    RH_COPY_HEADER+=( "Copyright (c) ${year} Red Hat, Inc." )
done

COMMUNITY_COPY_HEADER_STRING=$(cat $COMMUNITY_COPY_HEADER_FILE)

echo "Desired copyright header is: $COMMUNITY_COPY_HEADER_STRING"

# NOTE: Only use one newline or javascript and typescript linter/prettier will complain about the extra blank lines
NEWLINE="\n"

if [[ "$DRY_RUN" == true ]]; then
   echo "---- Beginning dry run ----"
fi

for FILE in $ALL_FILES
do
    echo "FILE: $FILE:"
    if [[ -d $FILE ]] ; then
        echo -e "\t-Directory; skipping"
        continue
    fi

    COMMENT_START="# "
    COMMENT_END=""

    if [[ $FILE  == *".go" ]]; then
        COMMENT_START="// "
    fi

    if [[ $FILE  == *".ts" || $FILE  == *".tsx" || $FILE  == *".js" ]]; then
        COMMENT_START="/* "
        COMMENT_END=" */"
    fi

    if [[ $FILE  == *".md" ]]; then
        COMMENT_START="[comment]: # ( "
        COMMENT_END=" )"
    fi

    if [[ $FILE  == *".html" ]]; then
        COMMENT_START="<!-- "
        COMMENT_END=" -->"
    fi

    if [[ $FILE  == *".go"       \
            || $FILE == *".yaml" \
            || $FILE == *".yml"  \
            || $FILE == *".sh"   \
            || $FILE == *".js"   \
            || $FILE == *".ts"   \
            || $FILE == *".tsx"   \
            || $FILE == *"Dockerfile" \
            || $FILE == *"Makefile"  \
            || $FILE == *"Dockerfile.prow" \
            || $FILE == *"Makefile.prow"  \
            || $FILE == *".gitignore"  \
            || $FILE == *".md"  ]]; then

        COMMUNITY_HEADER_AS_COMMENT="$COMMENT_START$COMMUNITY_COPY_HEADER_STRING$COMMENT_END"

        if grep -qF "$COMMUNITY_HEADER_AS_COMMENT" "$FILE"; then
            echo -e "\t- Header already exists; skipping"
        else

            if [[ "$DRY_RUN" == true ]]; then
                echo -e "\t- [DRY RUN] Will add Community copyright header to file"
                continue
            fi

            ALL_COPYRIGHTS=""

            for rh_header in "${RH_COPY_HEADER[@]}"; do
                RH_COPY_HEADER_AS_COMMENT="$COMMENT_START$rh_header$COMMENT_END"
                if grep -qF "$RH_COPY_HEADER_AS_COMMENT" "$FILE"; then
                    ALL_COPYRIGHTS="$ALLCOPYRIGHTS$RH_COPY_HEADER_AS_COMMENT$NEWLINE"
                    grep -vF "$RH_COPY_HEADER_AS_COMMENT" $FILE > $TMP_FILE
                    mv $TMP_FILE  $FILE
                    echo -e "\t- Has Red Hat copyright header"
                fi
            done

            # Capture any other header information
            if (head -1 ${FILE} | grep "^$(echo "${COMMENT_START}" | sed 's/ $//' | sed 's/\*/\\*/')" &>/dev/null); then
                if [[ -z "${COMMENT_END}" ]]; then
                    # Capture up to the first blank line and then capture any comments within
                    EXISTING_HEADER=$(sed '/^$/q' $FILE | sed "/^[^${COMMENT_START}]/q" | sed '$d')
                    ALL_COPYRIGHTS="${EXISTING_HEADER}${NEWLINE}${ALL_COPYRIGHTS}"
                    grep -v "^[$COMMENT_START]\{1,3\}$" $FILE | grep -vF "$(echo "$EXISTING_HEADER" | grep -v "^[${COMMENT_START}]\{1,3\}$")" > $TMP_FILE
                    mv $TMP_FILE  $FILE
                    echo -e "\t- Has general header"
                else
                    # Capture first full comment
                    EXISTING_HEADER=$(sed -n "\%^$(echo "${COMMENT_START}" | sed 's/ $//' | sed 's/\*/\\*/')%,\%$(echo "${COMMENT_END}" | sed 's/^ //' | sed 's/\*/\\*/')$%p" $FILE)
                    ALL_COPYRIGHTS="${EXISTING_HEADER}${NEWLINE}${ALL_COPYRIGHTS}"
                    sed "\%^$(echo "${COMMENT_START}" | sed 's/ $//' | sed 's/\*/\\*/')%,\%$(echo "${COMMENT_END}" | sed 's/^ //' | sed 's/\*/\\*/')$%d" $FILE > $TMP_FILE
                    mv $TMP_FILE  $FILE
                    echo -e "\t- Has general header"
                fi
            fi

            ALL_COPYRIGHTS="$ALL_COPYRIGHTS$COMMUNITY_HEADER_AS_COMMENT$NEWLINE"
            echo -e "$ALL_COPYRIGHTS" > $TMP_FILE
            cat $FILE >> $TMP_FILE
            mv $TMP_FILE $FILE

            # Make sure shell script files are still executable
            if  [[ $FILE == *".sh" ]]; then
              chmod 755 $FILE
            fi

            echo -e "\t- Adding Community copyright header to file"
        fi
    else
        echo -e "\t- DO NOTHING"
    fi

    COMMENT_END=""
done

rm -f $TMP_FILE
