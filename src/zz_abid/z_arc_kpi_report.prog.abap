*&---------------------------------------------------------------------*
*& Report Z_ARC_KPI_REPORT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_arc_kpi_report.

*---------------------------------------------------------------------*
* Selection Screen
*---------------------------------------------------------------------*
PARAMETERS: p_year  TYPE char4 OBLIGATORY,
            p_month TYPE char2.
*            p_week  TYPE char2.

TYPES: BEGIN OF ty_kpi,
         period        TYPE char6,
         year          TYPE char4,
         month         TYPE char2,
*         week          TYPE char2,
         totalcount    TYPE i,
         approvedcount TYPE i,
         pendingcount  TYPE i,
         rejectedcount TYPE i,
       END OF ty_kpi.

DATA: gt_kpi TYPE TABLE OF ty_kpi,
      gs_kpi TYPE ty_kpi.

DATA: gt_data TYPE TABLE OF zcomp_role_hdr,
      gs_data TYPE zcomp_role_hdr.

DATA: gt_kpi_hash TYPE HASHED TABLE OF ty_kpi
                  WITH UNIQUE KEY period.
                  "week.
*---------------------------------------------------------------------*
* F4 Helps
*---------------------------------------------------------------------*
*AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_year.
*  PERFORM f4_year.

*AT SELECTION-SCREEN.

*  IF p_week IS NOT INITIAL AND p_month IS INITIAL.
*    MESSAGE 'Month required when Week is used' TYPE 'E'.
*  ENDIF.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_month.
  PERFORM f4_month.

*AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_week.
*  PERFORM f4_week.

*---------------------------------------------------------------------*
* Data
*---------------------------------------------------------------------*
  DATA: gt_kpi TYPE STANDARD TABLE OF ty_kpi,
        gs_kpi TYPE ty_kpi.

  DATA: gt_data TYPE TABLE OF zcomp_role_hdr,
        gs_data TYPE zcomp_role_hdr.

  DATA: gt_kpi_hash TYPE HASHED TABLE OF ty_kpi
                    WITH UNIQUE KEY period.
                    "week.

*---------------------------------------------------------------------*
* Start-of-selection
*---------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM get_data.
  PERFORM process_data.
  PERFORM display_data.

*---------------------------------------------------------------------*
* Get Data
*---------------------------------------------------------------------*
FORM get_data.

  DATA: lv_pattern TYPE char20.

*  IF p_week IS NOT INITIAL AND p_month IS INITIAL.
*    MESSAGE 'Month required when Week is used' TYPE 'E'.
*  ENDIF.

  IF p_month IS NOT INITIAL.
    CONCATENATE p_year p_month '%' INTO lv_pattern.
  ELSE.
    CONCATENATE p_year '%' INTO lv_pattern.
  ENDIF.

  SELECT *
    FROM zcomp_role_hdr
    INTO TABLE gt_data
    WHERE created_at LIKE lv_pattern.

ENDFORM.

*---------------------------------------------------------------------*
* Process KPI
*---------------------------------------------------------------------*
FORM process_data.

  DATA: lv_key       TYPE char6,
        lv_week_calc TYPE char2,
        lv_date      TYPE sy-datum,
        lv_day       TYPE i.

  LOOP AT gt_data INTO gs_data.

    lv_date = gs_data-created_at+0(8).
    lv_day  = lv_date+6(2).

** Week logic (within month)
*    IF lv_day BETWEEN 1 AND 7.
*      lv_week_calc = '1'.
*    ELSEIF lv_day BETWEEN 8 AND 14.
*      lv_week_calc = '2'.
*    ELSEIF lv_day BETWEEN 15 AND 21.
*      lv_week_calc = '3'.
*    ELSE.
*      lv_week_calc = '4'.
*    ENDIF.

* Apply week filter
*    IF p_week IS NOT INITIAL AND lv_week_calc <> p_week.
*      CONTINUE.
*    ENDIF.

* Determine period
    IF p_month IS NOT INITIAL.
      lv_key = gs_data-created_at+0(6).
    ELSE.
      lv_key = gs_data-created_at+0(4).
      CLEAR lv_week_calc.
    ENDIF.

* Read/Create KPI row
    READ TABLE gt_kpi_hash INTO gs_kpi
      WITH KEY period = lv_key.
*    week = lv_week_calc.

    IF sy-subrc <> 0.
      CLEAR gs_kpi.
      gs_kpi-period = lv_key.
      gs_kpi-year   = p_year.
      gs_kpi-month  = p_month.
*      gs_kpi-week   = lv_week_calc.
      INSERT gs_kpi INTO TABLE gt_kpi_hash.
      READ TABLE gt_kpi_hash INTO gs_kpi
        WITH KEY period = lv_key.
*        week = lv_week_calc.
    ENDIF.

* Total
    gs_kpi-totalcount = gs_kpi-totalcount + 1.

