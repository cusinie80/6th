%option noyywrap noinput nounput

%{
#ifndef GRAMMAR_CORE_H
#define GRAMMAR_CORE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PROD 256
#define MAX_RHS  64
#define ASCII    128
#define EPSILON  0

enum {
    ARROW = 256,
    BAD_TOKEN
};

int yylex(void);

typedef struct {
    int lhs;
    char rhs[MAX_RHS];
} Production;

static Production prod[MAX_PROD];
static int np = 0;

static int start_symbol = -1;
static int defined[26];
static int used[26];
static int terminals[ASCII];

/*
 * FIRST:
 *   index 0 = epsilon
 *   index 1..127 = ASCII terminals
 *
 * FOLLOW:
 *   index 0 is never used
 *   index 1..127 = ASCII terminals
 */
static unsigned char first_set[26][ASCII];
static unsigned char follow_set[26][ASCII];

static void fail(const char *msg)
{
    fprintf(stderr, "Error: %s\n", msg);
    exit(EXIT_FAILURE);
}

static int is_nonterminal(int c)
{
    return c >= 'A' && c <= 'Z';
}

/* ------------------------------------------------------------
 * Production handling
 * ------------------------------------------------------------ */

static void add_production(int lhs, const char *rhs)
{
    int p;

    if (np >= MAX_PROD)
        fail("too many productions");

    /* Ignore exact duplicate productions. */
    for (p = 0; p < np; ++p) {
        if (prod[p].lhs == lhs && strcmp(prod[p].rhs, rhs) == 0)
            return;
    }

    prod[np].lhs = lhs;

    if (strlen(rhs) >= MAX_RHS)
        fail("RHS too long");

    strcpy(prod[np].rhs, rhs);
    ++np;
}

/* ------------------------------------------------------------
 * Read grammar
 *
 * Format:
 *
 *   S -> aA | #
 *   A -> bS | c
 *
 * Uppercase letters = nonterminals
 * Other printable ASCII characters = terminals
 * # = epsilon
 * $ = end marker, reserved and cannot occur in RHS
 * ------------------------------------------------------------ */

static void read_grammar(void)
{
    int t = yylex();

    while (t != 0) {

        if (t == '\n') {
            t = yylex();
            continue;
        }

        if (t == BAD_TOKEN)
            fail("invalid character");

        if (!is_nonterminal(t))
            fail("LHS must be one uppercase letter");

        {
            int lhs = t - 'A';

            defined[lhs] = 1;

            if (start_symbol < 0)
                start_symbol = lhs;

            t = yylex();

            if (t != ARROW)
                fail("expected -> after LHS");

            t = yylex();

            for (;;) {
                char rhs[MAX_RHS];
                int len = 0;
                int epsilon = 0;

                while (t != 0 && t != '\n' && t != '|') {

                    if (t == BAD_TOKEN)
                        fail("invalid character in RHS");

                    if (t == '#') {

                        if (len != 0 || epsilon)
                            fail("# must be the entire alternative");

                        epsilon = 1;

                    } else {

                        if (epsilon)
                            fail("epsilon (#) cannot be mixed with other symbols");

                        if (t < 33 || t >= ASCII || t == '$')
                            fail("invalid RHS symbol");

                        if (len >= MAX_RHS - 1)
                            fail("RHS too long");

                        rhs[len++] = (char)t;

                        if (is_nonterminal(t))
                            used[t - 'A'] = 1;
                        else
                            terminals[(unsigned char)t] = 1;
                    }

                    t = yylex();
                }

                if (len == 0 && !epsilon)
                    fail("empty alternative; use # for epsilon");

                rhs[len] = '\0';

                add_production(lhs, rhs);

                if (t != '|')
                    break;

                /* Read next alternative. */
                t = yylex();

                if (t == '\n' || t == 0)
                    fail("missing alternative after |");
            }

            if (t == '\n')
                t = yylex();
        }
    }

    if (np == 0)
        fail("empty grammar");

    /* Every referenced nonterminal must have a production. */
    for (int n = 0; n < 26; ++n) {
        if (used[n] && !defined[n]) {
            char msg[100];

            snprintf(
                msg,
                sizeof(msg),
                "nonterminal %c has no production",
                'A' + n
            );

            fail(msg);
        }
    }
}

/* ------------------------------------------------------------
 * Set operations
 * ------------------------------------------------------------ */

static int unite(
    unsigned char *dst,
    const unsigned char *src,
    int include_epsilon
)
{
    int changed = 0;
    int begin = include_epsilon ? EPSILON : 1;

    for (int c = begin; c < ASCII; ++c) {
        if (src[c] && !dst[c]) {
            dst[c] = 1;
            changed = 1;
        }
    }

    return changed;
}

/* ------------------------------------------------------------
 * FIRST of a string
 *
 * Example:
 *
 * FIRST(ABC)
 *
 * If A -> epsilon, then FIRST(B) is considered, etc.
 *
 * Empty string has FIRST = epsilon.
 * ------------------------------------------------------------ */

static void first_of_string(
    const char *s,
    unsigned char result[ASCII]
)
{
    memset(result, 0, ASCII);

    /* FIRST(empty) = epsilon */
    if (s[0] == '\0') {
        result[EPSILON] = 1;
        return;
    }

    for (int i = 0; s[i] != '\0'; ++i) {

        int c = (unsigned char)s[i];

        if (!is_nonterminal(c)) {
            result[c] = 1;
            return;
        }

        /*
         * Add FIRST(nonterminal) except epsilon.
         */
        unite(
            result,
            first_set[c - 'A'],
            0
        );

        /*
         * If this nonterminal cannot derive epsilon,
         * the rest of the string is irrelevant.
         */
        if (!first_set[c - 'A'][EPSILON])
            return;
    }

    /*
     * Every symbol in the string can derive epsilon.
     */
    result[EPSILON] = 1;
}

/* ------------------------------------------------------------
 * FIRST sets
 * ------------------------------------------------------------ */

static void compute_first_sets(void)
{
    int changed;

    do {
        changed = 0;

        for (int p = 0; p < np; ++p) {

            unsigned char first_rhs[ASCII];

            first_of_string(
                prod[p].rhs,
                first_rhs
            );

            changed |= unite(
                first_set[prod[p].lhs],
                first_rhs,
                1
            );
        }

    } while (changed);
}

/* ------------------------------------------------------------
 * FOLLOW sets
 * ------------------------------------------------------------ */

static void compute_follow_sets(void)
{
    int changed;

    /*
     * End marker belongs to FOLLOW(start symbol).
     */
    follow_set[start_symbol]['$'] = 1;

    do {
        changed = 0;

        for (int p = 0; p < np; ++p) {

            int lhs = prod[p].lhs;
            const char *rhs = prod[p].rhs;

            for (int i = 0; rhs[i] != '\0'; ++i) {

                int c = (unsigned char)rhs[i];

                if (!is_nonterminal(c))
                    continue;

                int n = c - 'A';

                /*
                 * FIRST(beta), where beta is everything
                 * after this nonterminal.
                 */
                unsigned char suffix_first[ASCII];

                first_of_string(
                    rhs + i + 1,
                    suffix_first
                );

                /*
                 * Add FIRST(beta) - epsilon
                 * to FOLLOW(B).
                 */
                changed |= unite(
                    follow_set[n],
                    suffix_first,
                    0
                );

                /*
                 * If beta can derive epsilon, add
                 * FOLLOW(A) to FOLLOW(B).
                 */
                if (suffix_first[EPSILON]) {

                    changed |= unite(
                        follow_set[n],
                        follow_set[lhs],
                        0
                    );
                }
            }
        }

    } while (changed);
}

/* ------------------------------------------------------------
 * Compute both FIRST and FOLLOW
 * ------------------------------------------------------------ */

static void compute_sets(void)
{
    compute_first_sets();
    compute_follow_sets();
}

/* ------------------------------------------------------------
 * Printing
 * ------------------------------------------------------------ */

static void print_set(const unsigned char *set)
{
    printf("{ ");

    for (int c = 0; c < ASCII; ++c) {

        if (set[c]) {

            if (c == EPSILON)
                printf("# ");
            else
                printf("%c ", c);
        }
    }

    printf("}");
}

static void print_production(int p)
{
    printf(
        "%c->%s",
        'A' + prod[p].lhs,
        prod[p].rhs[0] ? prod[p].rhs : "#"
    );
}

static void print_sets(void)
{
    printf(
        "Start symbol: %c\n\n",
        'A' + start_symbol
    );

    for (int n = 0; n < 26; ++n) {

        if (!defined[n])
            continue;

        printf(
            "FIRST(%c) = ",
            'A' + n
        );

        print_set(first_set[n]);

        printf("\n");

        printf(
            "FOLLOW(%c) = ",
            'A' + n
        );

        print_set(follow_set[n]);

        printf("\n\n");
    }
}

/* ------------------------------------------------------------
 * Predictive parsing table
 * ------------------------------------------------------------ */

static int table[26][ASCII][MAX_PROD];
static int count[26][ASCII];

static void table_add(int n, int c, int p)
{
    for (int i = 0; i < count[n][c]; ++i) {

        if (table[n][c][i] == p)
            return;
    }

    if (count[n][c] >= MAX_PROD)
        fail("too many productions in one parsing-table cell");

    table[n][c][count[n][c]++] = p;
}

static void build_table(void)
{
    /*
     * Fill predictive parsing table.
     */
    for (int p = 0; p < np; ++p) {

        unsigned char first_rhs[ASCII];
        int n = prod[p].lhs;

        first_of_string(
            prod[p].rhs,
            first_rhs
        );

        /*
         * FIRST(alpha)
         */
        for (int c = 1; c < ASCII; ++c) {

            if (first_rhs[c])
                table_add(n, c, p);
        }

        /*
         * If epsilon is in FIRST(alpha),
         * use FOLLOW(A).
         */
        if (first_rhs[EPSILON]) {

            for (int c = 1; c < ASCII; ++c) {

                if (follow_set[n][c])
                    table_add(n, c, p);
            }
        }
    }

    puts("Productions:");

    for (int p = 0; p < np; ++p) {

        printf("P%d: ", p + 1);
        print_production(p);
        putchar('\n');
    }

    puts("");
    puts(
        "Predictive parsing table "
        "(terminals + end marker $):"
    );

    int conflicts = 0;

    for (int n = 0; n < 26; ++n) {

        if (!defined[n])
            continue;

        for (int c = 1; c < ASCII; ++c) {

            /*
             * Only print actual grammar terminals
             * and the end marker.
             */
            if (!terminals[c] && c != '$')
                continue;

            printf(
                "M[%c,%c] = ",
                'A' + n,
                c
            );

            if (count[n][c] == 0) {

                printf("error");

            } else {

                for (int i = 0; i < count[n][c]; ++i) {

                    if (i)
                        printf(" / ");

                    print_production(
                        table[n][c][i]
                    );
                }

                if (count[n][c] > 1) {
                    printf("  CONFLICT");
                    ++conflicts;
                }
            }

            putchar('\n');
        }
    }

    /*
     * Check productivity.
     */
    int productive[26] = {0};
    int changed;

    do {
        changed = 0;

        for (int p = 0; p < np; ++p) {

            int ok = 1;

            for (int i = 0; prod[p].rhs[i]; ++i) {

                int c =
                    (unsigned char)prod[p].rhs[i];

                if (is_nonterminal(c) &&
                    !productive[c - 'A']) {

                    ok = 0;
                    break;
                }
            }

            if (ok &&
                !productive[prod[p].lhs]) {

                productive[prod[p].lhs] = 1;
                changed = 1;
            }
        }

    } while (changed);

    int nonproductive = 0;

    for (int n = 0; n < 26; ++n) {

        if (defined[n] && !productive[n]) {

            printf(
                "Nonproductive nonterminal: %c\n",
                'A' + n
            );

            nonproductive = 1;
        }
    }

    putchar('\n');

    if (conflicts) {

        puts(
            "Grammar is NOT LL(1): "
            "table conflicts exist."
        );

    } else if (nonproductive) {

        puts(
            "No table conflicts, but grammar is "
            "nonproductive."
        );

    } else {

        puts("Grammar is LL(1).");
    }
}

/* ------------------------------------------------------------
 * Main
 * ------------------------------------------------------------ */

int main(void)
{
    read_grammar();

    compute_sets();

    print_sets();

    build_table();

    return EXIT_SUCCESS;
}

#endif
%}

/* ------------------------------------------------------------
 * Lexer
 * ------------------------------------------------------------ */

%%
"->"          { return ARROW; }

[ \t\r]+      { /* ignore whitespace */ }

\n            { return '\n'; }

[\x21-\x7E]  { return (unsigned char)yytext[0]; }

.             { return BAD_TOKEN; }
%%
