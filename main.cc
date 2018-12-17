#include "heading.h"

int yyparse();

extern FILE* yyin;

int main(int argc, char **argv)
{
   if (argc > 1)
   {
      yyin = fopen(argv[1], "r");
      if (yyin == NULL)
      {
         printf("syntax: %s filename\n", argv[0]);
         exit(0);
      }
   }
   yyparse(); // Calls yylex() for tokens.
   return 0;
}
