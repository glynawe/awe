PROGRAM        = program
ALGOLW_SOURCES = program.alw
C_SOURCES      = argv.c
OTHER_FILES    = expected.output

test : clean program
	./program Argument1 Arg2 'argument 3' > actual.output
	diff expected.output actual.output

# an additional cleaning rule:
clean ::
	rm -f actual.output

include awe.mk

