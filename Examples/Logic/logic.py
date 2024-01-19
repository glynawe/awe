#!/bin/env python3
r""" logic.py -- toy program to interpret logic propositions

You can run it from the command line:

| $ python logic.py "A^~B v B^~A + ~C^B,  A v C,  A^(B v C)"
| 
|  A B C
|  0 0 0  0 0 0
|  0 0 1  0 1 0
|  0 1 0  1 0 0
|  0 1 1  1 1 0
|  1 0 0  1 1 0
|  1 0 1  1 1 1
|  1 1 0  1 1 1
|  1 1 1  0 1 1

The syntax for logic propositions, in order of binding strength:

                          Alternatives
    -----------  -------  ------------
    Constants:   0 1      T F
    Brackets:    ( )      [ ]  { }
    Not:         ¬a       ~ !
    And:         a ∧ b    /\  ^  .  &
    Or:          a ∨ b    \/  v  +  |
    Xor:         a ⊕ b    (+)  #
    Implication  a → b    ->
    Equivalence: a ↔ b    <->
    Mat. imp.:   a ⇒ b    =>
    Mat. equ.:   a ⇔ b    <=>
    
    Multiple results: a, b, c ...    
    
    Variables can be any letter.

The two useful Python functions in this module are 'table' and 'valid':

| >>> import logic
| >>> logic.table("(A ∧ ¬B) ∨ (B ∧ ¬A) ∨ (C ⊕ ¬B)")
| 
|  A B C
|  0 0 0  1
|  0 0 1  0
|  0 1 0  1
|  0 1 1  1
|  1 0 0  1
|  1 0 1  1
|  1 1 0  0
|  1 1 1  1
| 
| >>> logic.valid("x v y^z <=> (x v y)^(x v z)")
| True

Though the 'valuations' iterator could be pretty handy too:

| >>> for v in logic.valuations('AB'):
| ...     print v
| ... 
| {'A': False, 'B': False}
| {'A': False, 'B': True}
| {'A': True,  'B': False}
| {'A': True,  'B': True}

"""

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tests: the usual rules of logic.
# These are all validated before the program starts.

TESTS = r"""

A  ⇔  A
¬F  ⇔  T
¬T  ⇔  F

A ∨ A  ⇔  A   //Idempotence
A ∧ A  ⇔  A

A ∧ B ⇔ B ∧ A   //Commutati∨ity
A ∨ B ⇔ B ∨ A

A ∧ (B ∧ C)  ⇔  (A ∧ B) ∧ C   //Associati∨ity
A ∨ (B ∨ C)  ⇔  (A ∨ B) ∨ C

A ∧ (B ∨ C)  ⇔  A ∧ B ∨ A ∧ C     //Distributivity
A ∨ (B ∧ C)  ⇔  (A ∨ B) ∧ (A ∨ C)

¬(A ∧ B)  ⇔  ¬A ∨ ¬B      //De Morgan's Laws
¬(A ∨ B)  ⇔  ¬A ∧ ¬B

¬¬A  ⇔  A     //Double Negation

A ∧ ¬A  ⇔  F  //Excluded Middle
A ∨ ¬A  ⇔  T

A ∧ T  ⇔  A   //Identity
A ∨ F  ⇔  A       

A ∧ F  ⇔  F   //Domination
A ∨ T  ⇔  T   

A → B  ⇔  ¬A ∨ B     //Conditional

A ↔ B  ⇔ (A → B) ∧ (B → A)    //Bi-conditional

A ⊕ B  ⇔  A ∧ ¬B ∨ ¬A ∧ B   //Rule for ⊕


A ⊕ B  ⇔  ¬(A  ↔  B)  //Miscellaneous tests
A ↔ (B ↔ C)  ⇔  (A ↔ B) ↔ C
T → F  ⇔  F
A ∧ B ∨ C ⇔ (A ∧ B) ∨ C
A ∨ B ∧ C ⇔ A ∨ (B ∧ C)
A → B → C  ⇔  (A → B) → C
"""

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Lexer

alternative_symbols = [
    ('T', '1'),
    ('F', '0'),
    ('¬', '¬'),
    ('!', '¬'),
    ('~', '¬'),
    ('∧', '∧'),
    ('&', '∧'),
    ('^', '∧'),
    ('/\\', '∧'),
    ('∨', '∨'),
    ('+', '∨'),
    ('|', '∨'),
    ('v', '∨'),
    ('\\/', '∨'),
    ('⊕', '⊕'),
    ('#', '⊕'),
    ('(+)', '⊕'),
    ('→', '→'),
    ('->', '→'),
    ('↔', '↔'),
    ('<->', '↔'),
    ('⇒', '⇒'),
    ('=>', '⇒'),
    ('⇔', '⇔'),
    ('<=>', '⇔')
]

