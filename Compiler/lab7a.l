%option noyywrap nodefault

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAX_STATES 200
#define MAX_SYMBOLS 50
#define MAX_STACK 500
#define MAX_DFA_STATES 500
#define MAX_REGEX 500

typedef struct {
    int transition[MAX_SYMBOLS][MAX_STATES];
    int transitionCount[MAX_SYMBOLS];
    int epsilon[MAX_STATES];
    int epsilonCount;
} NFAState;

typedef struct {
    int start;
    int accept;
} Fragment;

typedef struct {
    int states[MAX_STATES];
    int count;
} StateSet;

NFAState nfa[MAX_STATES];
int nfaCount = 0;

char regexText[MAX_REGEX];
int regexLength = 0;
int processed = 0;

char alphabet[MAX_SYMBOLS];
int alphabetCount = 0;

int isSymbol(char c)
{
    return isalnum((unsigned char)c);
}

int precedence(char op)
{
    if(op == '|')
        return 1;

    if(op == '.')
        return 2;

    return 0;
}

void addAlphabet(char c)
{
    int i;

    for(i = 0; i < alphabetCount; i++)
    {
        if(alphabet[i] == c)
            return;
    }

    if(alphabetCount < MAX_SYMBOLS)
        alphabet[alphabetCount++] = c;
}

int insertConcatenation(char *re,char *result)
{
    int i,j = 0;
    char left,right;

    for(i = 0; re[i] != '\0'; i++)
    {
        left = re[i];
        result[j++] = left;

        if(re[i + 1] == '\0')
            break;

        right = re[i + 1];

        if((isSymbol(left) || left == ')' ||
            left == '*' || left == '+' || left == '?') &&
           (isSymbol(right) || right == '('))
        {
            result[j++] = '.';
        }
    }

    result[j] = '\0';

    return j;
}

int toPostfix(char *re,char *postfix)
{
    char infix[MAX_REGEX];
    char operators[MAX_STACK];
    int top = -1;
    int i,j = 0;
    char c;

    insertConcatenation(re,infix);

    for(i = 0; infix[i] != '\0'; i++)
    {
        c = infix[i];

        if(isSymbol(c))
        {
            postfix[j++] = c;
        }
        else if(c == '(')
        {
            operators[++top] = c;
        }
        else if(c == ')')
        {
            while(top >= 0 && operators[top] != '(')
            {
                postfix[j++] = operators[top--];
            }

            if(top < 0)
            {
                printf("Error: Unmatched parenthesis\n");
                return 0;
            }

            top--;
        }
        else if(c == '*' || c == '+' || c == '?')
        {
            postfix[j++] = c;
        }
        else if(c == '|' || c == '.')
        {
            while(top >= 0 &&
                  operators[top] != '(' &&
                  precedence(operators[top]) >= precedence(c))
            {
                postfix[j++] = operators[top--];
            }

            operators[++top] = c;
        }
        else
        {
            printf("Error: Unsupported symbol: %c\n",c);
            return 0;
        }
    }

    while(top >= 0)
    {
        if(operators[top] == '(')
        {
            printf("Error: Unmatched parenthesis\n");
            return 0;
        }

        postfix[j++] = operators[top--];
    }

    postfix[j] = '\0';

    return 1;
}

int addState()
{
    int i,j;

    if(nfaCount >= MAX_STATES)
    {
        printf("Error: Too many NFA states\n");
        exit(1);
    }

    i = nfaCount++;

    for(j = 0; j < MAX_SYMBOLS; j++)
    {
        nfa[i].transitionCount[j] = 0;
    }

    nfa[i].epsilonCount = 0;

    return i;
}

void addTransition(int from,char symbol,int to)
{
    int index;

    for(index = 0; index < alphabetCount; index++)
    {
        if(alphabet[index] == symbol)
            break;
    }

    if(index == alphabetCount)
    {
        addAlphabet(symbol);
        index = alphabetCount - 1;
    }

    nfa[from].transition[index]
        [nfa[from].transitionCount[index]++] = to;
}

void addEpsilon(int from,int to)
{
    if(nfa[from].epsilonCount < MAX_STATES)
    {
        nfa[from].epsilon[
            nfa[from].epsilonCount++] = to;
    }
}

