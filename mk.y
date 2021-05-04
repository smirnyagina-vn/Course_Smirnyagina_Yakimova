%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef DEBUG_YACC
#define DY(...) printf(__VA_ARGS__);
#else
#define DY(...) ;
#endif

int yyparse();
extern int yylex();
extern FILE *yyin;
extern FILE *yyout;
int yyerror(char *s);
unsigned int line = 1;
unsigned int tgts = 0;
unsigned int vars = 0;
unsigned int conds = 0;
unsigned int target_exist = 0;
unsigned int if_cond = 0;

unsigned int err_dep = 0;
unsigned int err_unknown_var = 0;
unsigned int err_auto_var = 0;
unsigned int err_path_var = 0;
unsigned int err_filename_var = 0;
unsigned int err_string_var = 0;
unsigned int err_alone_ident = 0;
unsigned int err_unmatched_command_seq = 0;

char *file;

struct _list
{
    char* value;
    unsigned int line;
    struct _list* next;
};

typedef struct _list list_t;
 
list_t *gVarList, *gTargetList, *gDepList;
list_t *gVarListCur, *gTargetListCur, *gDepListCur;

static void init_lists();
static void save_list(list_t*, char *value);
static void save_var(char* v);
static void save_target(char* t, unsigned int line );
static void save_dep(char* d, unsigned int line );

static int check_var(char *name);
  
enum STATE_IN_TARG
{
	NORMAL,
    TARGET
};

static enum STATE_IN_TARG targState = NORMAL;
inline static void switch_state(enum STATE_IN_TARG to);
inline static void check_state();
%}


%union 
{
        int number;
        char *string;
}

%token <string> VAR_NAME
%token <string> VAR_AUT
%token <string> PATH
%token <string> NAME_OF_FILE
%token <string> STRING
%token VAR_DEFINITION TEMPLATE TEMPLATE_TAR SFX_TARGET COMMAND_CMD RUN_CMD CMD_CONT SHELL
%token EXPORT INCLUDE DEFINE ENDEF FUNCTION ERROR
%token EOL EOFILE
%token IFEQ IFNEQ IFDEF IFNDEF ELSE ENDIF
%token SPECIAL

%start input

%%
input: line
    | input line    //стартовая строка
    ;

line: EOL                          { DY("\n%u:", line);}
    | ident EOL                    { printf("\nLine %u: alone ident error",line-1);++err_alone_ident;}
    | STRING EOL                   { printf("\nLine %u: alone ident error",line-1);++err_alone_ident;}
    | SHELL EOL                    { printf("\nLine %u: alone ident error",line-1);++err_alone_ident;}
    | variable                     { DY("VARIABLE \n%u:", line);++vars; switch_state(NORMAL);}              
    | target                       { DY("TARGET\n%u:", line); ++tgts; if(target_exist == 0) ++target_exist;switch_state(TARGET);}
    | command_seq                       { check_state();}
    | condition                    { DY("CONDITION \n%u:", line); ++vars;}
    | include                       //включение нового make-файла
    | define                        //именованная командная последовательность
    | ERROR
    ;


variable: var_name VAR_DEFINITION EOL          //объявление переменной: имя = последовательность_символов
    | var_name VAR_DEFINITION variable_units EOL   //для экспорта переменных верхнего уровня на нижний
    | EXPORT VAR_NAME EOL
    | EXPORT variable
    ;

var_name: VAR_NAME                      { save_var($1);}
    | VAR_AUT                      { printf("\nLine %u: auto var \"%s\" error",line,$1); ++err_auto_var;}
    | PATH	                        { printf("\nLine %u: path var \"%s\" error",line,$1); ++err_path_var;}
    | NAME_OF_FILE                      { printf("\nLine %u: filename var \"%s\" error",line,$1); ++err_filename_var;}
    ;

