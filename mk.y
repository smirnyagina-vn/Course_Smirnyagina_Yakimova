%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern FILE *yyin;
extern FILE *yyout;

int yyparse();
int yyerror(const char *s);

extern int yylex();

unsigned int g_line_amt = 1;
unsigned int g_cond_amt = 0;            //to count the number of conditional structures
unsigned int g_if_trgt_created = 0;


char *g_name_of_file;
  
enum STATE_IN_TARG
{
	NORMAL,
    TARGET
};

inline static void check_state();
static enum STATE_IN_TARG targState = NORMAL;
inline static void switch_state(enum STATE_IN_TARG to);

%}
%define parse.error verbose

%union 
{
        int number;
        char *string;
}

%token <string> PATH
%token <string> STRING
%token <string> VAR_AUT
%token <string> UNIT_NAME
%token <string> NAME_OF_FILE
%token VAR_DEFINITION TEMPLATE TEMPLATE_TRGT SFX_TARGET COMMAND RUN_CMD CMD_CONT SHELL

%token SPECIAL
%token EOFILE EOL
%token IFEQ IFNEQ IFDEF IFNDEF ELSE ENDIF
%token INCLUDE DEFINE EXPORT ENDEF ERROR FUNCTION

%start input

%%
input: line
    | input line    //стартовая строка
    ;

line: EOL                          { }
    | ident EOL                    { printf("\nLine %u: alone ident error",g_line_amt-1);}
    | STRING EOL                   { printf("\nLine %u: alone ident error",g_line_amt-1);}
    | SHELL EOL                    { printf("\nLine %u: alone ident error",g_line_amt-1);}
    | variable                     { switch_state(NORMAL);}              
    | target                       { if(g_if_trgt_created == 0) ++g_if_trgt_created;switch_state(TARGET);}
    | command_seq                  { check_state();}
    | condition                    { }
    | include                       //включение нового make-файла
    | define                        //именованная командная последовательность
    | ERROR
    ;


variable: var_name VAR_DEFINITION EOL               //объявление переменной: имя = последовательность_символов
    | var_name VAR_DEFINITION variable_units EOL   //для экспорта переменных верхнего уровня на нижний
    | EXPORT UNIT_NAME EOL
    | EXPORT variable
    ;

var_name: UNIT_NAME                 { }
    | VAR_AUT                      { printf("\nLine %u: auto var \"%s\" error",g_line_amt,$1);}
    | PATH	                       { printf("\nLine %u: path var \"%s\" error",g_line_amt,$1);}
    | NAME_OF_FILE                 { printf("\nLine %u: filename var \"%s\" error",g_line_amt,$1);}
    ;

variable_units: UNIT_NAME           //может быть как один объект, так и лист объектов
    | STRING
    | PATH
    | NAME_OF_FILE
    |'(' variable_units ')'
    |'{' variable_units '}' 
    | variable_unit
    | variable_units variable_unit
    | variable_units UNIT_NAME
    | variable_units STRING
    | variable_units PATH
    | variable_units NAME_OF_FILE
    | variable_units '(' variable_units ')'
    | variable_units '{' variable_units '}'
    ;
    
variable_unit: VAR_DEFINITION
    | FUNCTION
    | SHELL
    | variable_unit_spec  
    | var_value
    | VAR_AUT        { printf("\nLine %u: auto var \"%s\" error",g_line_amt,$1);}
    ;

variable_unit_spec: ':'
    | '|'    
    | '+'
    | '/'
    | '-'  
    | '&'
    | ';'
    | '['
    | ']'
    | '<'
    | '>'
    ;

//ссылка на переменную
var_value: '$' UNIT_NAME                             { }       
    | '$' '$' UNIT_NAME                              { }
    | '$' PATH                                      { printf("\nLine %u: path var \"%s\" error",g_line_amt,$2);}
    | '$' '$' PATH                                  { printf("\nLine %u: path var \"%s\" error",g_line_amt,$3);}
    | '$' NAME_OF_FILE                              { printf("\nLine %u: filename var \"%s\" error",g_line_amt,$2);}
    | '$' '$' NAME_OF_FILE                          { printf("\nLine %u: filename var \"%s\" error",g_line_amt,$3); }
    | '$' STRING                                    { printf("\nLine %u: string var \"%s\" error",g_line_amt,$2); }
    | '$' '$' STRING                                { printf("\nLine %u: string var \"%s\" error",g_line_amt,$3);}
    | '$' '(' UNIT_NAME  ')'                         { }
    | '$' '{' UNIT_NAME  '}'                         {  }
    | '$' '(' PATH ')'                              { printf("\nLine %u: path var \"%s\" error",g_line_amt,$3); }
    | '$' '{' PATH '}'                              { printf("\nLine %u: path var \"%s\" error",g_line_amt,$3);}
    | '$' '(' NAME_OF_FILE ')'                      { printf("\nLine %u: filename var \"%s\" error",g_line_amt,$3); }
    | '$' '{' NAME_OF_FILE '}'                      { printf("\nLine %u: filename var \"%s\" error",g_line_amt,$3); }
    | '$' '(' STRING ')'                            { printf("\nLine %u: string var \"%s\" error",g_line_amt,$3); }
    | '$' '{' STRING '}'                            { printf("\nLine %u: string var \"%s\" error",g_line_amt,$3);}
    | '$' '(' variable_unit ')'
    | '$' '{' variable_unit '}'
    | '$' '$' '(' variable_units ')'                //переменные записываются в скрипте как `$(foo)' или `${foo}'
    | '$' '$' '{' variable_units '}'
    | '$' '(' UNIT_NAME  ':' subst VAR_DEFINITION subst ')' {  }
    | '$' '{' UNIT_NAME  ':' subst VAR_DEFINITION subst '}' {  }
    | '$' '(' variable_unit  ':' subst VAR_DEFINITION subst ')'
    | '$' '{' variable_unit  ':' subst VAR_DEFINITION subst '}'
    ;


    subst: UNIT_NAME
    | NAME_OF_FILE
    ;


