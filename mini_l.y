/* An intermediate code generator for the MINI-L language */

%{
 #include "heading.h"
 void yyerror(const char* msg);
 int yylex(void);

 bool var_declared(string);
 bool var_multiply_declared(string);
 bool array_declared(string);
 bool function_declared(string);
 void continue_error();
 bool main_declared = false;
string reservedArray[] = {"function","beginparams","endparams","beginlocals","endlocals","beginbody","endbody","integer","array","of","if","then","endif","else","while","do","beginloop","endloop","continue","read","write","and","or","not","true","false","return"};
vector<string> reserved(reservedArray, reservedArray + sizeof(reservedArray)/sizeof(string));

 stringstream ss;

 bool declaringParams = false;
 bool declaringVars = false;
 vector<string> parameters;
 vector<string> statements;
 vector<string> func_table;
 vector<string> symbol_table;
 vector<string> symbol_type;
 vector<string> op;

 int __temp__count;
 int label_count = 0;
 vector< vector <string> > if_label;
 vector< vector <string> > loop_label;
 vector<string> doWhile_label;

 stack<string> parameter_queue;
 stack<string> read_in;

 vector<string> mil;
%}

%union{
  double dval;
  int ival;
  string* op_val;
}

%error-verbose
%start prog_start

%token FUNCTION BEGIN_PARAMS END_PARAMS BEGIN_LOCALS END_LOCALS BEGIN_BODY END_BODY INTEGER ARRAY OF IF THEN ENDIF ELSE WHILE DO BEGINLOOP ENDLOOP CONTINUE READ WRITE TRUE FALSE RETURN SEMICOLON COLON COMMA L_PAREN R_PAREN L_SQUARE_BRACKET R_SQUARE_BRACKET ASSIGN
%token <dval> NUMBER
%token <op_val> IDENT
%left MULT DIV MOD ADD SUB
%left EQ NEQ LT GT LTE GTE
%right NOT
%left AND OR
%right ASSIGN

%%
prog_start: functions
	   ;

functions: /* empty */
          {
                if(!main_declared)
                {
                    cerr << "error: a main function has not been defined" << endl; exit(0);
                }
                for(unsigned int i = 0; i < mil.size() - 1; ++i)
                {
                    cout << mil.at(i);
                }
          }
          | function functions
          ;

func_name: FUNCTION IDENT
          {
                func_table.push_back(*($2));
                mil.push_back("func ");
                mil.push_back(*($2));
                mil.push_back("\n");
                if(*($2) == "main")
                {
                    main_declared = true;
                }
          }
          ;

beginparams: BEGIN_PARAMS { declaringVars = true; declaringParams = true; }
            ;

endparams: END_PARAMS { declaringVars = false; declaringParams = false; }
          ;

beginlocals: BEGIN_LOCALS { declaringVars = true; }
            ;

endlocals: END_LOCALS { declaringVars = false; }
          ;

function: func_name SEMICOLON beginparams declarations endparams beginlocals declarations endlocals BEGIN_BODY statements END_BODY
         {
            for(unsigned int i = 0; i < symbol_table.size(); ++i)
            {
                if(symbol_type.at(i) == "INTEGER")
                {
                    mil.push_back(". ");
                    mil.push_back(symbol_table.at(i));
                    mil.push_back("\n");
                }
                else
                {
                    mil.push_back(".[] ");
                    mil.push_back(symbol_table.at(i));
                    mil.push_back(", ");
                    mil.push_back(symbol_type.at(i));
                    mil.push_back("\n");
                }
            }
            symbol_table.clear();
            symbol_type.clear();

            for(unsigned int i = 0; i < parameters.size(); ++i)
            {
                mil.push_back("= ");
                mil.push_back(parameters.at(i));
                mil.push_back(", $");
                ss.str("");
                ss << i;
                mil.push_back(ss.str());
                mil.push_back("\n");
            }
            parameters.clear();

            for(unsigned int i = 0; i < statements.size(); ++i)
            {
                mil.push_back(statements.at(i));
                mil.push_back("\n");
            }
            mil.push_back("endfunc");
            mil.push_back("\n");
            mil.push_back("\n");

            statements.clear();
            doWhile_label.clear();
         }
         ;

