%{
#include "mk.tab.h"

extern unsigned int line;
extern int yyerror(const char *);
unsigned int cont = 0;
extern char* file;
static void update_line();
static void handle_function();
%}

NUM [0-9]
NAME [_a-zA-Z\-\+\@\\]
CMD_RUN ^(\@[^\@]*\@)?\t\.\/[^\n]*          
CMD_S ^(\@[^\@]*\@)?\t[^\n]*
%%


{CMD_RUN}       { return CMD_RUN;}
{CMD_S}         { return CMD;}
{CMD_RUN}(\\\n[ \t]*[^\n]*)*     { update_line(); return CMD_RUN;}
{CMD_S}(\\\n[ \t]*[^\n]*)*       { update_line(); return CMD;}

"#"[^\n]*   {}

","         { return ','; }           
"?"         { return '?'; }
"!"         { return '!'; }
":"         { return ':'; }
";"         { return ';'; }
"-"         { return '-'; }
"+"         { return '+'; }
"$"         { return '$'; }
"\""        { return '"'; }
"|"         { return '|'; }
"/"         { return '/'; }
"&"         { return '&'; }
"]"         { return ']'; }
"["         { return '['; }
"("         { return '('; }
")"         { return ')'; }
"<"         { return '<'; }
">"         { return '>'; }
"{"         { return '{'; }
"}"         { return '}'; }
"`"         { return '`'; }
\'          { return '\''; }
\n          { ++line; cont = 0; return EOL;}
[ \t]+\n    { ++line; cont = 0; return EOL;}
"@"         {  }
"ifeq"      { return IFEQ;}
"ifneq"     { return IFNEQ;}
"ifdef"     { return IFDEF;}
"ifndef"    { return IFNDEF;}
"else"      { return ELSE;}
"endif"     { return ENDIF;}
^"define"   { return DEFINE;}
^"endef"    { return ENDEF;}
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
$\("error"      { handle_function();return ERROR_FUNCTION;}

^"%"({NAME}|{NUM}|[\.]|[//])*                              { return PATTERN_TARGET;}
^"."({NAME}|{NUM})*"."({NAME}|{NUM})+                  { return SFX_TARGET;}


\"[^\"]*\"                        { yylval.string = strdup(yytext); return STRING; }
\'[^\']*\'                        { yylval.string = strdup(yytext); return STRING; }
\`[^\`]*\`                        { return SHELL; }
$\(shell[^\)]*\)                  { return SHELL; }

"::="|"="                         { return VAR_DEF; }
[":"|"!"|"?"|"+"]"="              { return VAR_DEF; }

$("@"|"%"|"<"|"?"|"^"|"+"|"*")    { yylval.string = strdup(yytext);return AUTO_VAR; }



\%({NAME}|{NUM}|[\.])*         { return PATTERN;}

\\[\r]?\n[ \t]*  { ++line;}

({NAME}|{NUM})+                  { yylval.string = strdup(yytext); return NAME; }


({NAME}|{NUM}|[\.])+                 { yylval.string = strdup(yytext); return FILENAME; }
(\/|[\.\.]|[\.])?(({NAME}|{NUM}|[\.]|[\.\.])+[\/]?)+([\/]|[\/\*])?  { yylval.string = strdup(yytext); return PATH; }

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
                    ++line;
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
    snprintf(str,256,"sed -n \'%u,$ p\' %s | grep \'[^\\\\$]*[^\\\\]$\' -m1 -n | cut -d : -f 1",line,file);
    FILE *f = popen(str, "r");
    if (!feof(f)) {
         if(fgets(str,256,f) != NULL)
         {
            line += atoi(str);
            --line;
         }
    }
    pclose(f);
}

int yywrap()
{
    return 1;
}