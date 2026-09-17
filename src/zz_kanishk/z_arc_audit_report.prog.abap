*&---------------------------------------------------------------------*
*& Report Z_ARC_RECMAN_DEMO3
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_arc_audit_report.
TABLES: cdhdr, cdpos, tstc.
DATA: lv_date TYPE d,
      lv_time TYPE t.
SELECT-OPTIONS:
  s_objid FOR cdhdr-objectid,
  s_user  FOR cdhdr-username MATCHCODE OBJECT sx_user,
  s_tcode FOR tstc-tcode,
  s_date  FOR sy-datum OBLIGATORY,
  s_time  FOR sy-uzeit,
  s_tab   FOR cdpos-tabname,
  s_field FOR cdpos-fname,
  s_chind FOR cdpos-chngind.

*--------------------------------------------------------------------*
* Typdefinition
*--------------------------------------------------------------------*
TYPES: BEGIN OF ty_change,
         username   TYPE cdhdr-username,
         objectclas TYPE cdhdr-objectclas,
         objectid   TYPE cdhdr-objectid,
         tcode      TYPE cdhdr-tcode,
         udate      TYPE cdhdr-udate,
         utime      TYPE cdhdr-utime,
         tzone      TYPE syst_zonlo,
         tabname    TYPE cdpos-tabname,
         fname      TYPE cdpos-fname,
         tabkey     TYPE cdpos-tabkey,
         chngind    TYPE cdpos-chngind,
         chngtxt    TYPE string,
         value_new  TYPE cdpos-value_new,
         value_old  TYPE cdpos-value_old,
         color      TYPE lvc_t_scol,   " <--  für Zellenfarben
       END OF ty_change.

DATA: lt_changes TYPE STANDARD TABLE OF ty_change,
      lt_cdhdr   TYPE STANDARD TABLE OF cdhdr,
      lt_cdpos   TYPE STANDARD TABLE OF cdpos.

*--------------------------------------------------------------------*
* START-OF-SELECTION
*--------------------------------------------------------------------*
START-OF-SELECTION.

  " Schritt 1: CDHDR lesen
  SELECT *
  INTO TABLE @lt_cdhdr
  FROM cdhdr
 WHERE objectid IN @s_objid
   AND username IN @s_user
   AND tcode    IN @s_tcode
   AND udate    IN @s_date.

  IF sy-subrc <> 0.
    MESSAGE 'No change documents found for given selection' TYPE 'I'.
    EXIT.
  ENDIF.

  SORT lt_cdhdr BY objectclas objectid changenr.

  " Schritt 2: CDPOS lesen
  SELECT *
    INTO TABLE @lt_cdpos
    FROM cdpos
   FOR ALL ENTRIES IN @lt_cdhdr
   WHERE objectclas = @lt_cdhdr-objectclas
  AND objectid   = @lt_cdhdr-objectid
  AND changenr   = @lt_cdhdr-changenr
  AND tabname    IN @s_tab
  AND fname      IN @s_field
  AND chngind    IN @s_chind.

  IF sy-subrc <> 0.
    MESSAGE 'No change details found for given selection' TYPE 'I'.
    EXIT.
  ENDIF.

  SORT lt_cdpos BY objectclas objectid changenr.

