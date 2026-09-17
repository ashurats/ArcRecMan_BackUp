*&---------------------------------------------------------------------*
*& Modulpool Z_ARC_KPI_REPORT_MP
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
PROGRAM z_arc_kpi_report_mp.
TABLES: zcomp_role_hdr.

DATA: gv_year  TYPE char4, "VALUE sy-datum+0(4),
      gv_month TYPE char2. "VALUE sy-datum+4(2).

DATA: gv_total    TYPE i,
      gv_approved TYPE i,
      gv_pending  TYPE i,
      gv_rejected TYPE i.

*---------------------------------------------------------------------*
* CLASS DEFINITION
*---------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS: handle_timer FOR EVENT finished OF cl_gui_timer.
ENDCLASS.

DATA: go_timer   TYPE REF TO cl_gui_timer,
      go_handler TYPE REF TO lcl_event_handler.

*---------------------------------------------------------------------*
* CLASS IMPLEMENTATION
*---------------------------------------------------------------------*
CLASS lcl_event_handler IMPLEMENTATION.

  METHOD handle_timer.


    IF go_timer IS BOUND.
      PERFORM calculate_kpi.
      go_timer->run( ).
    ENDIF.

    CALL METHOD cl_gui_cfw=>flush.

  ENDMETHOD.

ENDCLASS.


*---------------------------------------------------------------------*
* PBO MODULE
*---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.

  SET PF-STATUS 'STANDARD'.
  SET TITLEBAR 'KPI_TILE'.

ENDMODULE.


MODULE auto_refresh OUTPUT.

* Default values
  IF gv_year IS INITIAL.
    gv_year  = sy-datum+0(4).
    gv_month = sy-datum+4(2).
  ENDIF.

* First load
  IF gv_total IS INITIAL.
    PERFORM calculate_kpi.
  ENDIF.

* Start timer
  IF go_timer IS INITIAL.

    CREATE OBJECT go_timer.
    go_timer->interval = 2.

    CREATE OBJECT go_handler.

    SET HANDLER go_handler->handle_timer FOR go_timer.

    go_timer->run( ).

  ENDIF.

ENDMODULE.






MODULE user_command_0100 INPUT.

  CASE sy-ucomm.

*    WHEN 'GET'.
*      PERFORM calculate_kpi.

    WHEN 'EXIT' OR 'BACK' OR 'CANCEL'.
      LEAVE PROGRAM.

  ENDCASE.

ENDMODULE.

FORM calculate_kpi.

  DATA: lt_data TYPE TABLE OF zcomp_role_hdr,
        ls_data TYPE zcomp_role_hdr.

  DATA: lv_pattern   TYPE char20,
        lv_date      TYPE sy-datum,
        lv_day       TYPE i,
        lv_week_calc TYPE char2.

  CLEAR: gv_total, gv_approved, gv_pending, gv_rejected.


* Build filter
  IF gv_month IS NOT INITIAL.
    CONCATENATE gv_year gv_month '%' INTO lv_pattern.
  ELSE.
    CONCATENATE gv_year '%' INTO lv_pattern.
  ENDIF.

* Fetch data
  SELECT *
    FROM zcomp_role_hdr
    INTO TABLE lt_data
    WHERE created_at LIKE lv_pattern.

* Process
  LOOP AT lt_data INTO ls_data.

    lv_date = ls_data-created_at+0(8).
    lv_day  = lv_date+6(2).

* Total
    gv_total = gv_total + 1.

* Status
    DATA lv_status TYPE string.
    lv_status = ls_data-wf_approval_status.
    TRANSLATE lv_status TO UPPER CASE.

    CASE lv_status.
      WHEN 'APPROVED'.
        gv_approved = gv_approved + 1.
      WHEN 'PENDING'.
        gv_pending = gv_pending + 1.
      WHEN 'REJECTED'.
        gv_rejected = gv_rejected + 1.
    ENDCASE.

  ENDLOOP.

ENDFORM.
