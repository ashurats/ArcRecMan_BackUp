*&---------------------------------------------------------------------*
*& Report Z_ARC_RECMAN_WBS_KPI_REPORT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_arc_recman_wbs_kpi_report.

*----------------------------------------------------------------------
* Types
*----------------------------------------------------------------------
TYPES: BEGIN OF ty_kpi,
         bukrs       TYPE bukrs,
         gjahr       TYPE gjahr,
         monat       TYPE monat,
         kpi_id      TYPE char20,
         kpi_text    TYPE char60,
         numerator   TYPE p LENGTH 16 DECIMALS 2,
         denominator TYPE p LENGTH 16 DECIMALS 2,
         kpi_pct     TYPE p LENGTH 16 DECIMALS 2,
       END OF ty_kpi.

DATA: gt_kpi TYPE STANDARD TABLE OF ty_kpi WITH EMPTY KEY,
      gs_kpi TYPE ty_kpi.

*----------------------------------------------------------------------
* Selection Screen
*----------------------------------------------------------------------
SELECT-OPTIONS: so_bukrs FOR gs_kpi-bukrs.
PARAMETERS: p_gjahr TYPE gjahr DEFAULT sy-datum(4),
            p_monat TYPE monat.

*----------------------------------------------------------------------
* Start
*----------------------------------------------------------------------
START-OF-SELECTION.

  "1) Fetch data
  SELECT * FROM zkpi_data
    INTO CORRESPONDING FIELDS OF TABLE @gt_kpi
    WHERE bukrs IN @so_bukrs
      AND gjahr = @p_gjahr
      AND monat = @p_monat.


  IF sy-subrc <> 0 OR gt_kpi IS INITIAL.
    MESSAGE 'No data found for given selection.' TYPE 'I'.
    RETURN.
  ENDIF.

  "2) Calculate KPI %
  LOOP AT gt_kpi INTO gs_kpi.
    IF gs_kpi-denominator IS INITIAL OR gs_kpi-denominator = 0.
      gs_kpi-kpi_pct = 0.
    ELSE.
      gs_kpi-kpi_pct = ( gs_kpi-numerator / gs_kpi-denominator ) * 100.
    ENDIF.
    MODIFY gt_kpi FROM gs_kpi.
  ENDLOOP.

  "3) Display ALV
  PERFORM display_alv.

*----------------------------------------------------------------------
* ALV (CL_SALV_TABLE)
*----------------------------------------------------------------------
FORM display_alv.
  DATA: lo_alv   TYPE REF TO cl_salv_table,
        lo_cols  TYPE REF TO cl_salv_columns_table,
        lo_col   TYPE REF TO cl_salv_column_table,
        lo_disp  TYPE REF TO cl_salv_display_settings,
        lo_funcs TYPE REF TO cl_salv_functions_list.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_kpi ).

      lo_cols  = lo_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      lo_disp = lo_alv->get_display_settings( ).
      lo_disp->set_striped_pattern( abap_true ).
      lo_disp->set_list_header( |KPI % Report - Year { p_gjahr }| ).

      lo_funcs = lo_alv->get_functions( ).
      lo_funcs->set_all( abap_true ).

      "Rename column headings
      lo_col ?= lo_cols->get_column( 'KPI_PCT' ).
      lo_col->set_short_text( 'KPI %' ).
      lo_col->set_medium_text( 'KPI Percentage' ).
*      lo_col->set_long_text( 'KPI Percentage (Numerator/Denominator*100)' ).
      lo_col->set_long_text( CONV scrtext_l(
        'KPI Percentage (Numerator/Denominator*100)' ) ).


      lo_col ?= lo_cols->get_column( 'NUMERATOR' ).
      lo_col->set_short_text( 'Achvd' ).
      lo_col->set_medium_text( 'Numerator' ).

      lo_col ?= lo_cols->get_column( 'DENOMINATOR' ).
      lo_col->set_short_text( 'Target' ).
      lo_col->set_medium_text( 'Denominator' ).

      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.
