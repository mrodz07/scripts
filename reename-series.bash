#!/bin/bash
for file in "$@"; do
	if [ -f "$file" ]; then
		new_filename=$(echo "$file" |
			sed -E "s/(\s+|-+|\++)/\./g" |
			tr -s "." |
			sed -E "s/\.[a-z](!$)/\U/g" |
			sed -E "s/\d{1,2}x\d{1,2}//")
		echo "$new_filename"
	fi
done
