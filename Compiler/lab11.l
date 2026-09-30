%option noyywrap noinput nounput

%{
#include <stdio.h>
#include <stdlib.h>

enum {
    ID = 256,
    NUMBER,
    INVALID
};

static int look;
static int depth = 0;

static void expression(void);
static void term(void);
static void factor(void);

static void fail(const char *msg)
{
    fprintf(stderr, "Invalid expression: %s\n", msg);
    exit(EXIT_FAILURE);
}

static void advance(void)
{
    look = yylex();
}
%}

%%

[a-zA-Z_][a-zA-Z0-9_]*        { return ID; }

([0-9]+(\.[0-9]+)?|\.[0-9]+)  { return NUMBER; }

[+*/()-]                      { return (unsigned char)yytext[0]; }

[ \t\r\n]+                    { /* ignore whitespace */ }

.                             { return INVALID; }

%%

/*
    Grammar:

    E -> T R
    R -> + T R | - T R | epsilon

    T -> F S
    S -> * F S | / F S | epsilon

    F -> ( E ) | id | number

    R and S are implemented using loops instead
    of recursive calls, so long operator chains
    do not cause unnecessary recursion.
*/

/* ---------------------------------------------------------
   factor()
   F -> ( E ) | id | number
   --------------------------------------------------------- */

static void factor(void)
{
    if (look == ID || look == NUMBER) {
        advance();
        return;
    }

    if (look == '(') {

        ++depth;

        if (depth > 256)
            fail("parenthesis nesting exceeds 256");

        advance();

        expression();

        if (look != ')')
            fail("expected ')'");

        --depth;

        advance();
        return;
    }

    if (look == INVALID)
        fail("invalid character");

    if (look == 0)
        fail("unexpected end of input");

    fail("expected identifier, number, or '('");
}

/* ---------------------------------------------------------
   term()
   T -> F S
   S -> * F S | / F S | epsilon
   --------------------------------------------------------- */

static void term(void)
{
    factor();

    while (look == '*' || look == '/') {

        advance();

        factor();
    }
}

/* ---------------------------------------------------------
   expression()
   E -> T R
   R -> + T R | - T R | epsilon
   --------------------------------------------------------- */

static void expression(void)
{
    term();

    while (look == '+' || look == '-') {

        advance();

        term();
    }
}

/* ---------------------------------------------------------
   main
   --------------------------------------------------------- */

int main(void)
{
    /*
       Read first token.
    */
    advance();

    /*
       Empty input is invalid.
    */
    if (look == 0)
        fail("empty expression");

    /*
       Parse according to E.
    */
    expression();

    /*
       The entire input must have been consumed.
    */
    if (look == INVALID)
        fail("invalid character after expression");

    if (look != 0)
        fail("unexpected trailing token");

    puts("Valid expression (recursive descent)");

    return EXIT_SUCCESS;
}
