
/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
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

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol();
    static char* lookup_symbol_type();
    static int lookup_symbol_addr();
    static int lookup_symbol_mut();
    static void dump_symbol();

    /* Global variables */
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;



    typedef struct sym{
        int index;
        char *name;
        int mut;
        char *type;
        int addr;
        int lineno;
        char *func_sig;
    } Symbol;

    static Symbol symbol_table[4][10];
    static int symbol_count[4] = {0};
    static int scope_level = -1;
    static int addr = -1;
    static int line_number = 1;
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
%type <s_val> Expression LogicalOrExpr LogicalAndExpr EqualityExpr SHIFTING AddExpr MulExpr UnaryExpr NeverGonnaGiveYouUp

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : { 
      CODEGEN("\n.method public static main([Ljava/lang/String;)V\n");
      CODEGEN(".limit stack 100\n");
      CODEGEN(".limit locals 100\n");
    } 
    {create_symbol(); printf("ininin\n");} GlobalStatementList {dump_symbol();} 
    {
      CODEGEN("return\n");
      CODEGEN(".end method\n");
    }
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
    
    | ID  NEQ ID  {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} {printf("IDENT (name=%s, address=%d)\n", $3, lookup_symbol_addr($3));} {printf("NEQ\n");}
    | ID NEQ {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} LIT  {printf("NEQ\n");}
    | LIT NEQ LIT {printf("NEQ\n");}

    | ID {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} '<' LIT {printf("LSS\n");}
    | ID {
        if(0 == strcmp(lookup_symbol_type($1), "undefined"))
            printf("error:%d: undefined: %s\n", line_number, $1);
        else
            printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} 
    '>' LIT {
        if(lookup_symbol_type($1) != $4)                                                                                                                // a09
            printf("error:%d: invalid operation: GTR (mismatched types %s and %s)\n",line_number, lookup_symbol_type($1), $4);                       // a09
        printf("GTR\n");}      // a09
;
Whilestmt
    : WHILE Ifcond Block
;

AssignStmt
    : LET ID ':' Type '=' LIT ';' {insert_symbol($2, 0, $6, line_number, "-"); 
        if(!strcmp($4, "i32")){
            CODEGEN("istore %d\n", addr);
        }
        else if (!strcmp($4, "f32")){
            CODEGEN("fstore %d\n", addr);
        }
    }
    | LET MUT ID ':' Type '=' LIT ';' {insert_symbol($3, 1, $7, line_number, "-");}
    | LET MUT ID '=' LIT ';' {insert_symbol($3, 1, $5, line_number, "-");}
    | LET MUT ID ':' Type ';' {insert_symbol($3, 1, $5, line_number, "-");}             // a05
    | ID '=' LIT ';' {
        if(0 == strcmp(lookup_symbol_type($1), "undefined"))
            printf("error:%d: undefined: %s\n", line_number, $1);
        else{
            printf("ASSIGN\n");
            if(0 == lookup_symbol_mut($1))
                printf("error:%d: cannot borrow immutable borrowed content `%s` as mutable\n", line_number, $1);
        }}
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
    : '[' Type ';' LIT ']' '=' '[' VALUE ']' ';' ;                                       // a08
VALUE
    : LIT ',' VALUE 
    | LIT
;