declarations: /* empty */
             | declaration SEMICOLON declarations
             ;

declaration: identifier COLON INTEGER
            {
                symbol_type.push_back("INTEGER");
            }
            | identifier COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER
            {
                if($5 == 0)
                {
                    extern int currLine, currPos;
                    cerr << "error at line " << currLine << ", column " << currPos << ": cannot declare an array of size zero" << endl;
                    exit(0);
                }
                ss.str("");
                ss << $5;
                symbol_type.push_back(ss.str());
            }
            | identifier COLON ARRAY L_SQUARE_BRACKET SUB NUMBER R_SQUARE_BRACKET OF INTEGER
            {
                    extern int currLine, currPos;
                    cerr << "error at line " << currLine << ", column " << currPos << ": cannot declare an array of negative size" << endl;
                    exit(0);
            }
 		    ;

identifier: IDENT
           {
                if(declaringVars)
                {
                    if(var_multiply_declared(*($1)))
                    {
                        exit(0);
                    }
                }
                symbol_table.push_back(*($1));
                if(declaringParams)
                {
                    parameters.push_back(*($1));
                }
           }
 	   | IDENT COMMA identifier
           {
                if(declaringVars)
                {
                   if(var_multiply_declared(*($1)))
                   {
                       exit(0);
                   }
                }
                symbol_table.push_back(*($1));
                symbol_type.push_back("INTEGER");
                if(declaringParams)
                {
                    parameters.push_back(*($1));
                }
           }
 		   ;

statements: /* empty */
           | statement SEMICOLON statements
           ;

statement: IDENT ASSIGN expression
          {
                string var = *($1);
                if(!var_declared(var))
                {
                    exit(0);
                }
                statements.push_back("= " + var + ", " + op.back());
                op.pop_back();
          }
          | IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET ASSIGN expression
          {
                string var = *($1);
                if(!array_declared(var))
                {
                    exit(0);
                }
                string array_result_expression = op.back();
                op.pop_back();
                string array_expression = op.back();
                op.pop_back();
                statements.push_back("[]= " + *($1) + ", " + array_expression + ", " + array_result_expression);
          }
          | ifelse
          | whileloop
          | dowhileloop
          | readvars
          | writevars
          | CONTINUE
          {
              bool doWhile = false;
              if(!loop_label.empty())
              {
                  string potentialDoWhile = loop_label.back().at(0);

                  for(unsigned int i = 0; i < doWhile_label.size(); ++i)
                  {
                      if(doWhile_label.at(i) == potentialDoWhile)
                      {
                        doWhile = true;
                      }
                  }
                  if(doWhile)
                  {
                      statements.push_back(":= " + loop_label.back().at(1));
                  }
                  else
                  {
                      statements.push_back(":= " + loop_label.back().at(0));
                  }
              }
              else
              {
                  continue_error();
                  exit(0);
              }
          }
          | RETURN expression { statements.push_back("ret " + op.back()); op.pop_back(); }
          ;

ifelse: if_statement statements ENDIF
        {
            statements.push_back(": " + if_label.back().at(1));
            if_label.pop_back();
        }
        | elseif statements ENDIF
	{
           statements.push_back(": " + if_label.back().at(2));
           if_label.pop_back();
        }
        ;

