#!/bin/bash

read -p "Enter password, if any -> " pass

for file in $(ls | grep .rar); do
	unrar x $file -p"$pass"
done
