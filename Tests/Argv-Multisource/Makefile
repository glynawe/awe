PROGRAM        = program
ALGOLW_SOURCES = begin argv-headers.alw program.alw end
C_SOURCES      = argv.c
OTHER_FILES    = expected.output

test : clean build
	./program Argument1 Arg2 'argument 3' > actual.output
	diff --strip-trailing-cr expected.output actual.output

clean::
	rm -f actual.output

include awe.mk