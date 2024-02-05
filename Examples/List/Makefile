PROGRAM        = list
ALGOLW_SOURCES = BEGIN argv.alw io.alw list.alw END
C_SOURCES      = argv-library.c io-library.c
C_INCLUDES     = 
EXTRA_FILES    = README test?.txt expected.output

include awe.mk

test : clean build
	./list test1.txt test2.txt test3.txt test4.txt > actual.output
	diff --strip-trailing-cr expected.output actual.output
	rm actual.output
	echo "Success!"
