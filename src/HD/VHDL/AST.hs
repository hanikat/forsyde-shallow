-- A VHDL 93 AST subset, coded so that it can be easy to extend, 
-- please see doc/VHDL/vhdl93-syntax.html as reference 
-- in order to extend it (this AST is based on that grammar)

-- This AST is aimed at code generation not parsing, and thus, 
-- it was simplified
-- The incompatibilities or simplifications from the standard
-- are properly commented

-- FIXME: shouldn't I use records instead of bare algebraic types?
-- FIXME: shouldn't I remove unused type redefinitions?
-- FIXME: It would maybe be a good idea to create a sequence ADT which
--        guaranteed to hold at least one element (i.e. the grammar
--        has some cases such as "choices ::= choice | {choice}"
--        which are not well represented as "[Choice]", 
--        "Choices Choice  (Maybe [Choice])" is not easy to handle either
--        and thus, it was discarded.

module HD.VHDL.AST where
import Data.Char
import Data.Maybe (isJust, fromJust)

import HD.Misc

-- { } is expressed as [ ]
-- [ ] is expressed as Maybe

-- Reset and clock signals (they are considered 

-- VHDL identifier, use mkVHDLId to create it from a String, 
-- making sure a string is a proper VHDL identifier
data VHDLId = Basic String | Extended String


fromVHDLId :: VHDLId -> String
fromVHDLId (Basic    str) = str
fromVHDLId (Extended str) = str


instance Show VHDLId where
 show  = show.fromVHDLId


-- unsafely create a basic VHDLId (without cheking if the string is correct)
unsafeVHDLBasicId :: String -> VHDLId
unsafeVHDLBasicId str = Basic str



-- unsafely create an exteded VHDLId (without cheking if the string is correct)
unsafeVHDLExtId :: String -> VHDLId
unsafeVHDLExtId str = Extended str



-- FIXME: make use of regular expressions or parsec, a hand made
--        lexer is ugly (but powerful)
mkVHDLId :: String -> EProne VHDLId
-- FIXME: The first letter and end empty pattern matching are checked twice
mkVHDLId [] = throwError "empty identifier"
mkVHDLId id@(first:_)
 | first == '/'    = mkVHDLExtId id
 | isLetter first  = mkVHDLBasicId id
 | otherwise       = throwError " is not a valid VHDL Id"    

mkVHDLBasicId ::String -> EProne VHDLId
-- FIXME: we relax the fact that two consecutive underlines 
--        are not allowed
mkVHDLBasicId [] = throwError "empty identifier"
mkVHDLBasicId id@(first:rest)
  | isLetter first && all (\c -> isLetter c || isDigit c || c == '_') rest &&
    (not $ elem lowId reservedWords) = return $ Basic id
  | otherwise = throwError "incorrect basic identifier"
 where lowId = map toLower id
 
mkVHDLExtId :: String -> EProne VHDLId
-- FIXME: we don't check that "If a backslash is to be used as 
--        one of the graphic characters of an extended identifier, 
--        it must be doubled."
mkVHDLExtId [] = throwError "empty identifier"
mkVHDLExtId id@(first:rest)
 | first == '/' && isJust maybeMLId && lastId == '/' &&
   all isMiddle middleId = return $ Extended id
 | otherwise = throwError "incorrect extended identifier"
 where ~(middleId,lastId) = fromJust maybeMLId
       maybeMLId = safeInitLast rest
       isMiddle c = isLetter c || isDigit c || c == ' ' || 
                    elem c specialChars || elem c otherSpecialChars 
       


specialChars = ['"' , '#' , '&' , '\'' , '(' , ')' , '*' , '+' , ',',
                '-' , '.' , '/' , ':'  , ';' , '<' , '=' , '>' , '_' , '|']

otherSpecialChars =['!' , '$' , '%' , '@' , '?' , '[' , '\\' , ']',
                    '^' , '`' , '{' , '}' , '~']


reservedWords :: [String]
reservedWords = ["abs", "access", "after", "alias", "all", "and",
 "architecture", "array", "assert", "attribute", "begin", "block",
 "body", "buffer", "bus", "case", "component", "configuration",
 "constant", "disconnect", "downto", "else", "elsif", "end", "entity",
 "exit", "file", "for", "function", "generate", "generic", "group",
 "guarded", "if", "impure", "in", "inertial", "inout", "is", "label",
 "library", "linkage", "literal", "loop", "map", "mod", "nand", "new",
 "next", "nor", "not", "null", "of", "on", "open", "or", "others",
 "out", "package", "port", "postponed", "procedure", "process", "pure",
 "range", "record", "register", "reject", "rem", "report", "return",
 "rol", "ror", "select", "severity", "shared", "signal", "sla", "sll",
 "sra", "srl", "subtype", "then", "to", "transport", "type",
 "unaffected", "units", "until", "use", "variable", "wait", "when",
 "while", "with", "xnor", "xor"]

-- design_file
-- Having ContextClauses associated to library units is messy
-- instead we only allow ContextClause for the whole design file.
-- Furthermore we incorrectly (and deliberately) accept a file with 
-- no library units 
data DesignFile = DesignFile [ContextItem] [LibraryUnit]  
 deriving Show

-- context_item
-- We don't allow the "name1,name2,name3" syntax, only one name is allowed
--  at once
data ContextItem = Library VHDLId | Use SelectedName
 deriving Show

-- selected_name
-- We don't want to deal with prefixes and subfixes, the name is internally
-- generated anyway, and thus we will make sure it is a correct one.
type SelectedName = String

-- library_unit
-- We avoid adding the overhead of a PrimaryUnit and SecondaryUnit types
data LibraryUnit = LUEntity EntityDec | LUArch ArchBody
 deriving Show

-- entity_declaration
-- No declarative nor statemet part is allowed 
-- Only interface signal declarations are allowed in the port clause
data EntityDec = EntityDec VHDLId [IfaceSigDec]
 deriving Show

-- interface_signal_declaration
-- We don't allow the "id1,id2,id3" syntax, only one identifier is allowed
--  at once
-- The Mode is mandatory
-- Bus is not allowed 
-- Preasigned values are not allowed
-- SubType indications are not allowed, just a typemark 
-- Constraints are not allowed: just add a new type with the constarint
--  in ForSyDe.vhd if it is required
data IfaceSigDec = IfaceSigDec VHDLId Mode TypeMark
 deriving Show

-- type_mark
-- We don't distinguish between type names and subtype names
type TypeMark = VHDLName


-- mode
-- INOUT | BUFFER | LINKAGE are not allowed
data Mode = In | Out
 deriving Show

-- architecture_body 
-- [ ARCHITECTURE ] and [ architecture_simple_name ] are not allowed
data ArchBody = ArchBody VHDLId VHDLName [BlockDecItem] [ConcSm]
 deriving Show

-- name
-- Only simple_names (identifiers) are allowed 
type VHDLName = VHDLId

-- block_declarative_item
-- Only subprogram bodys and signal declarations are allowed
data BlockDecItem = BDISPB SubProgBody | BDISD SigDec
 deriving Show


-- subprogram_body
-- No declarations are allowed, (wierd but we don't need them anyway) 
-- No subprogram kind nor designator is allowed
data SubProgBody = SubProgBody SubProgSpec [SeqSm]
 deriving Show

-- subprogram_specification
-- Only Functions are allowed
-- [Pure | Impure] is not allowed
-- Only a VHDLName is valid as the designator
-- In the formal parameter list only variable declarations are accepted  
data SubProgSpec = Function VHDLName [IfaceVarDec] TypeMark 
 deriving Show

-- interface_variable_declaration
-- [variable] is not allowed
-- We don't allow the "id1,id2,id3" syntax, only one identifier is allowed
-- Mode is not allowed
-- Resolution functions and constraints are not allowed, thus a TypeMark
--  is used instead of a subtype_indication
data IfaceVarDec = IfaceVarDec VHDLId TypeMark
 deriving Show

-- sequential_statement
-- Only If, case and return allowed
-- It is incorrect to have an empty [CaseSmAlt]
data SeqSm = IfSm  Expr [SeqSm] [ElseIf] (Maybe Else) |
             CaseSm Expr [CaseSmAlt]                  |
             ReturnSm (Maybe Expr)
 deriving Show

-- helper types, they don't exist in the origianl grammar
data ElseIf = ElseIf Expr [SeqSm]
 deriving Show
data Else = Else [SeqSm]
 deriving Show

-- case_statement_alternative
-- it is incorrect to have an empty [Choice]
data CaseSmAlt = CaseSmAlt [Choice] [SeqSm]
 deriving Show

-- choice
-- although any expression is allowed the grammar specfically only allows 
-- simple_expressions (not covered in this AST) 
data Choice = ChoiceE Expr | Others
 deriving Show

-- signal_declaration
-- We don't allow the "id1,id2,id3" syntax, only one identifier is allowed
--  at once
-- Resolution functions and constraints are not allowed, thus a TypeMark
--  is used instead of a subtype_indication
-- Signal kinds are not allowed
-- Preasigned values are not allowed
data SigDec = SigDec VHDLId TypeMark 
 deriving Show

-- concurrent_statement
-- only block statements, component instantiations and signal assignments 
-- are allowed
data ConcSm = CSBSm BlockSm | CSSASm  ConSigAssignSm | CSISm CompInsSm  
 deriving Show

-- block_statement
-- Generics are not supported
-- The port_clause (with only signals) and port_map_aspect are mandatory
-- The ending [ block_label ] is not allowed
-- 
data BlockSm = BlockSm Label [IfaceSigDec] PMapAspect [BlockDecItem] [ConcSm]
 deriving Show

-- port_map_aspect
newtype PMapAspect = PMapAspect [AssocElem]
 deriving Show

-- label
type Label = VHDLId

-- association_element
data AssocElem = Maybe (FormalPart) :=>: ActualPart
 deriving Show

-- formal_part
-- We only accept a formal_designator (which is a name after all),   
--  "function_name ( formal_designator )" and "type_mark ( formal_designator )"
--  are not allowed
type FormalPart = VHDLName

-- actual_part
-- We only accept an actual_designator,
--  "function_name ( actual_designator )" and "type_mark ( actual_designator )"
--  are not allowed
type ActualPart = ActualDesig

-- actual_designator
data ActualDesig = ADName VHDLName | ADExpr Expr | Open
 deriving Show

-- concurrent_signal_assignment_statement
-- Only conditional_signal_assignment is allowed (without options)
-- The LHS (targets) are simply signal names, no aggregates
data ConSigAssignSm = VHDLName :<==: ConWforms
 deriving Show

-- conditional_waveforms 
data ConWforms = ConWforms [WhenElse] Wform (Maybe When)  
 deriving Show

-- Helper types, they don't exist in the VHDL grammar
data WhenElse = WhenElse Wform Expr
 deriving Show
newtype When = When Expr
 deriving Show

-- waveform
-- wavefrom_element can just be  an expression
-- although it is possible to leave [Expr] empty, that's obviously not
-- valid VHDL
-- FIXME, Check what is the meaning a various waveforms separated by commas
data Wform = Wform [Expr] | Unaffected
 deriving Show

           
-- component_instantiation_statement
-- No generics supported
-- The port map aspect is mandatory
data CompInsSm = CompInsSm Label InsUnit [AssocElem]
 deriving Show

-- instantiated_unit
-- Only Entities are allowed and their architecture cannot be specified
data InsUnit = IUEntity VHDLName
 deriving Show

-----------------
-- Expression AST
-----------------

-- expression, instead of creating an AST like the grammar 
-- (see commented section below) we made our own expressions which are 
-- easier to handle, but which don't don't show operand precedence
-- (that is a responsibility of the pretty printer)

data Expr = -- Logical operations
            And  Expr Expr    |
            Or   Expr Expr    |
            Xor  Expr Expr    |
            Nand Expr Expr    |
            Nor  Expr Expr    |
            -- Relational Operators
            Expr :=:  Expr    |
            Expr :/=: Expr    |
            Expr :<:  Expr    |
            Expr :<=: Expr    |
            Expr :>:  Expr    |
            Expr :>=: Expr    |
            -- Shift Operators
            Sll Expr Expr     |
            Srl Expr Expr     |
            Sla Expr Expr     |
            Sra Expr Expr     |
            Rol Expr Expr     |
            Ror Expr Expr     |
            -- Adding Operators
            Expr :+: Expr     |
            Expr :-: Expr     |
            Expr :&: Expr     |
            -- Sign Operators
            Neg Expr          |
            Pos Expr          |
            -- Multiplying Operators
            Expr :*: Expr     |
            Expr :/: Expr     |
            Mod  Expr Expr    |
            Rem  Expr Expr    |
            -- Miscellaneous Operators
            Expr :**: Expr    |
            Abs  Expr         |
            Not  Expr         |
            -- Primary expressions
            -- Only literals, names and function calls  are allowed
            PrimName VHDLName     |
            PrimLit   Literal |
            PrimFCall FCall           
 deriving Show            


-- literal
-- Literals are expressed as a string (remember we are generating
-- code, not parsing)
type Literal = String

-- function_call
data FCall = FCall VHDLName [AssocElem]
 deriving Show
             
            
{-

Expression AST following the grammar (discarded)

-- again, even if it possible to leave the [Relation] lists empty
-- that wouldn't be valid VHDL code
-- regading  NandExpr and NorExpr, their Relation list should 
-- have a maximum size of two (i.e. NandExpr Expr (Maybe Expr))
data Expr = AndExpr  [Relation] | 
            OrExpr   [Relation] |
            XorExpr  [Relation] |
            NandExpr [Relation] |
            NorExpr  [Relation] |
            XnorExpr [Relation]
 deriving Show

-- relation            
data Relation = Relation ShiftExpr  (Maybe (RelOp,ShiftExpr))
 deriving Show

-- relational_operator
data RelOp = Eq | NEq | Less | LessEq | Gter | GterEq 
 deriving Show 

-- shift_expression
data ShiftExpr = ShiftExpr SimpleExpr (Maybe(ShiftOp,SimpleExpr)) 
 deriving Show

-- simple_expression
data SimpleExpr = SimpleExpr (Maybe Sign) Term [(AddOp,Term)]
 deriving Show

-- sign
data Sign = Pos | Neg
 deriving Show

-- shift_operator
data ShiftOp = Sll | Srl | Sla | Sra | Rol | Ror
 deriving Show 

-- adding_operator
data AddOp = Plus | Minus | Concat 
 deriving Show

-- term
data Term = Term Factor (Maybe (MultOp, Factor))
 deriving Show

-- multiplying_operator
data MultOp = Mult | Div | Mod | Rem
 deriving Show

-- factor
data Factor = Exp Primary (Maybe (Primary)) |
              Abs Primary                   |
              Not Primary
 deriving Show

-- primary
-- Only literals, names and function calls  are allowed
data Primary = PrimName  VHDLName    |
               PrimLit   Literal |
               PrimFCall FCall
 deriving Show

-- literal
-- Literals are expressed as a string (remember we are generating
-- code, not parsing)
type Literal = String

-- function_call
data FCall = FCall VHDLName [AssocElem]
 deriving Show
-}