if_statement: IF bool_expr THEN
              {
                    ss.str("");
                    ss << label_count;
                    ++label_count;
                    string label1 = "__label__" + ss.str();
                    ss.str("");
                    ss << label_count;
                    ++label_count;
                    string label2 = "__label__" + ss.str();
                    ss.str("");
                    ss << label_count;
                    ++label_count;
                    string label3 = "__label__" + ss.str();
                    vector<string> iflabels;
                    iflabels.push_back(label1);
                    iflabels.push_back(label2);
                    iflabels.push_back(label3);
                    if_label.push_back(iflabels);
                    statements.push_back("?:= " + if_label.back().at(0) + ", " + op.back());
                    op.pop_back();
                    statements.push_back(":= " + if_label.back().at(1));
                    statements.push_back(": " + if_label.back().at(0));
              }
              ;

elseif: if_statement statements ELSE
       {
            statements.push_back(":= " + if_label.back().at(2));
            statements.push_back(": " + if_label.back().at(1));
       }
       ;

while_declaration: WHILE
                  {
                        ss.str("");
                        ss << label_count;
                        ++label_count;
                        string label1 = "__label__" + ss.str();
                        ss.str("");
                        ss << label_count;
                        ++label_count;
                        string label2 = "__label__" + ss.str();
                        ss.str("");
                        ss << label_count;
                        ++label_count;
                        string label3 = "__label__" + ss.str();
                        vector<string> whilelabels;
                        whilelabels.push_back(label1);
                        whilelabels.push_back(label2);
                        whilelabels.push_back(label3);
                        loop_label.push_back(whilelabels);
                        statements.push_back(": " + loop_label.back().at(0));
                  }
                  ;

endwhile: while_declaration bool_expr BEGINLOOP
         {
                 statements.push_back("?:= " + loop_label.back().at(1) + ", " + op.back());
                 op.pop_back();
                 statements.push_back(":= " + loop_label.back().at(2));
                 statements.push_back(": " + loop_label.back().at(1));
         }

whileloop: endwhile statements ENDLOOP
        {
              statements.push_back(":= " + loop_label.back().at(0));
              statements.push_back(": " + loop_label.back().at(2));
              loop_label.pop_back();
        }
        ;

dowhile_declaration: DO BEGINLOOP
                   {
                        ss.str("");
                        ss << label_count;
                        ++label_count;
                        string label1 = "__label__" + ss.str();
                        doWhile_label.push_back(label1);
                        ss.str("");
                        ss << label_count;
                        ++label_count;
                        string label2 = "__label__" + ss.str();
                        vector <string> dowhilelabels;
                        dowhilelabels.push_back(label1);
                        dowhilelabels.push_back(label2);
                        loop_label.push_back(dowhilelabels);
                        statements.push_back(": " + label1);
                   }

enddowhile: dowhile_declaration statements ENDLOOP
           {
                statements.push_back(": " + loop_label.back().at(1));
           }

dowhileloop: enddowhile WHILE bool_expr
            {
                  statements.push_back("?:= " + loop_label.back().at(0) + ", " + op.back());
                  op.pop_back();
                  loop_label.pop_back();
            }
            ;

readvars: READ IDENT vars
         {
            string var = *($2);
            if(!var_declared(var))
            {
                exit(0);
            }
            statements.push_back(".< " + *($2));
            while(!read_in.empty())
            {
                statements.push_back(read_in.top());
                read_in.pop();
            }
         }
         | READ IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET vars
         {
            string var = *($2);
            if(!array_declared(var))
            {
                exit(0);
            }
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            statements.push_back(".< " + __temp__);
            statements.push_back("[]= " + *($2) + ", " + op.back() + ", " + __temp__);
            op.pop_back();
            while(!read_in.empty())
            {
                statements.push_back(read_in.top());
                read_in.pop();
            }
         }
         ;

vars: /* empty */
     | COMMA IDENT vars
     {
        string var = *($2);
        if(!var_declared(var))
        {
            exit(0);
        }
        read_in.push(".< " + *($2));
     }
     | COMMA IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET vars
     {
         string var = *($2);
         if(!array_declared(var))
         {
             exit(0);
         }
         ss.str("");
         ss << __temp__count;
         ++__temp__count;
         string __temp__ = "__temp__" + ss.str();
         symbol_table.push_back(__temp__);
         symbol_type.push_back("INTEGER");
         read_in.push(".< " + __temp__);
         read_in.push("[]= " + *($2) + ", " + op.back() + ", " + __temp__);
         op.pop_back();
     }
     ;

