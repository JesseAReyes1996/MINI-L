/* cs152-fall18 */
  /* A flex scanner specification for the MINI-L language */

/*
Name: Jesse Reyes
SID: 861148238
*/

%{
  #include "heading.h"
  #include "tok.h"
  int currLine = 1, currPos = 1;
%}

/* REGULAR EXPRESSIONS */

digit    [0-9]
letter [a-zA-Z]
underscore [_]
number (\.{digit}+)|({digit}+(\.{digit}*)?([eE][+-]?{digit}+)?)
identifier {letter}({letter}|{digit}|({underscore}?({letter}|{digit})))*
consecutiveUnderscore {letter}({letter}|{digit}|({underscore}+({letter}|{digit})))*
beginDigit {digit}({letter}|{digit}|({underscore}?({letter}|{digit})))*
beginUnderscore {underscore}({letter}|{digit}|({underscore}?({letter}|{digit})))*
endUnderscore {letter}({letter}|{digit}|({underscore}?({letter}|{digit})))*{underscore}

%%

    /* TOKENS */

    /* RESERVED KEYWORDS */

"function"     {currPos += yyleng; return FUNCTION;}
"beginparams"  {currPos += yyleng; return BEGIN_PARAMS;}
"endparams"	   {currPos += yyleng; return END_PARAMS;}
"beginlocals"  {currPos += yyleng; return BEGIN_LOCALS;}
"endlocals"    {currPos += yyleng; return END_LOCALS;}
"beginbody"    {currPos += yyleng; return BEGIN_BODY;}
"endbody"	   {currPos += yyleng; return END_BODY;}
"integer"      {currPos += yyleng; return INTEGER;}
"array"		   {currPos += yyleng; return ARRAY;}
"of"		   {currPos += yyleng; return OF;}
"if"		   {currPos += yyleng; return IF;}
"then"		   {currPos += yyleng; return THEN;}
"endif"		   {currPos += yyleng; return ENDIF;}
"else"		   {currPos += yyleng; return ELSE;}
"while"		   {currPos += yyleng; return WHILE;}
"do"		   {currPos += yyleng; return DO;}
"beginloop"	   {currPos += yyleng; return BEGINLOOP;}
"endloop"	   {currPos += yyleng; return ENDLOOP;}
"continue"	   {currPos += yyleng; return CONTINUE;}
"read"		   {currPos += yyleng; return READ;}
"write"		   {currPos += yyleng; return WRITE;}
"and"		   {currPos += yyleng; return AND;}
"or"		   {currPos += yyleng; return OR;}
"not"		   {currPos += yyleng; return NOT;}
"true"		   {currPos += yyleng; return TRUE;}
"false"		   {currPos += yyleng; return FALSE;}
"return"	   {currPos += yyleng; return RETURN;}

    /* COMMENT */
"##"[^\n]*	   {;}

    /* OPERANDS */
"+"            {currPos += yyleng; return ADD;}
"-"            {currPos += yyleng; return SUB;}
"*"            {currPos += yyleng; return MULT;}
"/"            {currPos += yyleng; return DIV;}
"%"            {currPos += yyleng; return MOD;}

    /* COMPARISONS */
"=="		   {currPos += yyleng; return EQ;}
"<>"		   {currPos += yyleng; return NEQ;}
"<"			   {currPos += yyleng; return LT;}
">"			   {currPos += yyleng; return GT;}
"<="		   {currPos += yyleng; return LTE;}
">="		   {currPos += yyleng; return GTE;}

    /* PUNCTUATION */

";"            {currPos += yyleng; return SEMICOLON;}
":"            {currPos += yyleng; return COLON;}
","			   {currPos += yyleng; return COMMA;}
"("            {currPos += yyleng; return L_PAREN;}
")"            {currPos += yyleng; return R_PAREN;}
"["			   {currPos += yyleng; return L_SQUARE_BRACKET;}
"]"			   {currPos += yyleng; return R_SQUARE_BRACKET;}
":="           {currPos += yyleng; return ASSIGN;}

{number} {currPos += yyleng; yylval.dval=atof(yytext); return NUMBER;}

{beginDigit} {printf("Error at line %d, column %d: identifier \"%s\" must begin with a letter\n", currLine, currPos, yytext); exit(0);}

{beginUnderscore} {printf("Error at line %d, column %d: identifier \"%s\" must begin with a letter\n", currLine, currPos, yytext); exit(0);}

{endUnderscore} {printf("Error at line %d, column %d: identifier \"%s\" cannot end with an underscore\n", currLine, currPos, yytext); exit(0);}

{identifier} {currPos += yyleng; yylval.op_val=new std::string(yytext); return IDENT;}

{consecutiveUnderscore} {printf("Error at line %d, column %d: identifier \"%s\" cannot have consecutive underscores\n", currLine, currPos, yytext); exit(0);}

[\t]+         {/* ignore tabs */ currPos += yyleng;}

[" "]+       {/* ignore spaces*/ currPos += yyleng;}

"\n"           {currLine++; currPos = 1;}

.              {printf("Error at line %d, column %d: unrecognized symbol \"%s\"\n", currLine, currPos, yytext); exit(0);}

%%
