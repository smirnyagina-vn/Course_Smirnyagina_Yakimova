%{
#include "mk.tab.h"

extern unsigned int g_line_amt;
extern int yyerror(const char *);
unsigned int cont = 0;
extern char* g_name_of_file;
static void update_line();
static void handle_function();
%}

DIGIT [0-9]
UNIT_NAME [_a-zA-Z\-\+\@\\]
RUN_CMD ^(\@[^\@]*\@)?\t\.\/[^\n]*          
CMD_S ^(\@[^\@]*\@)?\t[^\n]*
%%


{RUN_CMD}                        { return RUN_CMD;}
{CMD_S}                          { return COMMAND;}
{RUN_CMD}(\\\n[ \t]*[^\n]*)*     { update_line(); return RUN_CMD;}
{CMD_S}(\\\n[ \t]*[^\n]*)*       { update_line(); return COMMAND;}

"#"[^\n]*   {}

","         { return ','; }           
"?"         { return '?'; }
"!"         { return '!'; }
":"         { return ':'; }
";"         { return ';'; }
"-"         { return '-'; }
"+"         { return '+'; }
"\""        { return '"'; }
"|"         { return '|'; }
"/"         { return '/'; }
"&"         { return '&'; }
"$"         { return '$'; }
"]"         { return ']'; }
"["         { return '['; }
"("         { return '('; }
")"         { return ')'; }
"{"         { return '{'; }
"}"         { return '}'; }
"<"         { return '<'; }
">"         { return '>'; }
"`"         { return '`'; }
\'          { return '\''; }
\n          { ++g_line_amt; cont = 0; return EOL;}
[ \t]+\n    { ++g_line_amt; cont = 0; return EOL;}
"@"         {  }
"else"      { return ELSE;}
^"endef"    { return ENDEF;}
"ifeq"      { return IFEQ;}
"endif"     { return ENDIF;}
"ifneq"     { return IFNEQ;}
"ifdef"     { return IFDEF;}
"ifndef"    { return IFNDEF;}
^"define"   { return DEFINE;}
^"export"   { return EXPORT;}
^"include"  { return INCLUDE;}
<<EOF>>     { static int once = 0; return once++ ? 0 : EOL;}
  
".PHONY"|".SUFFIXES"|".DEFAULT"|".PRECIOUS"|".INTERMEDIATE"|".SECONDARY"|".DELETE_ON_ERROR"|".IGNORE"|".SILENT"|".EXPORT_ALL_VARIABLES"|".NOTPARALLEL"    { return SPECIAL; }

$\("foreach"    { handle_function();return FUNCTION;}
$\("subst"      { handle_function();return FUNCTION;}
$\("patsubst"   { handle_function();return FUNCTION;}
$\("findstring" { handle_function();return FUNCTION;}
$\("filter-out" { handle_function();return FUNCTION;}
$\("sort"       { handle_function();return FUNCTION;}
$\("word"       { handle_function();return FUNCTION;}
$\("wordlist"   { handle_function();return FUNCTION;}
$\("firstword"  { handle_function();return FUNCTION;}
$\("dir"        { handle_function();return FUNCTION;}
$\("notdir"     { handle_function();return FUNCTION;}
$\("suffix"     { handle_function();return FUNCTION;}
$\("basename"   { handle_function();return FUNCTION;}
$\("addsuffix"  { handle_function();return FUNCTION;}
$\("addprefix"  { handle_function();return FUNCTION;}
$\("strip"      { handle_function();return FUNCTION;}
$\("join"       { handle_function();return FUNCTION;}
$\("wildcard"   { handle_function();return FUNCTION;}
$\("realpath"   { handle_function();return FUNCTION;}
$\("abspath"    { handle_function();return FUNCTION;}
$\("if"         { handle_function();return FUNCTION;}
$\("or"         { handle_function();return FUNCTION;}
$\("and"        { handle_function();return FUNCTION;}
$\("file"       { handle_function();return FUNCTION;}
$\("call"       { handle_function();return FUNCTION;}
$\("value"      { handle_function();return FUNCTION;}
$\("eval"       { handle_function();return FUNCTION;}
$\("origin"     { handle_function();return FUNCTION;}
$\("flavour"    { handle_function();return FUNCTION;}
$\("error"      { handle_function();return ERROR;}

^"%"({UNIT_NAME}|{DIGIT}|[\.]|[//])*                              { return TEMPLATE_TRGT;}
^"."({UNIT_NAME}|{DIGIT})*"."({UNIT_NAME}|{DIGIT})+                  { return SFX_TARGET;}


\"[^\"]*\"                        { yylval.string = strdup(yytext); return STRING; }
\'[^\']*\'                        { yylval.string = strdup(yytext); return STRING; }
\`[^\`]*\`                        { return SHELL; }
$\(shell[^\)]*\)                  { return SHELL; }

"::="|"="                         { return VAR_DEFINITION; }
[":"|"!"|"?"|"+"]"="              { return VAR_DEFINITION; }

$("@"|"%"|"<"|"?"|"^"|"+"|"*")    { yylval.string = strdup(yytext);return VAR_AUT; }



\%({UNIT_NAME}|{DIGIT}|[\.])*            { return TEMPLATE;}

\\[\r]?\n[ \t]*  { ++g_line_amt;}

({UNIT_NAME}|{DIGIT})+                   { yylval.string = strdup(yytext); return UNIT_NAME; }


({UNIT_NAME}|{DIGIT}|[\.])+                 { yylval.string = strdup(yytext); return NAME_OF_FILE; }
(\/|[\.\.]|[\.])?(({UNIT_NAME}|{DIGIT}|[\.]|[\.\.])+[\/]?)+([\/]|[\/\*])?  { yylval.string = strdup(yytext); return PATH; }

[ \t\f\v\r]
.          { printf("0x%x ",yytext[0]);yyerror("!syntax error"); exit(0); }

%%

static void handle_function()
{
    int c = 0; 
    int sc_count = 1; 
    int prev = 0;
    while((c=input())) 
    { 
        switch (c)
        {
            
            case ')': 
            { 
                if(--sc_count == 0) 
                { 
                    return;
                }
                break;
            }
            case '(':
            { 
                ++sc_count;
                break;
            }
            case '\n':
            {
                if (prev == '\\')
                {
                    ++g_line_amt;
                    break;
                }
                else
                {
                    yyerror("!syntax function error");
                }
                
            }
            default: prev = c; break;
        }
    }
}


static void update_line()
{
    char str[256];
    memset(str,0,256);
    snprintf(str,256,"sed -n \'%u,$ p\' %s | grep \'[^\\\\$]*[^\\\\]$\' -m1 -n | cut -d : -f 1", g_line_amt, g_name_of_file);
    FILE *f = popen(str, "r");
    if (!feof(f)) {
         if(fgets(str,256,f) != NULL)
         {
            g_line_amt += atoi(str);
            --g_line_amt;
         }
    }
    pclose(f);
}

int yywrap()
{
    return 1;
}
