
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
    static int toOne = 1;
    static int notend = 1;
    
    static int L_True = 1;
    static int L_false = 1;
    static int L_if_exit = 1;
    static int L_exit = 1;

    static int L_right = 1;
    static int L_if_false = 1;
    static int L_if_True = 1;
    static int end = 1;

    static int True_first = 1;
    static int True_second = 1;
    static int False_second = 1;
    static int the_end = 1;

    static int whilewhile = 1;
    static int end_whilewhile = 1;

    static int if_exit = 1;
    static int condition_true = 1;

    static int LSS_exit = 1;
    static int LSS_true = 1;

    static int endif = 1;

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
    bool b_val;
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
    : {CODEGEN("\n.method public static main([Ljava/lang/String;)V\n");
       CODEGEN(".limit stack 100\n");
       CODEGEN(".limit locals 100\n");} 
       {create_symbol();} GlobalStatementList {dump_symbol();} 
    { CODEGEN("return\n");
      CODEGEN(".end method\n"); } 
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
    : FUNC ID '(' ')' {insert_symbol($2, -1, "func",  line_number, "(V)V");}
     Block ;
Block
    : {create_symbol();} '{' StatementList '}' {dump_symbol();}
;
StatementList
    : StatementList Statement 
    | /* empty */  
;
Statement
    : AssignStmt
    | PrintStatement
    | NEWLINE {++line_number;}
    | Block
    | Ifstmt
    | Whilestmt
;

Ifstmt
    : IF 
    Ifcond 
    {CODEGEN("ifeq endif%d\n", endif);}
    Block 
    { CODEGEN("goto endif%d\n", endif+1);
      CODEGEN("endif%d:\n", endif++); }
    | ELSE 
    Block 
    { CODEGEN("endif%d:\n", endif); }
;
Ifcond
    : ID EQL ID  
    {
        CODEGEN("iload %d\n", lookup_symbol_addr($1));
        CODEGEN("iload %d\n", lookup_symbol_addr($3));
        CODEGEN("if_icmpeq condition_true%d\n", condition_true);
        CODEGEN("    iconst_0\n");
        CODEGEN("    goto if_exit%d\n", if_exit);
        CODEGEN("condition_true%d:\n", condition_true++);
        CODEGEN("    iconst_1\n");
        CODEGEN("if_exit%d\n", if_exit++);
    } 
    | ID EQL LIT 
    {
        CODEGEN("iload %d\n", lookup_symbol_addr($1));
        CODEGEN("if_icmpeq condition_true%d\n", condition_true);
        CODEGEN("    iconst_0\n");
        CODEGEN("    goto if_exit%d\n", if_exit);
        CODEGEN("condition_true%d:\n", condition_true++);
        CODEGEN("    iconst_1\n");
        CODEGEN("if_exit%d:\n", if_exit++);
    } 
    | ID NEQ ID
    | ID NEQ LIT {
        CODEGEN("iload %d\n", lookup_symbol_addr($1));
        CODEGEN("if_icmpne condition_true%d\n", condition_true);
        CODEGEN("    iconst_0\n");
        CODEGEN("    goto if_exit%d\n", if_exit);
        CODEGEN("condition_true%d:\n", condition_true++);
        CODEGEN("    iconst_1\n");
        CODEGEN("if_exit%d:\n", if_exit++); }  
    | LIT NEQ LIT
    | ID {
        CODEGEN("iload %d\n", lookup_symbol_addr($1));
    } 
    '<' LIT
    {
        CODEGEN("if_icmplt LSS_true%d\n", LSS_true);
        CODEGEN("    iconst_0\n");
        CODEGEN("    goto LSS_exit%d\n", LSS_exit);
        CODEGEN("LSS_true%d:\n", LSS_true++);
        CODEGEN("    iconst_1\n");
        CODEGEN("LSS_exit%d:\n", LSS_exit++);
    }
;
Whilestmt
    : WHILE 
    {
        CODEGEN("whilewhile%d:\n", whilewhile);   
    }
    Ifcond 
    {
        CODEGEN("ifeq end_whilewhile%d\n", end_whilewhile);
    }
    Block
    {
        CODEGEN("goto whilewhile%d\n", whilewhile);
        CODEGEN("end_whilewhile%d:\n", end_whilewhile++);
        whilewhile++;
    }
;