PrintStatement
    : PRINTLN '(' {
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");   
    } 
      PrintContent ')' ';' {
        // if(!strcmp($4, "i32")){
        //     printf("OK\n");
        //     CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n");
        // }else if(!strcmp($4, "str")){
        //     printf("WTF\n");
        //     CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        // }


        if(!strcmp($4, "i32")){
            CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n");
        }else if(!strcmp($4, "f32")){
            CODEGEN("invokevirtual java/io/PrintStream/println(F)V\n");
        }else if(!strcmp($4, "str")){
            CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }else if(!strcmp($4, "bool")){
            CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n");
        }

    }
    | PRINT '(' 
      {CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");}
      PrintContent ')' ';' 
      {CODEGEN("invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");}
PrintContent
    : LIT {$$ = $1;} 
    | Expression {$$ = $1;}
    | NEWLINE Expression{$$ = $2; ++line_number;}
    | NEWLINE Expression NEWLINE{$$ = $2; ++line_number; ++line_number;}
    | Expression NEWLINE{$$ = $1; ++line_number;}
    | NEWLINE {++line_number;}
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
    : EqualityExpr '>' SHIFTING {$$ = "bool"; printf("GTR\n");}
    | SHIFTING {$$ = $1;} ;
SHIFTING
    : SHIFTING LSHIFT AddExpr {$$ = "i32"; 
        if($1 != $3)                                                                                                                // a09
            printf("error:%d: invalid operation: LSHIFT (mismatched types %s and %s)\n",line_number, $1, $3);                       // a09
        printf("LSHIFT\n");}
    | SHIFTING RSHIFT AddExpr {$$ = "i32"; printf("RSHIFT\n");}
    | AddExpr {$$ = $1;} ;
AddExpr
    : AddExpr '+' MulExpr {
        $$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32";  
        
        if(!strcmp($1,"f32")||!strcmp($3,"f32"))CODEGEN("fadd\n");
        else CODEGEN("iadd\n");
    }
    | AddExpr '-' MulExpr {
        $$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; 
        if(!strcmp($1,"f32")||!strcmp($3,"f32"))CODEGEN("fsub\n");
        else CODEGEN("isub\n");
    }
    | MulExpr {$$ = $1;} ;
MulExpr
    : MulExpr '*' UnaryExpr {
        $$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; 
        if(!strcmp($1,"f32")||!strcmp($3,"f32"))CODEGEN("fmul\n");
        else CODEGEN("imul\n");
    }
    | MulExpr '/' UnaryExpr {
        $$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; 
        if(!strcmp($1,"f32")||!strcmp($3,"f32"))CODEGEN("fdiv\n");
        else CODEGEN("idiv\n");
    }
    | MulExpr '%' UnaryExpr {
        $$ = (!strcmp($1,"f32")||!strcmp($3,"f32"))?"f32":"i32"; 
        if(!strcmp($1,"f32")||!strcmp($3,"f32"));
        else CODEGEN("irem\n");
    }
    | UnaryExpr {$$ = $1;} ;
UnaryExpr
    : '-' UnaryExpr {$$ = $2; 
        if(!strcmp($2, "i32")){
            CODEGEN("ineg\n");
        }else if(!strcmp($2, "f32")){
            CODEGEN("fneg\n");
        }
    }
    | '!' UnaryExpr {$$ = "bool"; printf("NOT\n");}
    | NeverGonnaGiveYouUp {$$ = $1;} ;
NeverGonnaGiveYouUp
    : '(' Expression ')' {$$ = $2;} ;
    | LIT {$$ = $1;}
    | ID {
        $$ = lookup_symbol_type($1); 
        // CODEGEN("istore %d\n", lookup_symbol_addr($1));
        // CODEGEN("iload %d\n", lookup_symbol_addr($1));
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }else if(!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
        }else if(!strcmp(lookup_symbol_type($1), "str")){
            CODEGEN("aload %d\n", lookup_symbol_addr($1));
        }else if(!strcmp(lookup_symbol_type($1), "bool")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }
        printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1)); 
    }
    | LIT AS Type 
        {if(!strcmp($1, "f32") && !strcmp($3, "i32")) CODEGEN("f2i\n");                                                   // a05
        else if (!strcmp($1, "i32") && !strcmp($3, "f32")) CODEGEN("i2f\n");}                                             // a05
    | ID AS Type {printf("IDENT (name=%s, address=%d)\n", $1, lookup_symbol_addr($1));} 
        {if(!strcmp(lookup_symbol_type($1), "f32") && !strcmp($3, "i32")) CODEGEN("f2i\n");                               // a05
        else if (!strcmp(lookup_symbol_type($1), "i32") && !strcmp($3, "f32")) CODEGEN("i2f\n");}                         // a05
;

Type 
   : INT {$$ = "i32";}
   | FLOAT {$$ = "f32";}
   | BOOL {$$ = "bool";}
   | STR {$$ = "str";}
   | '&' Type {$$ = $2;}
;

LIT
    : INT_LIT {$$ = "i32"; CODEGEN("ldc %d\n", $1);}
    | FLOAT_LIT {$$ = "f32"; CODEGEN("ldc %f\n", $1);}
    | STRING_LIT {$$ = "str"; CODEGEN("ldc \"%s\"\n", $1);}
    | '"' STRING_LIT '"' {$$ = "str"; CODEGEN("ldc \"%s\"\n", $2);}
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
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");

    /* Symbol table init */
    // Add your code

    yylineno = 0;
    yyparse();

    /* Symbol table dump */
    // Add your code

	printf("Total lines: %d\n", yylineno);
    fclose(fout);
    fclose(yyin);

    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
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