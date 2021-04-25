PROGRAM        = logic
ALGOLW_SOURCES = logic.alw
C_SOURCES      = argv.c
EXTRA_FILES    = expected.output README logic68.a68 logicpas.pas tests.sh

test : clean logic
	sh tests.sh ./logic
	./logic '~a \/ b, a -> b' > actual.output
	diff expected.output actual.output

# an additional cleaning rule:
clean ::
	rm -f actual.output logicpas logicpas.o logic68 logic68.c logic68.o

# Bonus Algol 68 program! You need Algol 68RS to compile this.
logic68: logic68.a68
	ca -u AAAAAAA logic68.a68
	sh tests.sh ./logic68
	./logic68 '~a \/ b, a -> b' > actual.output
	diff expected.output actual.output

# Bonus Pascal program! You need Free Pascal to compile this.
logicpas: logicpas.pas
	fpc logicpas.pas
	sh tests.sh ./logicpas
	./logicpas '~a \/ b, a -> b' > actual.output
	diff expected.output actual.output

include awe.mk
