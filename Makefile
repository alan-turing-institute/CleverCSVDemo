# Makefile to create the iPython notebook
#
# Author: Gertjan van den Burg
# Date: 2019-05-01
# License: See LICENSE file.

NAME=CSV_dialect_detection_with_CleverCSV

.PHONY: all clean

all: $(NAME).ipynb

$(NAME).ipynb: $(NAME).md
	pweave -f notebook -o $@ $<

clean:
	rm -f $(NAME).ipynb
