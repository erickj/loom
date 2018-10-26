#!/bin/sh
find lib -name \*.rb | etags -l ruby --output=loom.TAGS -
