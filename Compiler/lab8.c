#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

/*
    LAB 8: CFG FOR AN EXPRESSION LANGUAGE
    AND STRING VERIFICATION

    Grammar:

    E -> E + T | E - T | T
    T -> T * F | T / F | F
    F -> ( E ) | id | number

    Converted for recursive descent:

    E -> T R
    R -> + T R | - T R | epsilon

    T -> F S
    S -> * F S | / F S | epsilon

    F -> ( E ) | id | number
*/

#define MAX_INPUT 1000

/* Token types */
enum Token {
    TOK_END,
    TOK_ID,
    TOK_NUMBER,
    TOK_PLUS,
    TOK_MINUS,
    TOK_MUL,
    TOK_DIV,
    TOK_LPAREN,
    TOK_RPAREN,
    TOK_INVALID
};

static char input[MAX_INPUT];
static int position;
static int current_token;

/* --------------------------------------------------
   Error handling
   -------------------------------------------------- */

static void error_message(const char *message)
{
    printf("Invalid expression: %s\n", message);
    exit(0);
}

/* --------------------------------------------------
   Lexer
   -------------------------------------------------- */

static int get_token(void)
{
    char c;

    /* Skip spaces and tabs */
    while (input[position] == ' ' ||
           input[position] == '\t') {
        position++;
    }

    c = input[position];

    /* End of input */
    if (c == '\0' || c == '\n') {
        return TOK_END;
    }

    /* Identifier:
       [a-zA-Z_][a-zA-Z0-9_]*
    */
    if (isalpha((unsigned char)c) || c == '_') {

        position++;

        while (
            isalnum((unsigned char)input[position]) ||
            input[position] == '_'
        ) {
            position++;
        }

        return TOK_ID;
    }

    /* Number */

    if (isdigit((unsigned char)c) || c == '.') {

        int digits = 0;
        int dot = 0;

        /* Digits before decimal point */
        while (isdigit((unsigned char)input[position])) {
            digits = 1;
            position++;
        }

        /* Decimal point */
        if (input[position] == '.') {

            dot = 1;
            position++;

            /* Digits after decimal point */
            while (isdigit((unsigned char)input[position])) {
                digits = 1;
                position++;
            }
        }

        /*
           A '.' without any digits is invalid.
        */
        if (!digits) {
            return TOK_INVALID;
        }

        return TOK_NUMBER;
    }

    /* Operators and parentheses */

    position++;

    switch (c) {

        case '+':
            return TOK_PLUS;

        case '-':
            return TOK_MINUS;

        case '*':
            return TOK_MUL;

        case '/':
            return TOK_DIV;

        case '(':
            return TOK_LPAREN;

        case ')':
            return TOK_RPAREN;

        default:
            return TOK_INVALID;
    }
}

/* --------------------------------------------------
   Move to next token
   -------------------------------------------------- */

static void advance(void)
{
    current_token = get_token();
}

/* --------------------------------------------------
   Function declarations
   -------------------------------------------------- */

static void expression(void);
static void term(void);
static void factor(void);

/* --------------------------------------------------
   E -> T R
   R -> + T R | - T R | epsilon
   -------------------------------------------------- */

static void expression(void)
{
    term();

    while (current_token == TOK_PLUS ||
           current_token == TOK_MINUS) {

        advance();
        term();
    }
}

/* --------------------------------------------------
   T -> F S
   S -> * F S | / F S | epsilon
   -------------------------------------------------- */

static void term(void)
{
    factor();

    while (current_token == TOK_MUL ||
           current_token == TOK_DIV) {

        advance();
        factor();
    }
}

/* --------------------------------------------------
   F -> ( E ) | id | number
   -------------------------------------------------- */

static void factor(void)
{
    /* F -> id */
    if (current_token == TOK_ID) {
        advance();
        return;
    }

    /* F -> number */
    if (current_token == TOK_NUMBER) {
        advance();
        return;
    }

    /* F -> ( E ) */
    if (current_token == TOK_LPAREN) {

        advance();

        expression();

        if (current_token != TOK_RPAREN) {
            error_message("expected ')'");
        }

        advance();

        return;
    }

    if (current_token == TOK_INVALID) {
        error_message("invalid character");
    }

    if (current_token == TOK_END) {
        error_message("unexpected end of expression");
    }

    error_message(
        "expected identifier, number, or '('"
    );
}

/* --------------------------------------------------
   Main
   -------------------------------------------------- */

int main(void)
{
    printf("=====================================\n");
    printf(" LAB 8 - Expression Validator\n");
    printf("=====================================\n\n");

    printf("Grammar:\n");
    printf("E -> E + T | E - T | T\n");
    printf("T -> T * F | T / F | F\n");
    printf("F -> ( E ) | id | number\n\n");

    printf("Enter an expression: ");

    /*
       Read one complete expression.
    */
    if (fgets(input, MAX_INPUT, stdin) == NULL) {
        printf("No input.\n");
        return 1;
    }

    /* Remove newline */
    input[strcspn(input, "\n")] = '\0';

    /* Empty input */
    if (strlen(input) == 0) {
        printf("Invalid expression: empty input\n");
        return 1;
    }

    position = 0;

    /* Start lexical analysis */
    advance();

    /* Parse expression */
    expression();

    /*
       Everything must have been consumed.
    */
    if (current_token != TOK_END) {

        if (current_token == TOK_INVALID) {
            error_message("invalid character");
        }

        error_message("unexpected token");
    }

    printf("\nValid expression\n");

    return 0;
}
