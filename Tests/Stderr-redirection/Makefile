PROGRAM        = program
ALGOLW_SOURCES = program.alw
OTHER_FILES    = expected-stdout.output expected-stderr.output

test : clean program
	./program  > actual-stdout.output 2> actual-stderr.output
	diff expected-stderr.output actual-stderr.output
	diff expected-stdout.output actual-stdout.output

# an additional cleaning rule:
clean ::
	rm -f actual-stdout.output actual-stderr.output

include awe.mk

