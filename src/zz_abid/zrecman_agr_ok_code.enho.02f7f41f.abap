"Name: \PR:SAPLPRGN_TREE\FO:USER_COMMAND_121_NEW\SE:BEGIN\EI
ENHANCEMENT 0 ZRECMAN_AGR_OK_CODE.

  SET PARAMETER ID 'ZUC' FIELD sy-ucomm.

***  DATA: lt_domvals TYPE STANDARD TABLE OF dd07v WITH EMPTY KEY.
***  "---- NEW: Read domain fixed values (FI, SD, ...) from DDIC
***  CALL FUNCTION 'DD_DOMVALUES_GET'
***    EXPORTING
***      domname        = 'ZZ_OWNER_GROUP'
****     TEXT           = ' '
***      langu          = sy-langu
****     BYPASS_BUFFER  = ' '
**** IMPORTING
****     RC             =
***    TABLES
***      dd07v_tab      = lt_domvals
***    EXCEPTIONS
***      wrong_textflag = 1
***      OTHERS         = 2.
***
***  "Optional: if DDIC call fails, don't create anything
***  IF sy-subrc <> 0 OR lt_domvals IS INITIAL.
***    MESSAGE e019(zz_arc_recman) DISPLAY LIKE 'E'.
***    RETURN.
***  ENDIF.
***
***  DATA(lv_match) = abap_false.
***  LOOP AT lt_domvals INTO DATA(ls_dom)
***       WHERE domvalue_l IS NOT INITIAL.
***    IF agr_name_neu CS ls_dom-domvalue_l.
***      lv_match = abap_true.
***      EXIT.
***    ENDIF.
***  ENDLOOP.
***
****---- ERROR if no match
***  IF lv_match = abap_false.
***    MESSAGE s020(zz_arc_recman)  DISPLAY LIKE 'E' WITH agr_name_neu.
***    RETURN.
***  ENDIF.

ENDENHANCEMENT.
