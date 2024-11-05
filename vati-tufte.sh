#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <html_file>"
    exit 1
fi

# Store the file path from the argument
HTML_FILE="$1"

# Verify if the file exists and is readable
if [ ! -f "$HTML_FILE" ] || [ ! -r "$HTML_FILE" ]; then
    echo "Error: File not found or not readable."
    exit 1
fi

# Extract content between the markers
HTML_HEAD_FOOT_REMOVED=$(awk '
    /<div class="documento">/ { in_document = 1 }
    in_document { print }
    /<!-- \/CONTENUTO DOCUMENTO -->/ && in_document { print "</div>"; in_document = 0 }
    ' "$HTML_FILE"
)

HTML_NBSP_FIXED=$(printf "%s\n" "$HTML_HEAD_FOOT_REMOVED" | awk '{ gsub(/&nbsp;/, " "); print }')

# TEST: remove this later, plz
printf "%s\n" "$HTML_NBSP_FIXED" > ede-no-nbsp.html

# Using `printf` and not `echo` because whitespaces needs to be preserved.
MARKDOWN=$(printf "%s\n" "$HTML_NBSP_FIXED" | quarto pandoc --from=HTML --to=markdown)

# Process the footnotes with awk
PROCESSED_MARKDOWN=$(printf "%s\n" "$MARKDOWN" | awk '
    BEGIN { in_notes = 0 }
    /^(\*\*NOTES\*\*)$/ { in_notes = 1; next } # Skip the "NOTES" line
    {
        if (in_notes) {
            # Replace ^n^ or ^n ^ with [^n]: after the "NOTES" marker
            while (match($0, /\^([0-9]{1,3}) ?\^/)) {
                footnote_num = substr($0, RSTART+1, RLENGTH-2)
                gsub(/ $/, "", footnote_num)  # remove trailing space if present
                $0 = substr($0, 1, RSTART-1) "[^" footnote_num "]: " substr($0, RSTART + RLENGTH)
            }
        } else {
            # Replace ^n^ or ^n ^ with [^n] before the "NOTES" marker
            while (match($0, /\^([0-9]{1,3}) ?\^/)) {
                footnote_num = substr($0, RSTART+1, RLENGTH-2)
                if (substr(footnote_num, length(footnote_num), 1) == " ") {
                    footnote_num = substr(footnote_num, 1, length(footnote_num) - 1)
                }
                $0 = substr($0, 1, RSTART-1) "[^" footnote_num "]" substr($0, RSTART + RLENGTH)
            }
        }
        print
    }
')

printf "%s\n" "$PROCESSED_MARKDOWN"

FOOTNOTE_EXTRA_FIX_MARKDOWN=$(printf "%s\n" "$PROCESSED_MARKDOWN" | awk '
    {
        # Match cases like ^13 ^ with optional punctuation or newline after
        while (match($0, /\^([0-9]{1,3})[[:space:]]?\^([[:punct:]]*|\n|$)/)) {
            footnote_num = substr($0, RSTART+1, RLENGTH-2)
            # Remove any trailing space from the number if present
            gsub(/[[:space:]]$/, "", footnote_num)
            # Replace with [^n] and reattach any punctuation or newline
            $0 = substr($0, 1, RSTART-1) "[^" footnote_num "]" substr($0, RSTART + RLENGTH)
        }
        print
    }
')

# printf "%s\n" "$FOOTNOTE_EXTRA_FIX_MARKDOWN"

