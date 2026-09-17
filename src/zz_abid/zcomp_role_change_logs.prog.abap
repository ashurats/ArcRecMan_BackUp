*&---------------------------------------------------------------------*
*& Report ZCOMP_ROLE_CHANGE_LOGS
*& Description: Display Composite Role Change Logs
*&---------------------------------------------------------------------*
REPORT zcomp_role_change_logs.

*----------------------------------------------------------------------*
* TABLES DECLARATION (For Selection Screen)
*----------------------------------------------------------------------*
TABLES: zcomp_role_log.

*----------------------------------------------------------------------*
* TYPES & DATA DECLARATIONS
*----------------------------------------------------------------------*
" 1. Extend the structure to include a color column
TYPES: BEGIN OF ty_log.
         INCLUDE STRUCTURE zcomp_role_log.
TYPES:   t_color TYPE lvc_t_scol, " Table type for ALV colors
       END OF ty_log.

DATA: gt_log TYPE STANDARD TABLE OF ty_log,
      go_alv TYPE REF TO cl_salv_table.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_agr    FOR zcomp_role_log-agr_name,
                  s_child  FOR zcomp_role_log-child_agr,
                  s_user   FOR zcomp_role_log-changed_by,
                  s_date   FOR zcomp_role_log-changed_on.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  SELECT-OPTIONS: s_ctype  FOR zcomp_role_log-change_type,
                  s_amode  FOR zcomp_role_log-action_mode.
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM get_data.

  IF gt_log IS NOT INITIAL.
    PERFORM display_alv.
  ELSE.
    MESSAGE 'No log records found for the given criteria.' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
FORM get_data.
  DATA: ls_color TYPE lvc_s_scol.

  " Use CORRESPONDING FIELDS since our internal table has the extra color column
  SELECT *
    FROM zcomp_role_log
    INTO CORRESPONDING FIELDS OF TABLE @gt_log
    WHERE agr_name    IN @s_agr
      AND child_agr   IN @s_child
      AND changed_by  IN @s_user
      AND changed_on  IN @s_date
      AND change_type IN @s_ctype
      AND action_mode IN @s_amode
    ORDER BY changed_on DESCENDING, changed_at DESCENDING.

  " 2. Loop through the data and apply colors based on CHANGE_TYPE
  LOOP AT gt_log ASSIGNING FIELD-SYMBOL(<fs_log>).
    CLEAR ls_color.

    CASE <fs_log>-change_type.
      WHEN 'ADD'.
        ls_color-color-col = col_positive. " Green
        ls_color-color-int = 0.
        ls_color-color-inv = 0.
        APPEND ls_color TO <fs_log>-t_color.

      WHEN 'CHANGE'.
        ls_color-color-col = col_total.    " Yellow
        ls_color-color-int = 0.
        ls_color-color-inv = 0.
        APPEND ls_color TO <fs_log>-t_color.

      WHEN 'DELETE'.
        ls_color-color-col = col_negative. " Red (Optional, added for completeness)
        ls_color-color-int = 0.
        ls_color-color-inv = 0.
        APPEND ls_color TO <fs_log>-t_color.
    ENDCASE.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
FORM display_alv.
  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = gt_log ).

      DATA(lo_columns) = go_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " ------------------------------------------------------------------
      " FIELD CATALOG MAINTENANCE (SALV)
      " ------------------------------------------------------------------
      DATA: lo_column TYPE REF TO cl_salv_column_table.

      TRY.
          " 1. Hide technical or unnecessary columns (e.g., Client/MANDT)
          lo_column ?= lo_columns->get_column( 'MANDT' ).
          lo_column->set_visible( abap_false ).

          " Ensure the color column is strictly hidden from the user
          lo_column ?= lo_columns->get_column( 'T_COLOR' ).
          lo_column->set_visible( abap_false ).

          " 2. Override Data Dictionary Texts
          lo_column ?= lo_columns->get_column( 'CHILD_AGR' ).
          lo_column->set_long_text( 'Single Role Name' ).
          lo_column->set_medium_text( 'Single Role' ).
          lo_column->set_short_text( 'SnglRole' ).

          lo_column ?= lo_columns->get_column( 'AGR_NAME' ).
          lo_column->set_long_text( 'Composite Role Name' ).
          lo_column->set_medium_text( 'Composite Role' ).
          lo_column->set_short_text( 'CompRole' ).

          " 3. Adjust Alignment and Output Length
          lo_column ?= lo_columns->get_column( 'CHANGE_TYPE' ).
          lo_column->set_alignment( if_salv_c_alignment=>centered ).
          lo_column->set_output_length( 12 ).

          lo_column ?= lo_columns->get_column( 'ACTION_MODE' ).
          lo_column->set_alignment( if_salv_c_alignment=>centered ).

        CATCH cx_salv_not_found.
          " Ignore if a column name is misspelled or doesn't exist
      ENDTRY.


      " 3. Tell the ALV which column holds the color formatting
      TRY.
          lo_columns->set_color_column( 'T_COLOR' ).
        CATCH cx_salv_data_error.
          " Handle error if column is not found
      ENDTRY.

      DATA(lo_functions) = go_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      DATA(lo_display) = go_alv->get_display_settings( ).
      lo_display->set_striped_pattern( abap_true ).
      lo_display->set_list_header( 'Composite Role Modification Logs' ).

      DATA(lo_sorts) = go_alv->get_sorts( ).
      TRY.
          lo_sorts->add_sort( columnname = 'CHANGED_ON' sequence = if_salv_c_sort=>sort_down ).
          lo_sorts->add_sort( columnname = 'CHANGED_AT' sequence = if_salv_c_sort=>sort_down ).
        CATCH cx_salv_not_found cx_salv_existing cx_salv_data_error.
      ENDTRY.

      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.
ENDFORM.