Fragment buildNFA(char *postfix)
{
    Fragment stack[MAX_STACK];
    int top = -1;
    int i;
    char c;

    for(i = 0; postfix[i] != '\0'; i++)
    {
        c = postfix[i];

        if(isSymbol(c))
        {
            Fragment f;

            f.start = addState();
            f.accept = addState();

            addTransition(f.start,c,f.accept);

            stack[++top] = f;
        }
        else if(c == '.')
        {
            Fragment second,first,result;

            if(top < 1)
            {
                printf("Error: Invalid concatenation\n");
                exit(1);
            }

            second = stack[top--];
            first = stack[top--];

            addEpsilon(first.accept,second.start);

            result.start = first.start;
            result.accept = second.accept;

            stack[++top] = result;
        }
        else if(c == '|')
        {
            Fragment second,first,result;

            if(top < 1)
            {
                printf("Error: Invalid union\n");
                exit(1);
            }

            second = stack[top--];
            first = stack[top--];

            result.start = addState();
            result.accept = addState();

            addEpsilon(result.start,first.start);
            addEpsilon(result.start,second.start);

            addEpsilon(first.accept,result.accept);
            addEpsilon(second.accept,result.accept);

            stack[++top] = result;
        }
        else if(c == '*')
        {
            Fragment old,result;

            if(top < 0)
            {
                printf("Error: Invalid Kleene star\n");
                exit(1);
            }

            old = stack[top--];

            result.start = addState();
            result.accept = addState();

            addEpsilon(result.start,old.start);
            addEpsilon(result.start,result.accept);

            addEpsilon(old.accept,old.start);
            addEpsilon(old.accept,result.accept);

            stack[++top] = result;
        }
        else if(c == '+')
        {
            Fragment old,result;

            if(top < 0)
            {
                printf("Error: Invalid plus closure\n");
                exit(1);
            }

            old = stack[top--];

            result.start = addState();
            result.accept = addState();

            addEpsilon(result.start,old.start);

            addEpsilon(old.accept,old.start);
            addEpsilon(old.accept,result.accept);

            stack[++top] = result;
        }
        else if(c == '?')
        {
            Fragment old,result;

            if(top < 0)
            {
                printf("Error: Invalid optional operator\n");
                exit(1);
            }

            old = stack[top--];

            result.start = addState();
            result.accept = addState();

            addEpsilon(result.start,old.start);
            addEpsilon(result.start,result.accept);

            addEpsilon(old.accept,result.accept);

            stack[++top] = result;
        }
    }

    if(top != 0)
    {
        printf("Error: Malformed regular expression\n");
        exit(1);
    }

    return stack[0];
}

int contains(StateSet *set,int state)
{
    int i;

    for(i = 0; i < set->count; i++)
    {
        if(set->states[i] == state)
            return 1;
    }

    return 0;
}

void epsilonClosure(StateSet *input,StateSet *output)
{
    int stack[MAX_STATES];
    int top = -1;
    int i,current,next;

    output->count = 0;

    for(i = 0; i < input->count; i++)
    {
        if(!contains(output,input->states[i]))
        {
            output->states[output->count++] = input->states[i];
            stack[++top] = input->states[i];
        }
    }

    while(top >= 0)
    {
        current = stack[top--];

        for(i = 0; i < nfa[current].epsilonCount; i++)
        {
            next = nfa[current].epsilon[i];

            if(!contains(output,next))
            {
                output->states[output->count++] = next;
                stack[++top] = next;
            }
        }
    }

    /* Sort state set */
    for(i = 0; i < output->count - 1; i++)
    {
        int j;

        for(j = i + 1; j < output->count; j++)
        {
            if(output->states[i] > output->states[j])
            {
                int temp = output->states[i];
                output->states[i] = output->states[j];
                output->states[j] = temp;
            }
        }
    }
}

void moveAndClose(StateSet *states,char symbol,StateSet *result)
{
    StateSet moved;
    StateSet closed;
    int i,j,index;

    moved.count = 0;

    for(i = 0; i < states->count; i++)
    {
        int state = states->states[i];

        index = -1;

        for(j = 0; j < alphabetCount; j++)
        {
            if(alphabet[j] == symbol)
            {
                index = j;
                break;
            }
        }

        if(index >= 0)
        {
            for(j = 0;
                 j < nfa[state].transitionCount[index];
                 j++)
            {
                int next =
                    nfa[state].transition[index][j];

                if(!contains(&moved,next))
                {
                    moved.states[moved.count++] = next;
                }
            }
        }
    }

    epsilonClosure(&moved,&closed);

    *result = closed;
}