*--------------------------------------------------------------------*
* Schritt 3: Ergebnisse kombinieren + Farben setzen
*--------------------------------------------------------------------*
  LOOP AT lt_cdpos INTO DATA(ls_pos).
    READ TABLE lt_cdhdr INTO DATA(ls_hdr)
         WITH KEY objectclas = ls_pos-objectclas
                  objectid   = ls_pos-objectid
                  changenr   = ls_pos-changenr
         BINARY SEARCH.

    IF sy-subrc = 0.

      " Beschreibung bestimmen
      DATA(lv_chngtxt) = SWITCH string( ls_pos-chngind
        WHEN 'U' THEN 'Update'
        WHEN 'I' THEN 'Insert'
        WHEN 'E' THEN 'Delete (single field documentation)'
        WHEN 'D' THEN 'Delete'
        WHEN 'J' THEN 'Insert (single field documentation)'
        ELSE 'Unknown' ).

      " Farbinformation vorbereiten
      DATA(lt_color) = VALUE lvc_t_scol( ).

      CASE ls_pos-chngind.
        WHEN 'I' OR 'J'.   " Insert → Dunkelgrün
          APPEND VALUE #( fname = 'CHNGIND'
                          color-col = '5'
                          ) TO lt_color.
          APPEND VALUE #( fname = 'CHNGTXT'
                          color-col = '5'
                          ) TO lt_color.

        WHEN 'D' OR 'E'.   " Delete → Rot
          APPEND VALUE #( fname = 'CHNGIND'
                          color-col = '6' ) TO lt_color.
          APPEND VALUE #( fname = 'CHNGTXT'
                          color-col = '6' ) TO lt_color.

        WHEN 'U'.          " Update → Gelb
          APPEND VALUE #( fname = 'CHNGIND'
                          color-col = '3' ) TO lt_color.
          APPEND VALUE #( fname = 'CHNGTXT'
                          color-col = '3' ) TO lt_color.
      ENDCASE.


      " Datensatz aufbauen
      APPEND VALUE ty_change(
         username   = ls_hdr-username
         objectclas = ls_hdr-objectclas
         objectid   = ls_hdr-objectid
         tcode      = ls_hdr-tcode
         udate      = ls_hdr-udate
         utime      = ls_hdr-utime
         tzone      = sy-zonlo
         tabname    = ls_pos-tabname
         fname      = ls_pos-fname
         tabkey     = ls_pos-tabkey
         chngind    = ls_pos-chngind
         chngtxt    = lv_chngtxt
         value_new  = ls_pos-value_new
         value_old  = ls_pos-value_old
         color      = lt_color ) TO lt_changes.
    ENDIF.
  ENDLOOP.

*--------------------------------------------------------------------*
* Step 4: Anzeige im S ALV
*--------------------------------------------------------------------*
  IF lt_changes IS INITIAL.
    MESSAGE 'No changes found for given selection' TYPE 'I'.
    EXIT.
  ENDIF.

  DATA lo_alv TYPE REF TO cl_salv_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = lt_changes ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_display_settings( )->set_list_header(
        |Change Documents by User(s) and Transaction(s)| ).

      " Spaltenbreite anpassen
      lo_alv->get_columns( )->set_optimize( abap_true ).

      DATA: lo_cols TYPE REF TO cl_salv_columns_table,
      lo_col  TYPE REF TO cl_salv_column_table.

lo_cols = lo_alv->get_columns( ).

TRY.
    lo_col ?= lo_cols->get_column( 'OBJECTID' ).
    lo_col->set_short_text( 'Role' ).
    lo_col->set_medium_text( 'Composite Role' ).
    lo_col->set_long_text( 'Composite Role' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'USERNAME' ).
    lo_col->set_short_text( 'User' ).
    lo_col->set_medium_text( 'Changed By' ).
    lo_col->set_long_text( 'Changed By User' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'OBJECTCLAS' ).
    lo_col->set_short_text( 'Object' ).
    lo_col->set_medium_text( 'Object Type' ).
    lo_col->set_long_text( 'Object Type' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'TCODE' ).
    lo_col->set_short_text( 'TCode' ).
    lo_col->set_medium_text( 'Transaction' ).
    lo_col->set_long_text( 'Transaction Code' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'TABNAME' ).
    lo_col->set_short_text( 'Table' ).
    lo_col->set_medium_text( 'Table Name' ).
    lo_col->set_long_text( 'Database Table' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'FNAME' ).
    lo_col->set_short_text( 'Field' ).
    lo_col->set_medium_text( 'Field Name' ).
    lo_col->set_long_text( 'Changed Field' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'CHNGTXT' ).
    lo_col->set_short_text( 'Change' ).
    lo_col->set_medium_text( 'Change Type' ).
    lo_col->set_long_text( 'Change Type' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'VALUE_OLD' ).
    lo_col->set_short_text( 'Old' ).
    lo_col->set_medium_text( 'Old Value' ).
    lo_col->set_long_text( 'Previous Value' ).
  CATCH cx_salv_not_found.
ENDTRY.

TRY.
    lo_col ?= lo_cols->get_column( 'VALUE_NEW' ).
    lo_col->set_short_text( 'New' ).
    lo_col->set_medium_text( 'New Value' ).
    lo_col->set_long_text( 'New Value' ).
  CATCH cx_salv_not_found.
ENDTRY.

      " Farbfeld zuordnen
      lo_alv->get_columns( )->set_color_column( 'COLOR' ).

      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.
