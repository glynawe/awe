PROGRAM        = program
ALGOLW_SOURCES = program.alw
C_SOURCES      = io-library.c
OTHER_FILES    = expected.output

test : clean build
	./program > actual.output
	diff --strip-trailing-cr expected.output actual.output

clean::
	rm -f actual.output

include awe.mk
