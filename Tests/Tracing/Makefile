PROGRAM        = program
ALGOLW_SOURCES = program.alw
C_SOURCES      = tracing.c
OTHER_FILES    = expected.output
AWE_FLAGS      = -t

test : clean program
	./program 2> actual.output
	diff --strip-trailing-cr expected.output actual.output

clean ::
	rm -f actual.output

include awe.mk
