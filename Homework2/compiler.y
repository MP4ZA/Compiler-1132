/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h"
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol();
    static char* lookup_symbol_type();
    static int lookup_symbol_addr();
    static void dump_symbol();

    /* Global variables */
    bool HAS_ERROR = false;

    typedef struct sym{
        int index;
        char *name;
        int mut;
        char *type;
        int addr;
        int lineno;
        char *func_sig;
    } Symbol;

    static Symbol symbol_table[4][10];  // [scope][Index]
    static int symbol_count[4] = {0};
    static int scope_level = -1;
    static int addr = -2;
    static int line_number = 1;
%};

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    bool b_val;
    /* ... */
};

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
/* %token TRUE FALSE */
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> IDENT
%token <b_val> TRUE
%token <b_val> FALSE
%token <s_val> ID
/* %token <s_val> ID */

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type
%type <s_val> LIT
%type <s_val> PrintContent
%type <s_val> Expression LogicalOrExpr LogicalAndExpr EqualityExpr AddExpr MulExpr UnaryExpr NeverGonnaGiveYouUp

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : {create_symbol();} GlobalStatementList {dump_symbol();} 
;
GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement 
    | NEWLINE {++line_number;}
;
GlobalStatement
    : FunctionDeclStmt
    | NEWLINE {++line_number;}
;


FunctionDeclStmt
    : FUNC ID {printf("func: %s\n", $2);} '(' ')' {insert_symbol($2, -1, "func",  line_number, "(V)V");} 
     Block ;
Block
    : {create_symbol();} '{' StatementList '}' {dump_symbol();};
StatementList
    : StatementList Statement 
    | /* empty */  ;
Statement
    : AssignStmt
    | PrintStatement
    | NEWLINE {++line_number;}
    | Block
    | Ifstmt
    | Whilestmt
;

Ifstmt
    : IF Ifcond Block
    | ELSE Block
;
Ifcond
    : ID  EQL ID  {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} {printf("IDENT (name=%s, address=%d)\n", $3, lookup_symbol_addr($3));} {printf("EQL\n");}
    | ID EQL {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} LIT  {printf("EQL\n");}
    | LIT EQL LIT {printf("EQL\n");}
    | ID {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} '<' LIT {printf("LSS\n");}
;
Whilestmt
    : WHILE Ifcond Block
;

AssignStmt
    : LET ID ':' Type '=' LIT ';' {insert_symbol($2, 0, $6, line_number, "-");}
    | LET MUT ID ':' Type '=' LIT ';' {insert_symbol($3, 1, $7, line_number, "-");}
    | LET MUT ID '=' LIT ';' {insert_symbol($3, 1, $5, line_number, "-");}
    | LET MUT ID ':' Type ';' {insert_symbol($3, 1, $5, line_number, "-");}             // a05
    | ID '=' LIT ';' {printf("ASSIGN\n");}
    | ID ADD_ASSIGN LIT ';' {printf("ADD_ASSIGN\n");}
    | ID SUB_ASSIGN LIT ';' {printf("SUB_ASSIGN\n");}
    | ID MUL_ASSIGN LIT ';' {printf("MUL_ASSIGN\n");}
    | ID DIV_ASSIGN LIT ';' {printf("DIV_ASSIGN\n");}
    | ID REM_ASSIGN LIT ';' {printf("REM_ASSIGN\n");}
    | ID '=' Expression ';'
;

PrintStatement
    : PRINTLN '(' PrintContent ')' ';' {printf("PRINTLN %s\n", $3); }
    | PRINT '(' PrintContent ')' ';' {printf("PRINT %s\n", $3); };
PrintContent
    : LIT {$$ = $1;} 
    /* | ID {$$ = lookup_symbol_type($1); printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1)); } */
    | Expression {$$ = $1;}
    | NEWLINE Expression{$$ = $2; ++line_number;}
    | NEWLINE Expression NEWLINE{$$ = $2; ++line_number; ++line_number;}
    | Expression NEWLINE{$$ = $1; ++line_number;}
    | NEWLINE {++line_number;}
;

Expression
    : LogicalOrExpr ;
LogicalOrExpr
    : LogicalOrExpr LOR LogicalAndExpr {$$ = "bool"; printf("LOR\n");}
    | LogicalAndExpr {$$ = $1;} ;
LogicalAndExpr
    : LogicalAndExpr LAND EqualityExpr {$$ = "bool"; printf("LAND\n");}
    | EqualityExpr {$$ = $1;} ;
EqualityExpr
    : EqualityExpr '>' AddExpr {$$ = "bool"; printf("GTR\n");}
    | AddExpr {$$ = $1;} ;
AddExpr
    : AddExpr '+' MulExpr {$$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; printf("ADD\n");}
    | AddExpr '-' MulExpr {$$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; printf("SUB\n");}
    | MulExpr {$$ = $1;} ;
MulExpr
    : MulExpr '*' UnaryExpr {$$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; printf("MUL\n");}
    | MulExpr '/' UnaryExpr {$$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; printf("DIV\n");}
    | MulExpr '%' UnaryExpr {$$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; printf("REM\n");}
    | UnaryExpr {$$ = $1;} ;
UnaryExpr
    : '-' UnaryExpr {$$ = $2; printf("NEG\n");}
    | '!' UnaryExpr {$$ = "bool"; printf("NOT\n");}
    | NeverGonnaGiveYouUp {$$ = $1;} ;