writevars: WRITE term_varnum varcomma
        {
            while(!op.empty())
            {
            	string s = op.front();
                op.erase(op.begin());
                statements.push_back(".> " + s);
            }
            op.clear();
        }
	;

varcomma: /* empty */
	| COMMA term_varnum varcomma
        ;

bool_expr: relation_and_expr
	 | bool_expr OR relation_and_expr
         {
             ss.str("");
             ss << __temp__count;
             ++__temp__count;
             string __temp__ = "__temp__" + ss.str();
             symbol_table.push_back(__temp__);
             symbol_type.push_back("INTEGER");
             string op2 = op.back();
             op.pop_back();
             string op1 = op.back();
             op.pop_back();
             statements.push_back("|| " + __temp__ + ", " + op1 + ", " + op2);
             op.push_back(__temp__);
         }
	 ;

relation_and_expr: relation_expr
        	  | relation_and_expr AND relation_expr
                  {
                        ss.str("");
                        ss << __temp__count;
                        ++__temp__count;
                        string __temp__ = "__temp__" + ss.str();
                        symbol_table.push_back(__temp__);
                        symbol_type.push_back("INTEGER");
                        string op2 = op.back();
                        op.pop_back();
                        string op1 = op.back();
                        op.pop_back();
                        statements.push_back("&& " + __temp__ + ", " + op1 + ", " + op2);
                        op.push_back(__temp__);
                  }
        	  ;

relation_expr: comptr
	      | NOT comptr
              {
                    ss.str("");
                    ss << __temp__count;
                    ++__temp__count;
                    string __temp__ = "__temp__" + ss.str();
                    symbol_table.push_back(__temp__);
                    symbol_type.push_back("INTEGER");
                    string op1 = op.back();
                    op.pop_back();
                    statements.push_back("! " + __temp__ + ", " + op1);
                    op.push_back(__temp__);
              }
              ;

comptr:	expression EQ expression
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            string op2 = op.back();
            op.pop_back();
            string op1 = op.back();
            op.pop_back();
            statements.push_back("== " + __temp__ + ", " + op1 + ", " + op2);
            op.push_back(__temp__);
        }
	| expression NEQ expression
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            string op2 = op.back();
            op.pop_back();
            string op1 = op.back();
            op.pop_back();
            statements.push_back("!= " + __temp__ + ", " + op1 + ", " + op2);
            op.push_back(__temp__);
        }
        | expression LT expression
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            string op2 = op.back();
            op.pop_back();
            string op1 = op.back();
            op.pop_back();
            statements.push_back("< " + __temp__ + ", " + op1 + ", " + op2);
            op.push_back(__temp__);
        }
        | expression GT expression
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            string op2 = op.back();
            op.pop_back();
            string op1 = op.back();
            op.pop_back();
            statements.push_back("> " + __temp__ + ", " + op1 + ", " + op2);
            op.push_back(__temp__);
        }
        | expression LTE expression
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            string op2 = op.back();
            op.pop_back();
            string op1 = op.back();
            op.pop_back();
            statements.push_back("<= " + __temp__ + ", " + op1 + ", " + op2);
            op.push_back(__temp__);
        }
        | expression GTE expression
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            string op2 = op.back();
            op.pop_back();
            string op1 = op.back();
            op.pop_back();
            statements.push_back(">= " + __temp__ + ", " + op1 + ", " + op2);
            op.push_back(__temp__);
        }
        | TRUE
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            statements.push_back("= " + __temp__ + ", 1");
            op.push_back(__temp__);
        }
	| FALSE
        {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            statements.push_back("= " + __temp__ + ", 0");
            op.push_back(__temp__);
        }
	| L_PAREN bool_expr R_PAREN
        ;

