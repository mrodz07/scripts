#!/bin/bash

FFMPEG_OUTPUT_FILE="/tmp/ffmpeg_output.txt"

function format_time() {
	local time=${1}
	local format=${2}

	case "$format" in
	"hours")
		echo "$time/3600" | bc 2>/dev/null
		;;
	"minutes")
		echo "$time/60" | bc 2>/dev/null
		;;
	"seconds")
		echo "$time%60" | bc 2>/dev/null
		;;
	*)
		echo "Time format not supported"
		exit 1
		;;
	esac
}

function encode_video() {
	local file=${1}
	local new_file=${2}
	local quality=${3}

	if [ -z "$file" ]; then
		echo "Empty filename not supported" 1>&2
		return 1
	fi

	if [ ! -f "$file" ]; then
		echo "$file: doesn't exist" 1>&2
		return 1
	fi

	if [ -z "$quality" ]; then quality=25; fi

	if [[ $file == *x265* ]]; then
		echo "Already encoded: $file" 1>&2
		return 1
	fi

	if [[ $file == *.mp4 ]] || [[ $file == *.mkv ]] || [[ $file == *.webm ]]; then
		echo "Encoding file: $file to $new_file"

		#-scodec copy \
		#-global_quality $quality \
		#-hwaccel vaapi \

		ffmpeg -vaapi_device /dev/dri/renderD128 \
			-y \
			-i "$file" \
			-f "matroska" \
			-vf 'format=nv12,hwupload' \
			-map 0 \
			-c:v hevc_vaapi \
			-rc_mode CQP \
			-global_quality $quality \
			-profile:v main \
			-progress - -nostats \
			-loglevel error \
			"$new_file" >$FFMPEG_OUTPUT_FILE &
	else
		echo "Type not supported for: $file" 1>&2
		return 1
	fi

	return 0
}

function encode_video_progress() {
	local file=${1}
	local pid=${2}
	local total_frames="$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$file")"

	while [ -e /proc/$pid ]; do
		local current_frame=$(cat $FFMPEG_OUTPUT_FILE |
			grep --text 'frame=' |
			tail -1 |
			sed 's/frame=//')

		local progress_percentage=$(echo "scale=2;$current_frame/$total_frames*100" | bc 2>/dev/null)
		local video_time=$(cat $FFMPEG_OUTPUT_FILE | grep --text 'out_time' | tail -1 | sed 's/out_time=//')

		printf "Progress: %%%s Video Time: %s\r" $progress_percentage $video_time
		sleep 0.1
	done

	tput rc
	tput ed
	echo -e "Progress: %100 Video Time: $video_time"
}

function print_total_time() {
	local name=${1}
	local start_time=${2}
	local end_time=${3}
	local separators=${4}

	if [ -z "$separators" ]; then separators="\n\n"; fi

	local hours=$(format_time $(echo "($end_time-$start_time)" | bc) "hours")
	local minutes=$(format_time $(echo "($end_time-$start_time)" | bc) "minutes")
	local seconds=$(format_time $(echo "($end_time-$start_time)" | bc) "seconds")

	printf "Done $name in: %02dh:%02dm:%02ds$separators" $hours $minutes $seconds
}

TIME_START=$(date +%s)

for file in "$@"; do
	file_start_time=$(date +%s)
	tmp_file_name="/tmp/$file.tmp"
	final_file_name="$(echo "$file" | sed -E "s/\..{3,4}$/.x265.mkv/")"
	overwrite=0

	if [[ -e $final_file_name ]]; then
		echo "$file: has been encoded before to: $final_file_name"
		continue
	fi

	encode_video "$file" "$tmp_file_name" "19"

	if [[ $? != '0' ]]; then
		continue
	fi

	encode_video_progress "$file" "$!"

	echo "Moving $tmp_file_name to $final_file_name"
	mv "$tmp_file_name" "$final_file_name"

	if [[ $overwrite == "1" ]] && [[ "$file" != "$final_file_name" ]]; then
		echo "Removing $file"
		rm "$file"
	fi

	file_end_time=$(date +%s)

	print_total_time "$file" "$file_start_time" "$file_end_time"
done

TIME_END=$(date +%s)

print_total_time "all" "$TIME_START" "$TIME_END" "\n"
