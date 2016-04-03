#!/bin/bash

tmp="tmp.$$"
for f in "$@"
do
    echo "auto-cropping $f"
    convert $f -bordercolor white -border 1x1 \
	-trim +repage $tmp.${f#*.}
    mv $tmp.${f#*.} $f
done
