#!/bin/bash
# Sequential tape processing with crash recovery
# Drag file or folder support + automatic tape numbering

OUTPUT_DIR="PREDATOR_OUTPUT"
LOG_FILE="PREDATOR_LOG.txt"
PREVIEW_TIME=10
ANALYZE_TIME=8
PRESET="slow"

mkdir -p "$OUTPUT_DIR"
touch "$LOG_FILE"

#############################################
# PATH NORMALIZATION
#############################################

normalize_path () {
    local INPUT="$1"
    INPUT="${INPUT%\"}"
    INPUT="${INPUT#\"}"
    INPUT="${INPUT/#\~/$HOME}"
    echo "$INPUT"
}

#############################################
# CRASH RECOVERY LOGGING
#############################################

mark_started () { echo "STARTED|$1" >> "$LOG_FILE"; }
mark_done () { echo "DONE|$1" >> "$LOG_FILE"; }
already_done () { grep -q "^DONE|$1$" "$LOG_FILE"; }

#############################################
# TAPE NUMBERING
#############################################

get_next_tape_number () {

    LAST=$(ls "$OUTPUT_DIR"/Tape_* 2>/dev/null \
        | sed -E 's/.*Tape_([0-9]+).*/\1/' \
        | sort -n | tail -1)

    if [[ -z "$LAST" ]]; then
        TAPE_COUNTER=1
    else
        TAPE_COUNTER=$((LAST + 1))
    fi
}

get_next_tape_number

#############################################
# COLLECT VIDEOS FROM FOLDER
#############################################

collect_from_folder () {

    local DIR="$1"
    FILE_LIST=()

    echo "[📂] Reading directory:"
    echo "$DIR"

    while IFS= read -r f; do
        FILE_LIST+=("$f")
    done < <(find "$DIR" -type f \
        \( -iname "*.mov" -o -iname "*.mp4" \
           -o -iname "*.avi" -o -iname "*.mkv" \) | sort)
}

#############################################
# SMART ANALYSIS
#############################################

analyze_video () {

    local FILE="$1"

    echo "[🧠] Analyzing $(basename "$FILE")..."

    RESULT=$(ffmpeg -hide_banner -i "$FILE" \
        -t $ANALYZE_TIME \
        -vf "signalstats,metadata=print:file=-" \
        -f null - 2>&1)

    NOISE=$(echo "$RESULT" | grep -o "YDIF=[0-9.]*" | cut -d= -f2 \
        | awk '{s+=$1;n++} END{if(n)print s/n; else print 0}')

    if awk "BEGIN {exit !($NOISE > 8)}"; then
        echo "👉 Suggested encoder: CPU (better for noisy tapes)"
    else
        echo "👉 Suggested encoder: VideoToolbox (fast)"
    fi
}

#############################################
# PREVIEW GENERATION
#############################################

make_preview () {

    local FILE="$1"
    local FIELD="$2"
    local PARITY_VAL=1
    [[ "$FIELD" == "tff" ]] && PARITY_VAL=0

    NAME_ONLY="$(basename "${FILE%.*}")"

    ffmpeg -hide_banner -loglevel error \
        -i "$FILE" -t $PREVIEW_TIME \
        -vf "bwdif=mode=1:parity=$PARITY_VAL:deint=0" \
        -c:v hevc_videotoolbox -b:v 10M -tag:v hvc1 \
        -c:a aac -b:a 192k \
        -y "$OUTPUT_DIR/${NAME_ONLY}_${FIELD}_PREVIEW.mp4"
}

#############################################
# FULL ENCODING
#############################################

process_full () {

    local FILE="$1"
    local FIELD="$2"
    local PARITY_VAL=1
    [[ "$FIELD" == "tff" ]] && PARITY_VAL=0

    printf -v TAPE_NAME "Tape_%03d" "$TAPE_COUNTER"

    mark_started "$FILE"

    echo "[🚀] Encoding → $TAPE_NAME"

    if [[ "$ENCODER" == "cpu" ]]; then

        ffmpeg -hide_banner \
            -i "$FILE" \
            -vf "bwdif=mode=1:parity=$PARITY_VAL:deint=0" \
            -c:v libx265 -preset $PRESET -crf $CRF \
            -tag:v hvc1 \
            -c:a aac -b:a 192k \
            -y "$OUTPUT_DIR/${TAPE_NAME}_CPU_HEVC.mp4"

    else

        ffmpeg -hide_banner \
            -i "$FILE" \
            -vf "bwdif=mode=1:parity=$PARITY_VAL:deint=0" \
            -c:v hevc_videotoolbox -b:v "$BITRATE" \
            -tag:v hvc1 \
            -c:a aac -b:a 192k \
            -y "$OUTPUT_DIR/${TAPE_NAME}_VT_HEVC.mp4"
    fi

    if [[ $? -eq 0 ]]; then
        mark_done "$FILE"
        ((TAPE_COUNTER++))
        echo "[✅] Finished $TAPE_NAME"
    else
        echo "[❌] Encoding failed"
    fi
}

#############################################
# INPUT MENU
#############################################

echo "Select input mode:"
echo "1) Drag ONE video"
echo "2) Drag a FOLDER (sequential processing)"
echo "3) Process videos in current directory"
read -rp "Choice: " INPUT_MODE

if [[ "$INPUT_MODE" == "1" ]]; then

    echo "👉 Drag video and press ENTER:"
    read FILE_INPUT
    FILE_INPUT=$(normalize_path "$FILE_INPUT")
    FILE_LIST=("$FILE_INPUT")

elif [[ "$INPUT_MODE" == "2" ]]; then

    echo "👉 Drag folder and press ENTER:"
    read FOLDER_INPUT
    FOLDER_INPUT=$(normalize_path "$FOLDER_INPUT")
    collect_from_folder "$FOLDER_INPUT"

else
    collect_from_folder "."
fi

#############################################
# MAIN SEQUENTIAL LOOP
#############################################

for FILE in "${FILE_LIST[@]}"; do

    already_done "$FILE" && {
        echo "[⏭️] Skipping completed: $FILE"
        continue
    }

    echo "[📼] Processing: $(basename "$FILE")"

    analyze_video "$FILE"

    echo "Choose encoder:"
    echo "1) CPU (x265)"
    echo "2) VideoToolbox"
    read -rp "Choice: " MODE

    if [[ "$MODE" == "1" ]]; then
        ENCODER="cpu"
        read -rp "CRF (18–24 recommended): " CRF
    else
        ENCODER="vt"
        read -rp "Bitrate (example 12M): " BITRATE
    fi

    make_preview "$FILE" "bff"
    make_preview "$FILE" "tff"

    NAME_ONLY="$(basename "${FILE%.*}")"

    open "$OUTPUT_DIR/${NAME_ONLY}_bff_PREVIEW.mp4"
    sleep 1
    open "$OUTPUT_DIR/${NAME_ONLY}_tff_PREVIEW.mp4"

    read -rp "Correct field order? (bff/tff/skip): " CHOICE

    [[ "$CHOICE" == "bff" || "$CHOICE" == "tff" ]] && \
        process_full "$FILE" "$CHOICE"

    rm -f "$OUTPUT_DIR/${NAME_ONLY}_"*_PREVIEW.mp4

done

echo "[🏆] ALL TASKS COMPLETE"
