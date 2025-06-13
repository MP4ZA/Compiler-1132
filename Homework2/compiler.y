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
    static int lookup_symbol_mut();
    static void dump_symbol();
    // static void write();
    // static int read();

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

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type
%type <s_val> LIT
%type <s_val> PrintContentList PrintContent
%type <s_val> Expression LogicalOrExpr LogicalAndExpr EqualityExpr SHIFTING AddExpr MulExpr UnaryExpr Atom
%type <s_val> Operand
/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList ;
GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement ;
GlobalStatement
    : FunctionDeclStmt
    | NEWLINE {++line_number;} ;    // 函式外的空白行
FunctionDeclStmt
    : FUNC 
      ID {printf("func: %s\n", $2);} 
      '(' ')' 
      {insert_symbol($2, -1, "func",  line_number, "(V)V");} 
      Block ;
Block
    : {create_symbol();}
      '{' StatementList '}'
      {dump_symbol();} ;
StatementList
    : StatementList Statement 
    | /* empty */ ;
Statement
    : AssignStmt
    | PrintStatement
    | Block
    | Ifstmt
    | Whilestmt
    | NEWLINE {++line_number;}
;

Ifstmt
    : IF Condition Block
    | ELSE Block ;
Whilestmt
    : WHILE Condition Block ;
Condition
    : Expression
    | Operand '>' Operand 
    {
        if(lookup_symbol_type($1) != $3)                                                                                                                // a09
            printf("error:%d: invalid operation: GTR (mismatched types %s and %s)\n",line_number, lookup_symbol_type($1), $3);                       // a09
    }
    {printf("GTR\n");}      // a09
;

AssignStmt
    : LET ID ':' Type '=' LIT ';' {insert_symbol($2, 0, $6, line_number, "-");}
    | LET MUT ID ':' Type '=' LIT ';' {insert_symbol($3, 1, $7, line_number, "-");}
    | LET MUT ID '=' LIT ';' {insert_symbol($3, 1, $5, line_number, "-");}
    | LET MUT ID ':' Type ';' {insert_symbol($3, 1, $5, line_number, "-");}             // a05
    | ID ADD_ASSIGN LIT ';' {printf("ADD_ASSIGN\n");}
    | ID SUB_ASSIGN LIT ';' {printf("SUB_ASSIGN\n");}
    | ID MUL_ASSIGN LIT ';' {printf("MUL_ASSIGN\n");}
    | ID DIV_ASSIGN LIT ';' {printf("DIV_ASSIGN\n");}
    | ID REM_ASSIGN LIT ';' {printf("REM_ASSIGN\n");}
    | ID '=' Expression ';' {
        if(0 == strcmp(lookup_symbol_type($1), "undefined"))
            printf("error:%d: undefined: %s\n", line_number, $1);
        else{
            printf("ASSIGN\n");
            if(0 == lookup_symbol_mut($1))
                printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", line_number, $1);
        }}
    | LET ID ':' ARRAY {insert_symbol($2, 0, "array", line_number, "-");}              // a08
;

ARRAY
    : '[' Type ';' INT_LIT {printf("INT_LIT %d\n", $4);} ']' '=' '[' elem ']' ';' ;                                       // a08
elem
    : LIT ',' elem 
    | LIT
;

PrintStatement
    : PRINTLN '(' PrintContentList ')' ';' {printf("PRINTLN %s\n", $3); }
    | PRINT '(' PrintContentList ')' ';' {printf("PRINT %s\n", $3); };
PrintContentList
    : PrintContentList PrintContent {$$ = !strcmp($2,"bruh")?$1:$2;}
    | /* empty */ {$$ = "bruh";}
;
PrintContent
    : Expression {$$ = $1;}
    | NEWLINE {$$ = "bruh"; ++line_number;}
    | ID '[' INT_LIT ']' {$$ = "array"; printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));  printf("INT_LIT %d\n", $3);}
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
    : EqualityExpr '>' SHIFTING 
    {
        $$ = "bool"; 
        // printf("%s %s\n",lookup_symbol_type($1), lookup_symbol_type($3));
        // if(lookup_symbol_type($1) != lookup_symbol_type($3))                                                                                                                // a09
        //     printf("error:%d: invalid operation: GTR (mismatched types %s and %s)\n",line_number, lookup_symbol_type($1), lookup_symbol_type($3));                       // a09
        printf("GTR\n"); 
    }
    | EqualityExpr '<' SHIFTING {$$ = "bool"; printf("LSS\n");}
    | EqualityExpr EQL SHIFTING {$$ = "bool"; printf("EQL\n");}
    | EqualityExpr NEQ SHIFTING {$$ = "bool"; printf("EQL\n");}
    | SHIFTING {$$ = $1;} ;
SHIFTING
    : SHIFTING LSHIFT AddExpr {$$ = "i32"; 
        if($1 != $3)                                                                                                                // a09
            printf("error:%d: invalid operation: LSHIFT (mismatched types %s and %s)\n",line_number, $1, $3);                       // a09
        printf("LSHIFT\n");}
    | SHIFTING RSHIFT AddExpr {$$ = "i32"; printf("RSHIFT\n");}
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
    | Atom {$$ = $1;} ;
Atom
    : '(' Expression ')' {$$ = $2;} ;
    | Operand
    | Operand AS Type 
        {if(!strcmp($1, "f32") && !strcmp($3, "i32")) printf("f2i\n");                                                   // a05
        else if (!strcmp($1, "i32") && !strcmp($3, "f32")) printf("i2f\n");}                                             // a05
;

Type 
   : INT {$$ = "i32";}
   | FLOAT {$$ = "f32";}
   | BOOL {$$ = "bool";}
   | STR {$$ = "str";}
   | '&' Type {$$ = $2;}
;

Operand
    : LIT
    | ID 
    {
        if(0 == strcmp(lookup_symbol_type($1), "undefined")){
            printf("error:%d: undefined: %s\n", line_number, $1);
            $$ = "undefined";
        }else{
            $$ = lookup_symbol_type($1);
            printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));
        }
    };
LIT
    : INT_LIT               {$$ = "i32";    printf("INT_LIT %d\n", $1);}
    | FLOAT_LIT             {$$ = "f32";    printf("FLOAT_LIT %f\n", $1);}
    | STRING_LIT            {$$ = "str";    printf("STRING_LIT %s\n", $1);}
    | '"' STRING_LIT '"'    {$$ = "str";    printf("STRING_LIT \"%s\"\n", $2);}
    | '"' '"'               {$$ = "str";    printf("STRING_LIT \"\"\n");}
    | TRUE                  {$$ = "bool";   printf("bool TRUE\n");}
    | FALSE                 {$$ = "bool";   printf("bool FALSE\n");}
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

    create_symbol();
 
    yylineno = 0;
    yyparse();

    dump_symbol();

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
    char* SameType = "undefined";
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
    int addregera = -2147483648;
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

static int lookup_symbol_mut(char* ID_name) {
    int mutable = 0;
    for(int i=scope_level; i>=0;i--){
        for(int j =0; j<symbol_count[i]; j++){
            if(0 ==  strcmp(ID_name,symbol_table[i][j].name)){
                mutable = symbol_table[i][j].mut;
                return mutable;
            }
        }
    }
    return mutable;
}

static void dump_symbol() {
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
}