variable_units: VAR_NAME                    //может быть как один объект, так и лист объектов
    | STRING
    | PATH
    | NAME_OF_FILE
    |'(' variable_units ')'
    |'{' variable_units '}' 
    | variable_unit
    | variable_units variable_unit
    | variable_units VAR_NAME
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
    | VAR_AUT        { printf("\nLine %u: auto var \"%s\" error",line,$1); ++err_auto_var;}
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
var_value: '$' VAR_NAME                             { check_var($2); }       
    | '$' '$' VAR_NAME                              { check_var($3); }
    | '$' PATH                                  { printf("\nLine %u: path var \"%s\" error",line,$2); ++err_path_var;}
    | '$' '$' PATH                              { printf("\nLine %u: path var \"%s\" error",line,$3); ++err_path_var;}
    | '$' NAME_OF_FILE                              { printf("\nLine %u: filename var \"%s\" error",line,$2); ++err_filename_var;}
    | '$' '$' NAME_OF_FILE                          { printf("\nLine %u: filename var \"%s\" error",line,$3); ++err_filename_var;}
    | '$' STRING                                { printf("\nLine %u: string var \"%s\" error",line,$2); ++err_string_var;}
    | '$' '$' STRING                            { printf("\nLine %u: string var \"%s\" error",line,$3); ++err_string_var;}
    | '$' '(' VAR_NAME  ')'                         { check_var($3); }
    | '$' '{' VAR_NAME  '}'                         { check_var($3); }
    | '$' '(' PATH ')'                          { printf("\nLine %u: path var \"%s\" error",line,$3); ++err_path_var;}
    | '$' '{' PATH '}'                          { printf("\nLine %u: path var \"%s\" error",line,$3); ++err_path_var;}
    | '$' '(' NAME_OF_FILE ')'                      { printf("\nLine %u: filename var \"%s\" error",line,$3); ++err_filename_var;}
    | '$' '{' NAME_OF_FILE '}'                      { printf("\nLine %u: filename var \"%s\" error",line,$3); ++err_filename_var;}
    | '$' '(' STRING ')'                        { printf("\nLine %u: string var \"%s\" error",line,$3); ++err_string_var;}
    | '$' '{' STRING '}'                        { printf("\nLine %u: string var \"%s\" error",line,$3); ++err_string_var;}
    | '$' '(' variable_unit ')'
    | '$' '{' variable_unit '}'
    | '$' '$' '(' variable_units ')'            //переменные записываются в скрипте как `$(foo)' или `${foo}'
    | '$' '$' '{' variable_units '}'
    | '$' '(' VAR_NAME  ':' subst VAR_DEFINITION subst ')' { check_var($3); }
    | '$' '{' VAR_NAME  ':' subst VAR_DEFINITION subst '}' { check_var($3); }
    | '$' '(' variable_unit  ':' subst VAR_DEFINITION subst ')'
    | '$' '{' variable_unit  ':' subst VAR_DEFINITION subst '}'
    ;


    subst: VAR_NAME
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

target_name: VAR_NAME  { save_target($1,line); }
    | PATH
    | NAME_OF_FILE
    | TEMPLATE
    | template
    | VAR_AUT  { printf("\nLine %u: auto var \"%s\" error",line,$1); ++err_auto_var;}
    | var_value
    ;


//правила для зависмостей(пререквизитов)//

prerequisite:
    | prerequisite_idents             { DY("DEPS ");}
    ;

prerequisite_idents: prerequisite_ident
    | prerequisite_idents prerequisite_ident
    ;

prerequisite_ident: VAR_NAME {save_dep($1,line);}
    | PATH
    | NAME_OF_FILE
    | FUNCTION
    | template
    | VAR_AUT   { printf("\nLine %u: auto var \"%s\" error",line,$1); ++err_auto_var;}
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
cmd: COMMAND_CMD
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
    | ELSE		     { if(!if_cond) yyerror("else without ifeq/ifdef statement"); DY("ELSE\n%u",line);}
    | ENDIF          { if(!if_cond) yyerror("endif without ifeq/ifdef statement"); else --if_cond; DY("ENDIF\n%u",line); ++conds;}
    ;


if: IFEQ     { ++if_cond;}
    | IFNEQ  { ++if_cond;}
    ;

ifdef: IFDEF { ++if_cond; } 
    | IFNDEF { ++if_cond; }
    ;

cond: ident
    | STRING
    | FUNCTION
    ;


//правила для многострочных переменных//

define: DEFINE VAR_NAME EOL def_cmds ENDEF EOL
    ;