expression: multiplicative_expr
           | multiplicative_expr ADD expression
           {
                ss.str("");
                ss << __temp__count;
                ++__temp__count;
                string __temp__ = "__temp__" + ss.str();
                symbol_table.push_back(__temp__);
                symbol_type.push_back("INTEGER");
                string op2 = op.back();
                op.pop_back();
                string op1 = op.back();
                op.pop_back();
                statements.push_back("+ " + __temp__ + ", " + op1 + ", " + op2);
                op.push_back(__temp__);
           }
           | multiplicative_expr SUB expression
           {
                ss.str("");
                ss << __temp__count;
                ++__temp__count;
                string __temp__ = "__temp__" + ss.str();
                symbol_table.push_back(__temp__);
                symbol_type.push_back("INTEGER");
                string op2 = op.back();
                op.pop_back();
                string op1 = op.back();
                op.pop_back();
                statements.push_back("- " + __temp__ + ", " + op1 + ", " + op2);
                op.push_back(__temp__);
           }
	   ;

multiplicative_expr: term
                    | term MULT multiplicative_expr
                    {
                        ss.str("");
                        ss << __temp__count;
                        ++__temp__count;
                        string __temp__ = "__temp__" + ss.str();
                        symbol_table.push_back(__temp__);
                        symbol_type.push_back("INTEGER");
                        string op2 = op.back();
                        op.pop_back();
                        string op1 = op.back();
                        op.pop_back();
                        statements.push_back("* " + __temp__ + ", " + op1 + ", " + op2);
                        op.push_back(__temp__);
                    }
                    | term DIV multiplicative_expr
                    {
                        ss.str("");
                        ss << __temp__count;
                        ++__temp__count;
                        string __temp__ = "__temp__" + ss.str();
                        symbol_table.push_back(__temp__);
                        symbol_type.push_back("INTEGER");
                        string op2 = op.back();
                        op.pop_back();
                        string op1 = op.back();
                        op.pop_back();
                        statements.push_back("/ "+ __temp__ + ", " + op1 + ", " + op2);
                        op.push_back(__temp__);
                    }
                    | term MOD multiplicative_expr
                    {
                        ss.str("");
                        ss << __temp__count;
                        ++__temp__count;
                        string __temp__ = "__temp__" + ss.str();
                        symbol_table.push_back(__temp__);
                        symbol_type.push_back("INTEGER");
                        string op2 = op.back();
                        op.pop_back();
                        string op1 = op.back();
                        op.pop_back();
                        statements.push_back("% "+ __temp__ + ", " + op1 + ", " + op2);
                        op.push_back(__temp__);
                    }
                    ;

term: term_varnum {}
      | SUB term_varnum
      {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            statements.push_back("- " + __temp__ + ", 0, " + op.back());
            op.pop_back();
            op.push_back(__temp__);
      }
      | IDENT term_iden
      {
            ss.str("");
            ss << __temp__count;
            ++__temp__count;
            string __temp__ = "__temp__" + ss.str();
            symbol_table.push_back(__temp__);
            symbol_type.push_back("INTEGER");
            if(!function_declared(*($1)))
            {
                exit(0);
            }
            statements.push_back("call " + *($1) + ", " + __temp__);
            op.push_back(__temp__);
      }
      ;

