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
    static void lookup_symbol();
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
    static int addr = -1;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
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
%token <s_val> ID
/* %token <s_val> ID */

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type
%type <s_val> LIT

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
;

GlobalStatement
    : FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : Type ID '(' ')' {
        printf("%s: %s\n",$1, $2);
        insert_symbol($2, -1, $1, 0, 0, "(V)V");
        create_symbol();
    } Block {dump_symbol();}
;

Block
    : '{' StatementList '}'
;

StatementList
    : StatementList Statement
    | /* empty */
;

Statement
    : PrintStatement
    | LETStatement
    | NEWLINE
;

LETStatement
    : LET ID ':' Type '=' LIT ';'
;

PrintStatement
    : PRINTLN '(' PrintContent ')' ';'
    | PRINT '(' PrintContent ')' ';'
;

PrintContent
    : '"' STRING_LIT '"' {printf("PRINTLN str\n");}
    | Expression {printf("PRINTLN Type\n");}
;


////////////////////////////////////////////////////////////
Expression
    : LogicalOrExpr ;

LogicalOrExpr
    : LogicalOrExpr LOR LogicalAndExpr { printf("LOR\n"); }
    | LogicalAndExpr ;

LogicalAndExpr
    : LogicalAndExpr LAND EqualityExpr { printf("LAND\n"); }
    | EqualityExpr ;

EqualityExpr
    : EqualityExpr '>' AddExpr { printf("GTR\n"); }
    | AddExpr ;

AddExpr
    : AddExpr '+' MulExpr { printf("ADD\n"); }
    | AddExpr '-' MulExpr { printf("SUB\n"); }
    | MulExpr ;

MulExpr
    : MulExpr '*' UnaryExpr { printf("MUL\n"); }
    | MulExpr '/' UnaryExpr { printf("DIV\n"); }
    | MulExpr '%' UnaryExpr { printf("REM\n"); }
    | UnaryExpr ;

UnaryExpr
    : '-' UnaryExpr { printf("NEG\n"); }
    | '!' UnaryExpr { printf("NOT\n"); }
    | Primary ;

Primary
    : '(' Expression ')'
    | LIT
    | ID
    | TRUE
    | FALSE ;

////////////////////////////////////////////////////////////
Arithmetic
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
    | TRUE | FALSE
    | ID
    | LIT
    | '(' Arithmetic ')' 
    /* | Arithmetic '+' '(' Arithmetic ')' 
    | Arithmetic '-' '(' Arithmetic ')'
    | Arithmetic '*' '(' Arithmetic ')'
    | Arithmetic '/' '(' Arithmetic ')'
    | Arithmetic '%' '(' Arithmetic ')'
    | '(' Arithmetic ')'  '+' Arithmetic
    | '(' Arithmetic ')'  '-' Arithmetic
    | '(' Arithmetic ')'  '*' Arithmetic
    | '(' Arithmetic ')'  '/' Arithmetic
    | '(' Arithmetic ')'  '%' Arithmetic */
;

Type 
   : INT {$$ = "i32";}
   | FLOAT {$$ = "f32";}
   | BOOL {$$ = "bool";}
   | STR {$$ = "str";}
   | ID {$$ = "ID";}
   | FUNC {$$ = "func";}
   | STRING_LIT {$$ = "STRING_LIT";}
   | PRINTLN {$$ = "str";}
;

LIT
    : INT_LIT {printf("INT_LIT %d\n", $1);}
    | FLOAT_LIT {printf("FLOAT_LIT %f\n", $1);}
    | STRING_LIT {printf("STRING_LIT %s\n", $1);}
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

static void insert_symbol(char* name, int mut, char *type, int addr, int lineno, char *func_sig) {
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, scope_level);

    int index = symbol_count[scope_level];
    symbol_table[scope_level][index].index = index;
    symbol_table[scope_level][index].name = strdup(name);
    /* symbol_table[scope_level][index].mut = mut;
    symbol_table[scope_level][index].type = strdup(type);
    symbol_table[scope_level][index].addr = addr;
    symbol_table[scope_level][index].lineno = lineno;
    symbol_table[scope_level][index].func_sig = strdup(func_sig); */
    symbol_count[scope_level]++;
}

static void lookup_symbol() {
}

static void dump_symbol() {
    /* printf("\n> Dump symbol table (scope level: %d)\n", 0);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            0, "name", 0, "type", 0, 0, "func_sig"); */

    for (int level = scope_level; level >= 0; level--) {
        printf("\n> Dump symbol table (scope level: %d)\n", level);
        printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
            "Index", "Name", "Mut", "Type", "Addr", "Lineno", "Func_sig");

        for (int i = 0; i < symbol_count[level]; i++) {
            Symbol s = symbol_table[level][i];
            printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
                s.index, s.name, s.mut, s.type, s.addr, s.lineno, s.func_sig);
        }
    }

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