AssignStmt
    : LET ID ':' Type '=' LIT ';' {insert_symbol($2, 0, $6, line_number, "-"); 
        if(!strcmp($4, "i32")){
            CODEGEN("istore %d\n", addr);
        }
        else if (!strcmp($4, "f32")){
            CODEGEN("fstore %d\n", addr);
        }else if (!strcmp($4, "str")){
            CODEGEN("astore %d\n", addr);
        }else if (!strcmp($4, "bool")){
            CODEGEN("istore %d\n", addr);
        }
    }
    | LET MUT ID ':' Type '=' LIT ';' {insert_symbol($3, 1, $7, line_number, "-");
        if(!strcmp($5, "i32")){
            CODEGEN("istore %d\n", addr);
        }else if (!strcmp($5, "f32")){
            CODEGEN("fstore %d\n", addr);
        }else if (!strcmp($5, "str")){
            CODEGEN("astore %d\n", addr);
        }else if (!strcmp($5, "bool")){
            CODEGEN("istore %d\n", addr);
        }
    }
    | LET MUT ID '=' LIT ';' {insert_symbol($3, 1, $5, line_number, "-");
        if(!strcmp($5, "i32")){
            CODEGEN("istore %d\n", addr);
        }else if (!strcmp($5, "f32")){
            CODEGEN("fstore %d\n", addr);
        }else if (!strcmp($5, "str")){
            CODEGEN("astore %d\n", addr);
        }else if (!strcmp($5, "bool")){
            CODEGEN("istore %d\n", addr);
        }
    }
    | LET MUT ID ':' Type ';' {insert_symbol($3, 1, $5, line_number, "-");}
    | ID '=' LIT ';' {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fstore %d\n", lookup_symbol_addr($1));
        }else if (!strcmp(lookup_symbol_type($1), "str")){
            CODEGEN("astore %d\n", lookup_symbol_addr($1));
        }else if (!strcmp(lookup_symbol_type($1), "bool")){
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }    
    }
    | ID ADD_ASSIGN LIT ';' {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
            CODEGEN("iadd\n");
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
            CODEGEN("fadd\n");
            CODEGEN("fstore %d\n", lookup_symbol_addr($1));
        }
    }
    | ID 
    {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
        }
    }
    SUB_ASSIGN LIT ';' 
    {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("isub\n");
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fsub\n");
            CODEGEN("fstore %d\n", lookup_symbol_addr($1));
        }
    }
    | ID MUL_ASSIGN LIT ';' {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
            CODEGEN("imul\n");
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
            CODEGEN("fmul\n");
            CODEGEN("fstore %d\n", lookup_symbol_addr($1));
        }
    }
    | ID 
    {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
        }
    }    
    DIV_ASSIGN LIT ';' 
    {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("idiv\n");
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fdiv\n");
            CODEGEN("fstore %d\n", lookup_symbol_addr($1));
        }
    }
    | ID 
    {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }
        else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
        }
    }  
    REM_ASSIGN LIT ';' 
    {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("irem\n");
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }
    }
    | ID '=' Expression ';' {
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }else if (!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fstore %d\n", lookup_symbol_addr($1));
        }else if (!strcmp(lookup_symbol_type($1), "str")){
            CODEGEN("astore %d\n", lookup_symbol_addr($1));
        }else if (!strcmp(lookup_symbol_type($1), "bool")){
            CODEGEN("istore %d\n", lookup_symbol_addr($1));
        }
    }
;

