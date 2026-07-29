%{
#include<stdio.h>

int vowels=0, consonants=0, words=0, numbers=0;
%}

%%

[A-Za-z]+ {
    int i;
    words++;
    for(i=0; yytext[i]!='\0'; i++)
    {
        switch(yytext[i])
        {
            case 'a': case 'e': case 'i': case 'o': case 'u':
            case 'A': case 'E': case 'I': case 'O': case 'U':
                vowels++;
                break;
            default:
                consonants++;
        }
    }
}

[0-9]+    { numbers++; }

[ \t\n]   ;

.         ;

%%

int yywrap()
{
    return 1;
}

int main()
{
    printf("Enter text:\n");
    yylex();

    printf("\nWords = %d", words);
    printf("\nVowels = %d", vowels);
    printf("\nConsonants = %d", consonants);
    printf("\nNumbers = %d\n", numbers);

    return 0;
}