//правила для цели//

/*
    В общем виде, правило выглядит так:

    цели : пререквизиты
            команда
            ...
    или так:

    цели : пререквизиты ; команда
            команда
            ...
*/


target: target_spec prerequisite EOL       
    | target_spec prerequisite ';' idents EOL
    | target_spec prerequisite ';' EOL
    ;

target_spec: target_names ':'
    | target_names ':'':'
    | SFX_TARGET ':'
    | SPECIAL ':'
    ;

target_names: target_names target_name
    | target_name
    ;

target_name: UNIT_NAME  { }
    | PATH
    | NAME_OF_FILE
    | TEMPLATE_TRGT
    | template
    | VAR_AUT  { printf("\nLine %u: auto var \"%s\" error",g_line_amt,$1);}
    | var_value
    ;


//правила для зависимостей(пререквизитов)//

prerequisite:
    | prerequisite_idents             { }
    ;

prerequisite_idents: prerequisite_ident
    | prerequisite_idents prerequisite_ident
    ;

prerequisite_ident: UNIT_NAME {}
    | PATH
    | NAME_OF_FILE
    | FUNCTION
    | template
    | VAR_AUT   { printf("\nLine %u: auto var \"%s\" error",g_line_amt,$1);}
    | var_value
    ;

template: TEMPLATE
    | '('TEMPLATE')'
    ;


//правило для команд, которые будут передаваться в bash

command_seq: cmd EOL     
    | cmd idents EOL
    | cmd_cont EOL
    ;

cmd_cont: CMD_CONT
    | cmd_cont CMD_CONT
    | cmd_cont cmd
    ;
cmd: COMMAND
    | RUN_CMD
    ;


//правила для условий//

/*
условная-директива
фрагмент-для-выполненного-условия
endif

условная-директива
фрагмент-для-выполненного-условия
else
фрагмент-для-невыполненного-условия
endif

возможные варианты для условия

ifeq (параметр1, параметр2)
ifeq 'параметр1' 'параметр2'
ifeq "параметр1" "параметр2"
ifeq "параметр1" 'параметр2'
ifeq 'параметр1' "параметр2"

*/


condition: if '(' cond ',' cond ')' EOL
    | if '(' ',' cond ')' EOL
    | if '(' cond ',' ')' EOL
    | if '(' ',' ')' EOL
    | if STRING STRING EOL   
    | ifdef ident EOL 
    | ELSE		     { if(!g_cond_amt) yyerror("else without ifeq/ifdef statement");}
    | ENDIF          { if(!g_cond_amt) yyerror("endif without ifeq/ifdef statement"); else --g_cond_amt;}
    ;


if: IFEQ     { ++g_cond_amt;}
    | IFNEQ  { ++g_cond_amt;}
    ;

ifdef: IFDEF { ++g_cond_amt; } 
    | IFNDEF { ++g_cond_amt; }
    ;

cond: ident
    | STRING
    | FUNCTION
    ;


//правила для многострочных переменных//

define: DEFINE UNIT_NAME EOL def_cmds ENDEF EOL
    ;

def_cmds: def_cmd
    | def_cmds def_cmd 
    ;

def_cmd: def_cmd_spec 
    | UNIT_NAME
    | PATH
    | NAME_OF_FILE
    | STRING
    | SHELL
    | VAR_DEFINITION
    | FUNCTION
    | var_value
    | VAR_AUT  
    | EOL   
    ;

def_cmd_spec: ':'
    | '|'    
    | '+'
    | '/'
    | '-'  
    | '&'
    | ';'
    | '['
    | ']'
    | '<'
    | '>'
    | '!'
    ;
    

//для включений других make-файлов//


include: INCLUDE filenames

filenames: UNIT_NAME
    | PATH
    | NAME_OF_FILE
    | var_value
    ;

idents: ident
    | idents ident
    ;

ident: UNIT_NAME
    | PATH
    | NAME_OF_FILE
    | VAR_AUT
    | var_value
    ;


%%


inline void switch_state(enum STATE_IN_TARG to)
{
    targState = to;
}

inline void check_state()
{
    if(targState == NORMAL)
      printf("\nLine %u: unmatched command_seq",g_line_amt-1);
}

int yyerror(const char *s)
{
  fprintf(stderr, "error: %s line %u\n", s, g_line_amt);
  exit(0);
}


int main(int argc, char **argv)
{
  if (argc > 1)
  {
    if(!(yyin = fopen(argv[1], "r")))
    {
      perror(argv[1]);
      return (1);
    }
  }

  g_name_of_file = argv[1];

  yyparse();

  printf("\nProgram finished analysis\n");

  return 0;
}