* Status normalization
    DATA lv_status TYPE string.
    lv_status = gs_data-wf_approval_status.
    TRANSLATE lv_status TO UPPER CASE.

    CASE lv_status.
      WHEN 'APPROVED'.
        gs_kpi-approvedcount = gs_kpi-approvedcount + 1.
      WHEN 'PENDING'.
        gs_kpi-pendingcount = gs_kpi-pendingcount + 1.
      WHEN 'REJECTED'.
        gs_kpi-rejectedcount = gs_kpi-rejectedcount + 1.
    ENDCASE.

    MODIFY TABLE gt_kpi_hash FROM gs_kpi.

  ENDLOOP.

  gt_kpi = gt_kpi_hash.

ENDFORM.

*---------------------------------------------------------------------*
* Display ALV
*---------------------------------------------------------------------*
FORM display_data.
  DATA: lo_alv     TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_column  TYPE REF TO cl_salv_column.

  cl_salv_table=>factory(
    IMPORTING r_salv_table = lo_alv
    CHANGING  t_table      = gt_kpi ).

  lo_columns = lo_alv->get_columns( ).

  TRY.

*      lo_column ?= lo_columns->get_column( 'PERIOD' ).
*      lo_column->set_long_text( 'Period' ).

      lo_column ?= lo_columns->get_column( 'YEAR' ).
      lo_column->set_long_text( 'Year' ).

      lo_column ?= lo_columns->get_column( 'MONTH' ).
      lo_column->set_long_text( 'Month' ).

*      lo_column ?= lo_columns->get_column( 'WEEK' ).
*      lo_column->set_long_text( 'Week' ).

      lo_column ?= lo_columns->get_column( 'TOTALCOUNT' ).
      lo_column->set_long_text( 'Total Requests' ).

      lo_column ?= lo_columns->get_column( 'APPROVEDCOUNT' ).
      lo_column->set_long_text( 'Approved Requests' ).

      lo_column ?= lo_columns->get_column( 'PENDINGCOUNT' ).
      lo_column->set_long_text( 'Pending Requests' ).

      lo_column ?= lo_columns->get_column( 'REJECTEDCOUNT' ).
      lo_column->set_long_text( 'Rejected Requests' ).

    CATCH cx_salv_not_found.
  ENDTRY.


  lo_alv->display( ).


ENDFORM.

*---------------------------------------------------------------------*
* F4 HELP - YEAR
*---------------------------------------------------------------------*
FORM f4_year.

  DATA: lt_year   TYPE TABLE OF char4,
        lt_return TYPE TABLE OF ddshretval,
        lv_year   TYPE char4.

  DO 10 TIMES.
    lv_year = sy-datum+0(4) - sy-index + 1.
    APPEND lv_year TO lt_year.
  ENDDO.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'YEAR'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'P_YEAR'
      value_org   = 'S'
    TABLES
      value_tab   = lt_year
      return_tab  = lt_return.

ENDFORM.

*---------------------------------------------------------------------*
* F4 HELP - MONTH
*---------------------------------------------------------------------*
FORM f4_month.

  TYPES: BEGIN OF ty_month,
           month TYPE char2,
           text  TYPE char10,
         END OF ty_month.

  DATA: lt_month  TYPE TABLE OF ty_month,
        ls_month  TYPE ty_month,
        lt_return TYPE TABLE OF ddshretval.

  ls_month-month = '01'. ls_month-text = 'January'.   APPEND ls_month TO lt_month.
  ls_month-month = '02'. ls_month-text = 'February'.  APPEND ls_month TO lt_month.
  ls_month-month = '03'. ls_month-text = 'March'.     APPEND ls_month TO lt_month.
  ls_month-month = '04'. ls_month-text = 'April'.     APPEND ls_month TO lt_month.
  ls_month-month = '05'. ls_month-text = 'May'.       APPEND ls_month TO lt_month.
  ls_month-month = '06'. ls_month-text = 'June'.      APPEND ls_month TO lt_month.
  ls_month-month = '07'. ls_month-text = 'July'.      APPEND ls_month TO lt_month.
  ls_month-month = '08'. ls_month-text = 'August'.    APPEND ls_month TO lt_month.
  ls_month-month = '09'. ls_month-text = 'September'. APPEND ls_month TO lt_month.
  ls_month-month = '10'. ls_month-text = 'October'.   APPEND ls_month TO lt_month.
  ls_month-month = '11'. ls_month-text = 'November'.  APPEND ls_month TO lt_month.
  ls_month-month = '12'. ls_month-text = 'December'.  APPEND ls_month TO lt_month.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'MONTH'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'P_MONTH'
      value_org   = 'S'
    TABLES
      value_tab   = lt_month
      return_tab  = lt_return.

ENDFORM.

*---------------------------------------------------------------------*
* F4 HELP - WEEK
*---------------------------------------------------------------------*
FORM f4_week.

  DATA: lt_week   TYPE TABLE OF char2,
        lt_return TYPE TABLE OF ddshretval.

  APPEND '01' TO lt_week.
  APPEND '02' TO lt_week.
  APPEND '03' TO lt_week.
  APPEND '04' TO lt_week.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield    = 'WEEK'
      dynpprog    = sy-repid
      dynpnr      = sy-dynnr
      dynprofield = 'P_WEEK'
      value_org   = 'S'
    TABLES
      value_tab   = lt_week
      return_tab  = lt_return.

ENDFORM.
