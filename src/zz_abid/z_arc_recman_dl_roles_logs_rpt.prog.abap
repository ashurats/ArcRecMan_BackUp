*&---------------------------------------------------------------------*
*& Report Z_ARC_RECMAN_DL_ROLES_LOGS_RPT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT Z_ARC_RECMAN_DL_ROLES_LOGS_RPT.

*----------------------------------------------------------------------*
* DATA DECLARATIONS
*----------------------------------------------------------------------*
" Define a structure that includes the DB table and a field for ALV colors
TYPES: BEGIN OF ty_alv.
         INCLUDE TYPE zrecman_dl_logs.
TYPES:   color_line TYPE lvc_t_scol, " Table to hold cell/row colors
       END OF ty_alv.

DATA: gt_alv TYPE TABLE OF ty_alv,
      gs_alv TYPE ty_alv.

DATA: go_alv     TYPE REF TO cl_salv_table,
      go_columns TYPE REF TO cl_salv_columns_table,
      go_func    TYPE REF TO cl_salv_functions.

" Global variables for counting statuses
DATA: gv_approved_count TYPE i,
      gv_rejected_count TYPE i.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
" Dummy variables for selection screen reference
DATA: gv_agr_name TYPE zrecman_dl_logs-agr_name,
      gv_status   TYPE zrecman_dl_logs-wf_approval_status.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  " Attached standard SAP Role search help (F4)
  SELECT-OPTIONS: s_role   FOR gv_agr_name MATCHCODE OBJECT agr_name,
                  s_status FOR gv_status.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_data.
  PERFORM process_status_colors.
  PERFORM display_alv.

*----------------------------------------------------------------------*
* FORM get_data
*----------------------------------------------------------------------*
FORM get_data.
  " Fetch data filtering by both Role Name and Approval Status
  SELECT * FROM zrecman_dl_logs
    INTO CORRESPONDING FIELDS OF TABLE gt_alv
    WHERE agr_name           IN s_role
      AND wf_approval_status IN s_status.

  IF sy-subrc <> 0.
    MESSAGE 'No logs found for the selected criteria.' TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM process_status_colors
*----------------------------------------------------------------------*
FORM process_status_colors.
  DATA: ls_color  TYPE lvc_s_scol,
        lv_status TYPE string.

  CLEAR: gv_approved_count, gv_rejected_count.

  LOOP AT gt_alv INTO gs_alv.
    CLEAR: gs_alv-color_line, ls_color.

    " Normalize status text to uppercase for safe comparison
    lv_status = gs_alv-wf_approval_status.
    TRANSLATE lv_status TO UPPER CASE.
    CONDENSE lv_status.

    " Determine ALV color and increment counters
    IF lv_status = 'APPROVED'.
      ls_color-color-col = 5. " Green
      gv_approved_count = gv_approved_count + 1.
    ELSEIF lv_status = 'REJECTED'.
      ls_color-color-col = 6. " Red
      gv_rejected_count = gv_rejected_count + 1.
    ELSEIF lv_status = 'PENDING' OR lv_status IS INITIAL.
      ls_color-color-col = 3. " Dark Yellow
    ELSE.
      ls_color-color-col = 3. " Catch-all for missing/not completed
    ENDIF.

    " Set standard color parameters
    ls_color-color-int = 0.
    ls_color-color-inv = 0.
    ls_color-fname     = 'WF_APPROVAL_STATUS'. " Color only this cell

    APPEND ls_color TO gs_alv-color_line.

    " Update the internal table
    MODIFY gt_alv FROM gs_alv TRANSPORTING color_line.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM build_header
