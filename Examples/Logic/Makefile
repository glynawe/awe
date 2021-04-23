PROGRAM        = logic
ALGOLW_SOURCES = logic.alw
C_SOURCES      = argv.c
OTHER_FILES    = expected.output README logic68.a68

test : clean logic
	./logic '~a \/ b, a -> b' > actual.output
	diff expected.output actual.output

# an additional cleaning rule:
clean ::
	rm -f actual.output logicpas logic68 logic68.c logic68.o

# Bonus Algol 68 program! You need algol68toc to compile this.
logic68: logic68.a68
	ca -u AAAAAAA logic68.a68

# Bonus Pascal program! You need Free Pascal to compile this.
logicpas: logicpas.pas
	fpc logicpas.pas

include awe.mk