NeverGonnaGiveYouUp
    : '(' Expression ')' {$$ = $2;} ;
    | LIT {$$ = $1;}
    | ID {$$ = lookup_symbol_type($1); printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1)); }
;

/* Arithmetic
    : Arithmetic '+' Arithmetic {printf("ADD\n");}
    | Arithmetic '-' Arithmetic {printf("SUB\n");}
    | Arithmetic '*' Arithmetic {printf("MUL\n");}
    | Arithmetic '/' Arithmetic {printf("DIV\n");}
    | Arithmetic '%' Arithmetic {printf("REM\n");}
    | Arithmetic '>' Arithmetic {printf("GTR\n");}
    | Arithmetic LOR Arithmetic {printf("LOR\n");}
    | Arithmetic LAND Arithmetic {printf("LAND\n");}
    | '!' Arithmetic {printf("NOT\n");}
    | '-' Arithmetic {printf("NEG\n");}
    | ID
    | LIT
    | '(' Arithmetic ')' 
    | Arithmetic '+' '(' Arithmetic ')' 
    | Arithmetic '-' '(' Arithmetic ')'
    | Arithmetic '*' '(' Arithmetic ')'
    | Arithmetic '/' '(' Arithmetic ')'
    | Arithmetic '%' '(' Arithmetic ')'
    | '(' Arithmetic ')'  '+' Arithmetic
    | '(' Arithmetic ')'  '-' Arithmetic
    | '(' Arithmetic ')'  '*' Arithmetic
    | '(' Arithmetic ')'  '/' Arithmetic
    | '(' Arithmetic ')'  '%' Arithmetic 
; */

Type 
   : INT {$$ = "i32";}
   | FLOAT {$$ = "f32";}
   | BOOL {$$ = "bool";}
   | STR {$$ = "str";}
   | '&' Type {$$ = $2;}
;

LIT
    : INT_LIT {$$ = "i32"; printf("INT_LIT %d\n", $1);}
    | FLOAT_LIT {$$ = "f32"; printf("FLOAT_LIT %f\n", $1);}
    | STRING_LIT {$$ = "str"; printf("STRING_LIT %s\n", $1);}
    | '"' STRING_LIT '"' {$$ = "str"; printf("STRING_LIT \"%s\"\n", $2);}
    | '"' '"' {$$ = "str"; printf("STRING_LIT \"\"\n");}
    | TRUE {$$ = "bool";printf("bool TRUE\n");}
    | FALSE {$$ = "bool";printf("bool FALSE\n");}
;

%%


/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 0;
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", ++scope_level);

}

static void insert_symbol(char* name, int mut, char *type, int lineno, char *func_sig) {
    int index = symbol_count[scope_level];
    symbol_table[scope_level][index].index = index;
    symbol_table[scope_level][index].name = strdup(name);
    symbol_table[scope_level][index].mut = mut;
    symbol_table[scope_level][index].type = strdup(type);
    symbol_table[scope_level][index].addr = ++addr;
    symbol_table[scope_level][index].lineno = lineno;
    symbol_table[scope_level][index].func_sig = strdup(func_sig);
    symbol_count[scope_level]++;

    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, scope_level);
}

static char* lookup_symbol_type(char* ID_name) {
    char* SameType = NULL;
    for(int i=scope_level; i>=0;i--){
        for(int j =0; j<symbol_count[i]; j++){
            if(0 ==  strcmp(ID_name,symbol_table[i][j].name)){
                SameType = symbol_table[i][j].type;
                return SameType;
            }
        }
    }
    return SameType;
}

static int lookup_symbol_addr(char* ID_name) {
    int addregera = -1;
    for(int i=scope_level; i>=0;i--){
        for(int j =0; j<symbol_count[i]; j++){
            if(0 ==  strcmp(ID_name,symbol_table[i][j].name)){
                addregera = symbol_table[i][j].addr;
                return addregera;
            }
        }
    }
    return addregera;
}

static void dump_symbol() {
    /* printf("\n> Dump symbol table (scope level: %d)\n", 0);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            0, "name", 0, "type", 0, 0, "func_sig"); */


    int level = scope_level;
    printf("\n> Dump symbol table (scope level: %d)\n", level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut", "Type", "Addr", "Lineno", "Func_sig");
    for (int i = 0; i < symbol_count[level]; i++) {
        Symbol s = symbol_table[level][i];
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            s.index, s.name, s.mut, s.type, s.addr, s.lineno, s.func_sig);
    }
    symbol_count[level] = 0;
    scope_level--;



    /* for (int level = scope_level; level >= 0; level--) {
        printf("\n> Dump symbol table (scope level: %d)\n", level);
        printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
            "Index", "Name", "Mut", "Type", "Addr", "Lineno", "Func_sig");
        for (int i = 0; i < symbol_count[level]; i++) {
            Symbol s = symbol_table[level][i];
            printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
                s.index, s.name, s.mut, s.type, s.addr, s.lineno, s.func_sig);
        }
    } */

    /* 
    // free(): double free detected in tcache 2
    // Aborted (core dumped)
    for(int i=0;i<4;i++){
        for(int j=0;j<symbol_count[i];j++){
            free(symbol_table[i][j].name);
            free(symbol_table[i][j].type);
            free(symbol_table[i][j].func_sig);
        }
    } 
    */
}