Input = ''
Pos = 0
Next = ''
SymbolStart = 0


def start(s):
    global Input, Next, Pos
    Input = s
    Pos = 0
    advance()


def advance():
    global Input, Next, Pos, SymbolStart
    while Pos < len(Input) and Input[Pos].isspace():
        Pos += 1
    if Pos >= len(Input):
        Next = None
    else:
        SymbolStart = Pos
        for a, b in alternative_symbols:
            if Input.startswith(a, Pos):
                Next = b
                Pos += len(a)
                return
        Next = Input[Pos]
        Pos += 1


def error():
    print(Input)
    print((' ' * (SymbolStart - 1)) + '^')
    raise SyntaxErr()


class SyntaxErr(ValueError):
    pass


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parser

# Recursive descent parser that translates proposition into a postfix
# form that uses the non-standard one-character versions of operators:
#
# >>> compile_proposition("(A ∧ ¬B) ∨ (B ∧ ¬A) ∨ (C ⊕ ¬B)")
# 'AB¬∧BA¬∧+CB¬⊕,'


binary_operators = '∧∨⊕→↔⇒⇔'  # in order of binding strength


def compile_proposition(proposition):
    """returns the proposition in postfix form"""
    start(proposition)
    program = binary(len(binary_operators)) + ','
    while Next == ',':
        advance()
        program += binary(len(binary_operators)) + ','
    if Next is None:
        return program
    else:
        error()


def binary(level):
    if level > 0:
        program = binary(level - 1)
        op = binary_operators[level - 1]
        while Next == op:
            advance()
            program += binary(level - 1) + op
        return program
    else:
        return unary()


def unary():
    n = Next
    advance()
    if n.isalpha():
        return n  # variable name
    elif n == "1":
        return '1'
    elif n == "0":
        return '0'
    elif n == "¬":
        return unary() + '¬'
    elif n == '(':
        return brackets(')')
    elif n == '[':
        return brackets(']')
    elif n == '{':
        return brackets('}')
    else:
        error()


def brackets(closing):
    program = binary(len(binary_operators))
    if Next == closing:
        advance()
    else:
        error()
    return program


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Stack machine to interpret postfix programs.
# It is an iterator that yields each result column of multi-column table:

def interpret(program, valuation):
    stack = []
    for c in program:
        if c == ',':
            yield stack.pop()
        else:
            if c == "1" or c == "T":
                stack.append(True)
            elif c == "0" or c == "F":
                stack.append(False)
            elif c == '¬':
                stack.append(not stack.pop())
            elif c.isalpha():
                stack.append(valuation[c])
            else:
                b = stack.pop()
                a = stack.pop()
                if c == '∨':
                    r = (a or b)
                elif c == '∧':
                    r = (a and b)
                elif c == '⊕':
                    r = (a != b)
                elif c == '↔' or c == "⇔":
                    r = (a == b)
                elif c == '→' or c == "⇒":
                    r = (a <= b)
                else:
                    assert False
                stack.append(r)


# Iterator that yields all valuations of a list of variables:

def valuations(variables):
    n = len(variables)
    for minterm in range(2 ** n):
        valuation = {}
        i = minterm
        for j in range(n - 1, -1, -1):
            v = variables[j]
            valuation[v] = (i & 1) == 1
            i >>= 1
        yield valuation


def table(proposition):
    print()
    variables = all_variables(proposition)
    program = compile_proposition(proposition)
    print(' ', end=' ')
    for x in variables:
        print(x, end=' ')
    print()
    for valuation in valuations(variables):
        print(' ', end=' ')
        for x in variables:
            print(int(valuation[x]), end=' ')
        print(' ', end='')
        for result in interpret(program, valuation):
            print(int(result), end=' ')
        print()
    print()


def valid(proposition):
    program = compile_proposition(proposition)
    variables = all_variables(proposition)
    for valuation in valuations(variables):
        for result in interpret(program, valuation):
            if not result:
                return False
    return True


def all_variables(proposition):
    v = []
    for c in proposition:
        if c.isalpha() and (c not in 'TFv') and (c not in v):
            v.append(c)
    return v


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def self_test():
    okay = True
    for proposition in TESTS.split('\n'):
        if '//' in proposition:
            proposition = proposition[:proposition.index('//')]
        if proposition.strip() != '':
            try:
                if not valid(proposition):
                    print('Fails', proposition)
                    okay = False
            except SyntaxError:
                print('Syntax error')
                okay = False
    import sys
    sys.exit(1)


self_test()

if __name__ == '__main__':
    import sys

    if len(sys.argv) > 1:
        table(sys.argv[1])

# end