PrintStatement
    : PRINTLN '(' {
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");   
    } 
      PrintContent ')' ';' {
        if(!strcmp($4, "i32")){
            CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n");
        }else if(!strcmp($4, "f32")){
            CODEGEN("invokevirtual java/io/PrintStream/println(F)V\n");
        }else if(!strcmp($4, "str")){
            CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }else if(!strcmp($4, "bool")){
            int cur = toOne++;
            int end = notend++;
            CODEGEN("ifeq print_false_%d\n", cur);
            CODEGEN("ldc \"true\"\n");
            CODEGEN("goto print_end_%d\n", end);
            CODEGEN("print_false_%d:\n", cur);
            CODEGEN("ldc \"false\"\n");
            CODEGEN("print_end_%d:\n", end);
            CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }
    }
    | PRINT '(' {
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
    }
      PrintContent ')' ';' {
        if(!strcmp($4, "i32")){
            CODEGEN("invokevirtual java/io/PrintStream/println(I)V\n");
        }else if(!strcmp($4, "f32")){
            CODEGEN("invokevirtual java/io/PrintStream/println(F)V\n");
        }else if(!strcmp($4, "str")){
            CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }else if(!strcmp($4, "bool")){
            int cur = toOne++;
            int end = notend++;
            CODEGEN("ifeq print_false_%d\n", cur);
            CODEGEN("ldc \"true\"\n");
            CODEGEN("goto print_end_%d\n", end);
            CODEGEN("print_false_%d:\n", cur);
            CODEGEN("ldc \"false\"\n");
            CODEGEN("print_end_%d:\n", end);
            CODEGEN("invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }
    }
PrintContent
    : LIT {$$ = $1;} 
    | Expression {$$ = $1;}
    | NEWLINE Expression{$$ = $2; ++line_number;}
    | NEWLINE Expression NEWLINE{$$ = $2; ++line_number; ++line_number;}
    | Expression NEWLINE{$$ = $1; ++line_number;}
    | NEWLINE {++line_number;}
    | ID '[' INT_LIT ']' {$$ = "array";}
;

Expression
    : LogicalOrExpr ;
LogicalOrExpr
    : LogicalOrExpr LOR LogicalAndExpr {
        $$ = "bool"; 
        CODEGEN("ifne True_first%d\n", True_first);
        CODEGEN("ifne True_second%d\n", True_second);
        CODEGEN("goto False_second%d\n", False_second);
        CODEGEN("True_first%d:\n", True_first++);
        CODEGEN("    pop\n");
        CODEGEN("True_second%d:\n", True_second++);
        CODEGEN("    iconst_1\n");
        CODEGEN("    goto the_end%d\n", the_end);
        CODEGEN("False_second%d:\n", False_second++);
        CODEGEN("    iconst_0\n");
        CODEGEN("the_end%d:\n", the_end++);
    }
    | LogicalAndExpr {$$ = $1;} ;
LogicalAndExpr
    : LogicalAndExpr LAND EqualityExpr {
        $$ = "bool"; 
        CODEGEN("    ifne L_right%d\n", L_right);
        CODEGEN("    pop\n");
        CODEGEN("    goto L_if_false%d\n", L_if_false);
        CODEGEN("L_right%d:\n", L_right++);
        CODEGEN("    ifne L_if_True%d\n", L_if_True);
        CODEGEN("    goto L_if_false%d\n", L_if_false);
        CODEGEN("L_if_True%d:\n", L_if_True++);
        CODEGEN("    iconst_1\n");
        CODEGEN("    goto end%d\n", end);
        CODEGEN("L_if_false%d:\n", L_if_false++);
        CODEGEN("    iconst_0\n");
        CODEGEN("end%d:\n", end++);
    }
    | EqualityExpr {$$ = $1;} ;
EqualityExpr
    : EqualityExpr '>' SHIFTING {
        $$ = "bool"; 
        if(!strcmp($1,"f32")||!strcmp($3,"f32")){
            CODEGEN("fcmpl\n");
            CODEGEN("ifle L_false%d\n", L_false);
            CODEGEN("    iconst_1\n");
            CODEGEN("    goto L_exit%d\n",L_exit);
            CODEGEN("L_false%d:\n",L_false++);
            CODEGEN("    iconst_0\n");
            CODEGEN("L_exit%d:\n", L_exit++); 
        }else{
            CODEGEN("if_icmpgt L_True%d\n", L_True);
            CODEGEN("L_false%d:\n", L_false++);
            CODEGEN("   iconst_0\n");
            CODEGEN("   goto L_if_exit%d\n", L_if_exit);
            CODEGEN("L_True%d:\n", L_True++);
            CODEGEN("   iconst_1\n");
            CODEGEN("L_if_exit%d:\n", L_if_exit++);
        }
    }
    | SHIFTING {$$ = $1;} ;
SHIFTING
    : SHIFTING LSHIFT AddExpr {$$ = "i32"; 
        if($1 != $3)   
            printf("error:%d: invalid operation: LSHIFT (mismatched types %s and %s)\n",line_number, $1, $3);
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
    | '!' UnaryExpr {
        $$ = "bool"; 
        CODEGEN("ifeq toOne_%d\n", toOne);
        CODEGEN("    iconst_0\n");
        CODEGEN("    goto notend_%d\n", notend);
        CODEGEN("toOne_%d:\n", toOne++);
        CODEGEN("    iconst_1\n");
        CODEGEN("    goto notend_%d\n", notend);
        CODEGEN("notend_%d:\n", notend++);

    }
    | NeverGonnaGiveYouUp {$$ = $1;} ;
NeverGonnaGiveYouUp
    : '(' Expression ')' {$$ = $2;} ;
    | LIT {$$ = $1;}
    | ID {
        $$ = lookup_symbol_type($1); 
        if(!strcmp(lookup_symbol_type($1), "i32")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }else if(!strcmp(lookup_symbol_type($1), "f32")){
            CODEGEN("fload %d\n", lookup_symbol_addr($1));
        }else if(!strcmp(lookup_symbol_type($1), "str")){
            CODEGEN("aload %d\n", lookup_symbol_addr($1));
        }else if(!strcmp(lookup_symbol_type($1), "bool")){
            CODEGEN("iload %d\n", lookup_symbol_addr($1));
        }
    }
    | LIT AS Type 
        {
            if(!strcmp($1, "f32") && !strcmp($3, "i32")){
                $$ = "i32";
                CODEGEN("f2i\n");
            }
            else if (!strcmp($1, "i32") && !strcmp($3, "f32")){
                $$ = "f32";
                CODEGEN("i2f\n");
            } 
        }
    | ID AS Type
        {
            if(!strcmp(lookup_symbol_type($1), "f32") && !strcmp($3, "i32")) {
                $$ = "i32";
                CODEGEN("fload %d\n",lookup_symbol_addr($1));
                CODEGEN("f2i\n");  
            }
            else if (!strcmp(lookup_symbol_type($1), "i32") && !strcmp($3, "f32")) {
                $$ = "f32";
                CODEGEN("iload %d\n",lookup_symbol_addr($1));
                CODEGEN("i2f\n");
            }
        }
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
    | '"' '"' {$$ = "str";  CODEGEN("ldc \"\"\n");}
    | TRUE {$$ = "bool"; CODEGEN("iconst_1\n");}
    | FALSE {$$ = "bool"; CODEGEN("iconst_0\n");}
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
static void dump_symbol() {
    int level = scope_level;
    symbol_count[level] = 0;
    scope_level--;
}