*----------------------------------------------------------------------*
FORM build_header.
  DATA: lo_grid      TYPE REF TO cl_salv_form_layout_grid,
        lv_timestamp TYPE char40,
        lv_appr      TYPE char10,
        lv_rejc      TYPE char10.

  " Variables for custom date/time construction
  DATA: lv_day       TYPE char2,
        lv_month     TYPE char9,
        lv_year      TYPE char4,
        lv_hh        TYPE char2,
        lv_mm        TYPE char2,
        lv_ampm      TYPE char2,
        lv_time_part TYPE char15,
        lv_date_part TYPE char20.

  " 1. Extract Date Components
  lv_year = sy-datum(4).
  lv_day  = sy-datum+6(2).

  " Convert numeric month to text
  CASE sy-datum+4(2).
    WHEN '01'. lv_month = 'Jan'.
    WHEN '02'. lv_month = 'Feb'.
    WHEN '03'. lv_month = 'Mar'.
    WHEN '04'. lv_month = 'Apr'.
    WHEN '05'. lv_month = 'May'.
    WHEN '06'. lv_month = 'Jun'.
    WHEN '07'. lv_month = 'Jul'.
    WHEN '08'. lv_month = 'Aug'.
    WHEN '09'. lv_month = 'Sep'.
    WHEN '10'. lv_month = 'Oct'.
    WHEN '11'. lv_month = 'Nov'.
    WHEN '12'. lv_month = 'Dec'.
  ENDCASE.

  " 2. Extract Time Components
  lv_hh = sy-uzeit(2).
  lv_mm = sy-uzeit+2(2).

  " Determine AM / PM
  IF lv_hh >= 12.
    lv_ampm = 'PM'.
  ELSE.
    lv_ampm = 'AM'.
  ENDIF.

  " 3. Build the custom string: "15 May 2026 , 13:25 PM"
  CONDENSE lv_month.

  " Build the date portion first
  CONCATENATE lv_day lv_month lv_year INTO lv_date_part SEPARATED BY space.

  " Build the time portion
  CONCATENATE lv_hh ':' lv_mm INTO lv_time_part.
  CONCATENATE lv_time_part lv_ampm INTO lv_time_part SEPARATED BY space.

  " Combine Date, Comma, and Time exactly as requested
  CONCATENATE lv_date_part ' ,' lv_time_part INTO lv_timestamp SEPARATED BY space.
  CONDENSE lv_timestamp.

  " 4. Format Counters
  WRITE gv_approved_count TO lv_appr LEFT-JUSTIFIED.
  WRITE gv_rejected_count TO lv_rejc LEFT-JUSTIFIED.

  " 5. Build ALV Header Grid
  CREATE OBJECT lo_grid.

  " Row 1: Custom Timestamp
  lo_grid->create_label( row = 1 column = 1 text = 'Timestamp:' ).
  lo_grid->create_text(  row = 1 column = 2 text = lv_timestamp ).

  " Row 2: Status Counters
  lo_grid->create_label( row = 2 column = 1 text = 'Total Approved:' ).
  lo_grid->create_text(  row = 2 column = 2 text = lv_appr ).
  lo_grid->create_label( row = 2 column = 4 text = 'Total Rejected:' ).
  lo_grid->create_text(  row = 2 column = 5 text = lv_rejc ).

  " Assign the grid to the ALV top-of-list
  go_alv->set_top_of_list( lo_grid ).
ENDFORM.

*----------------------------------------------------------------------*
* FORM display_alv
*----------------------------------------------------------------------*
FORM display_alv.
  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = gt_alv ).
    CATCH cx_salv_msg.
      MESSAGE 'Error generating ALV grid.' TYPE 'E'.
  ENDTRY.

  " Build and set the ALV Header
  PERFORM build_header.

  " Enable standard toolbar functions
  go_func = go_alv->get_functions( ).
  go_func->set_all( abap_true ).

  " Link the color column
  TRY.
      go_columns = go_alv->get_columns( ).
      go_columns->set_color_column( 'COLOR_LINE' ).
      go_columns->set_optimize( abap_true ).
    CATCH cx_salv_data_error.
      MESSAGE 'Error setting ALV layout.' TYPE 'E'.
  ENDTRY.

  " Render the ALV
  go_alv->display( ).
ENDFORM.
