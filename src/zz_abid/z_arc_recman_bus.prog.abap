*****           Implementation of object type ZBUSRECMAN           *****
INCLUDE <object>.
BEGIN_DATA OBJECT. " Do not change.. DATA is generated
* only private members may be inserted into structure private
DATA:
" begin of private,
"   to declare private attributes remove comments and
"   insert private attributes here ...
" end of private,
  BEGIN OF KEY,
      COMPOSITEROLE1 LIKE AGR_AGRS-AGR_NAME,
      ROLE LIKE AGR_AGRS-CHILD_AGR,
  END OF KEY.
END_DATA OBJECT. " Do not change.. DATA is generated

begin_method display changing container.
DATA: lv_role TYPE agr_agrs-agr_name.

lv_role = object-key-compositerole1.
SET PARAMETER ID 'ZRECMAN' FIELD lv_role.
CALL TRANSACTION 'Z_ARC_RECMAN' AND SKIP FIRST SCREEN.
end_method.