term_varnum: var
            {
                ss.str("");
                ss << __temp__count;
                ++__temp__count;
                string __temp__ = "__temp__" + ss.str();
                symbol_table.push_back(__temp__);
                symbol_type.push_back("INTEGER");
                string op1 = op.back();
                if(op1.at(0) == '[')
                {
                    statements.push_back("=[] " + __temp__ + ", " + op1.substr(3, op1.length() - 3));
                }
                else
                {
                    statements.push_back("= " + __temp__ + ", " + op.back());
                }
                op.pop_back();
                op.push_back(__temp__);
            }
            | NUMBER
            {
                ss.str("");
                ss << __temp__count;
                ++__temp__count;
                string __temp__ = "__temp__" + ss.str();
                symbol_table.push_back(__temp__);
                symbol_type.push_back("INTEGER");
                ss.str("");
                ss << $1;
                statements.push_back("= " + __temp__ + ", " + ss.str());
                op.push_back(__temp__);
            }
            | L_PAREN expression R_PAREN
            ;

term_iden: L_PAREN term_expr R_PAREN
          {
              while(!parameter_queue.empty())
              {
                  statements.push_back("param " + parameter_queue.top());
                  parameter_queue.pop();
              }
          }
          | L_PAREN R_PAREN {}
          ;

term_expr: expression
         {
             parameter_queue.push(op.back());
             op.pop_back();
         }
         | expression COMMA term_expr
         {
             parameter_queue.push(op.back());
             op.pop_back();
         }
         ;

var: IDENT
    {
        string var = *($1);
        if (!var_declared(var))
        {
            exit(0);
        }
        op.push_back(var);
    }
    | IDENT L_SQUARE_BRACKET expression R_SQUARE_BRACKET
    {
        string op1 = op.back();
        op.pop_back();
        string var = *($1);
        if(!array_declared(var))
        {
            exit(0);
        }
        op.push_back("[] " + var + ", " + op1);
    }
    ;

%%

void yyerror(const char *msg)
{
   extern int currLine, currPos;
   if(declaringVars)
   {
        cerr << "error at line " << currLine << ", column " << currPos << ": variables cannot have the same name as a reserved keyword" << endl;
   }
   else
   {
        printf("** Line %d, position %d: %s\n", currLine, currPos-1, msg);
   }
}

bool var_declared(string var)
{
    extern int currLine, currPos;
    for(unsigned int i = 0; i < symbol_table.size(); ++i)
    {
        if(symbol_table.at(i) == var)
        {
            if(symbol_type.at(i) == "INTEGER")
            {
                return true;
            }
            else
            {
                cerr << "error at line " << currLine << ", column " << currPos << ": incompatible types in assignment of array \'" << var << "\' to integer" << endl;
                return false;
            }
        }
    }
    cerr << "error at line " << currLine << ", column " << currPos << ": variable \'" << var << "\' was not previously declared" << endl;
    return false;
}

bool var_multiply_declared(string var)
{
    extern int currLine, currPos;
    for(unsigned int i = 0; i < symbol_table.size(); ++i)
    {
        if(symbol_table.at(i) == var)
        {
                cerr << "error at line " << currLine << ", column " << currPos << ": symbol \'" << var << "\' is multiply-defined" << endl;
                return true;
        }
    }
    return false;
}

bool array_declared(string var)
{
    extern int currLine, currPos;
    for(unsigned int i = 0; i < symbol_table.size(); ++i)
    {
        if(symbol_table.at(i) == var)
        {
            if(symbol_type.at(i) == "INTEGER")
            {
                cerr << "error at line " << currLine << ", column " << currPos << ": incompatible types in assignment of integer \'" << var << "\' to array" << endl;
                return false;
            }
            else
            {
                return true;
            }
        }
    }
    cerr << "error at line " << currLine << ", column " << currPos << ": array \'" << var << "\' was not previously declared" << endl;
    return false;
}

bool function_declared(string var)
{
    extern int currLine, currPos;

    for(unsigned int i = 0; i < func_table.size(); ++i)
    {
        if(func_table.at(i) == var)
        {
            return true;
        }
    }
    cerr << "error at line " << currLine << ", column " << currPos << ": function \'" << var << "\' has not been defined" << endl;
    return false;
}

void continue_error()
{
    extern int currLine, currPos;

    cerr << "error at line " << currLine << ", column " << currPos << ": continue not within a loop" << endl;
}