int sameStateSet(StateSet *a,StateSet *b)
{
    int i;

    if(a->count != b->count)
        return 0;

    for(i = 0; i < a->count; i++)
    {
        if(a->states[i] != b->states[i])
            return 0;
    }

    return 1;
}

int findStateSet(StateSet dfaStates[],int count,StateSet *target)
{
    int i;

    for(i = 0; i < count; i++)
    {
        if(sameStateSet(&dfaStates[i],target))
            return i;
    }

    return -1;
}

void printStateSet(StateSet *set)
{
    int i;

    printf("{");

    for(i = 0; i < set->count; i++)
    {
        if(i != 0)
            printf(",");

        printf("%d",set->states[i]);
    }

    printf("}");
}

int convertRegexToDFA(char *re)
{
    char postfix[MAX_REGEX];

    StateSet dfaStates[MAX_DFA_STATES];
    int transition[MAX_DFA_STATES][MAX_SYMBOLS];

    Fragment complete;

    int dfaCount = 0;
    int queue[MAX_DFA_STATES];
    int front = 0;
    int rear = 0;

    int i,j;

    if(!toPostfix(re,postfix))
        return 0;

    nfaCount = 0;
    alphabetCount = 0;

    complete = buildNFA(postfix);

    StateSet startSet;
    StateSet temp;

    startSet.count = 1;
    startSet.states[0] = complete.start;

    epsilonClosure(&startSet,&temp);
    startSet = temp;

    dfaStates[0] = startSet;

    for(j = 0; j < MAX_SYMBOLS; j++)
        transition[0][j] = -1;

    dfaCount = 1;

    queue[rear++] = 0;

    while(front < rear)
    {
        int current = queue[front++];

        for(j = 0; j < alphabetCount; j++)
        {
            StateSet next;

            moveAndClose(
                &dfaStates[current],
                alphabet[j],
                &next
            );

            if(next.count == 0)
            {
                transition[current][j] = -1;
                continue;
            }

            int existing =
                findStateSet(
                    dfaStates,
                    dfaCount,
                    &next
                );

            if(existing == -1)
            {
                if(dfaCount >= MAX_DFA_STATES)
                {
                    printf("Error: Too many DFA states\n");
                    return 0;
                }

                existing = dfaCount;

                dfaStates[dfaCount] = next;

                for(i = 0; i < MAX_SYMBOLS; i++)
                    transition[dfaCount][i] = -1;

                dfaCount++;

                queue[rear++] = existing;
            }

            transition[current][j] = existing;
        }
    }

    printf("\nPostfix expression: %s\n",postfix);

    printf("DFA start state: D0\n");

    printf("DFA final state(s): ");

    for(i = 0; i < dfaCount; i++)
    {
        if(contains(
            &dfaStates[i],
            complete.accept))
        {
            printf("D%d ",i);
        }
    }

    printf("\n\nDFA state subsets:\n");

    for(i = 0; i < dfaCount; i++)
    {
        printf("D%d = ",i);
        printStateSet(&dfaStates[i]);
        printf("\n");
    }

    printf("\nTransition table\n");

    printf("State");

    for(i = 0; i < alphabetCount; i++)
        printf("\t%c",alphabet[i]);

    printf("\n");

    for(i = 0; i < dfaCount; i++)
    {
        printf("D%d",i);

        for(j = 0; j < alphabetCount; j++)
        {
            if(transition[i][j] == -1)
                printf("\t-");
            else
                printf("\tD%d",transition[i][j]);
        }

        printf("\n");
    }

    return 1;
}

%}

%%

[a-zA-Z0-9|*+?()] {
    if(regexLength < MAX_REGEX - 1)
    {
        regexText[regexLength++] = yytext[0];
        regexText[regexLength] = '\0';
    }
}

[ \t\r]+ {
    /* Ignore spaces */
}

\n {
    if(regexLength == 0)
    {
        printf("Error: empty regular expression\n");
        return 1;
    }

    processed = 1;

    return convertRegexToDFA(regexText) ? 0 : 1;
}

. {
    printf("Invalid character in RE: %s\n",yytext);
    return 1;
}

<<EOF>> {
    if(!processed && regexLength > 0)
        return convertRegexToDFA(regexText) ? 0 : 1;

    return 0;
}

%%

int main()
{
    printf("Enter regular expression: ");
    return yylex();
}