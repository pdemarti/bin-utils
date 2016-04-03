#!/bin/bash

tmp="tmp.$$"
for f in "$@"
do
    echo "replacing transparency by white in $f"
    convert $f -background white -flatten $tmp.${f#*.}
    mv $tmp.${f#*.} $f
done