def_cmds: def_cmd
    | def_cmds def_cmd 
    ;

def_cmd: def_cmd_spec 
    | VAR_NAME
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

filenames: VAR_NAME
    | PATH
    | NAME_OF_FILE
    | var_value
    ;

idents: ident
    | idents ident
    ;

ident: VAR_NAME
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
    {
      ++err_unmatched_command_seq;
      printf("\nLine %u: unmatched command_seq",line-1);
    }
}

int yyerror(char *s)
{
  fprintf(stderr, "error: %s line %u\n", s, line);
  exit(0);
}

static void init_lists()
{
    gVarListCur = malloc(sizeof(list_t));
    gTargetListCur = malloc(sizeof(list_t));
    gDepListCur = malloc(sizeof(list_t));

    if (!(gVarListCur && gTargetListCur && gDepListCur))
    {
      printf("Error allocate memory for global lists\n");
      exit(0);
    }
    
    memset(gVarListCur,0,sizeof(list_t));
    memset(gTargetListCur,0,sizeof(list_t));
    memset(gDepListCur,0,sizeof(list_t));

    gVarList = gVarListCur;
    gTargetList = gTargetListCur;
    gDepList = gDepListCur;
}

static void save_var(char* v)
{
  list_t *node = malloc(sizeof(list_t));
  memset(node,0,sizeof(list_t));
  unsigned int len = strlen(v)+1;

  node->value = malloc(len);
  memset(node->value,0,len);
  memcpy(node->value,v,len);

  node->next = NULL;

  
  gVarListCur->next = node;
  gVarListCur = gVarListCur->next;
}

static void print_list(list_t *list)
{
    list_t *l = list->next;
    while(l->next != NULL)
    {
      printf("%s\n",l->value);
      l = l->next;
    }
}

static void save_target(char* t , unsigned int line)
{
  list_t *node = malloc(sizeof(list_t));
  memset(node,0,sizeof(list_t));
  unsigned int len = strlen(t)+1;

  node->value = malloc(len);
  memset(node->value,0,len);
  memcpy(node->value,t,len);
  node->line = line;
  node->next = NULL;

  
  gTargetListCur->next = node;
  gTargetListCur = gTargetListCur->next;
}

static void save_dep(char* d, unsigned int line)
{
  list_t *node = malloc(sizeof(list_t));
  memset(node,0,sizeof(list_t));
  unsigned int len = strlen(d)+1;

  node->value = malloc(len);
  memset(node->value,0,len);
  memcpy(node->value,d,len);
  node->line = line;
  node->next = NULL;

  
  gDepListCur->next = node;
  gDepListCur = gDepListCur->next;
}

static int check_var(char *name)
{
    list_t *l = gVarList->next;
    while(l != NULL)
    {
      unsigned int len = strlen(l->value);
      if(!strncmp(name,l->value,len))
      {
         return 0;
      }
      l = l->next;
    }
    printf("\nLine %u: unknown var \"%s\" error\n",line,name);
    ++err_unknown_var;
    return 1;
}

void check_prerequisite()
{
    list_t *d = gDepList->next;
    while(d != NULL)
    {
      unsigned int dlen = strlen(d->value);
      char * dep = d->value;
      list_t *t = gTargetList->next;
      unsigned char found = 0;
      while (t != NULL)
      {
	 unsigned int tlen = strlen(t->value);
         if(!strncmp(dep , t->value ,tlen > dlen ? dlen : tlen))
         {
	   found = 1;
	   break;
         }
         t = t->next;
      }

      if(found == 0)
      {
	printf("\nLine %u: unknown prerequisite \"%s\" error",d->line, dep);
	++err_dep;
      }
      d = d->next;
    }
}
static void clean_list(list_t *l)
{
    list_t *next = l->next;
    while(l != NULL)
    {
      if(l->value != NULL)
      {
	free(l->value);
      }
      next = l->next;
      free(l);
      l = next;
    }
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
  file = argv[1];
  DY("1:");
  init_lists();
  yyparse();
  check_prerequisite();

  printf("\nProgram finished analysis\n");

  clean_list(gVarList);
  clean_list(gDepList);
  clean_list(gTargetList);
  return 0;
}


