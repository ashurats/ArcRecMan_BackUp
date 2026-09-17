*&---------------------------------------------------------------------*
*& Report Z_ARC_RECMAN_DEMO2
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_arc_recman_demo2.
TYPES: ty_user_range    TYPE RANGE OF sy-uname,
       ty_tcode_range   TYPE RANGE OF tcode,
       ty_program_range TYPE RANGE OF program_id.
DATA: lt_range_user  TYPE ty_user_range,
      ls_range_user  LIKE LINE OF lt_range_user,
      lt_range_tcode TYPE ty_tcode_range,
      ls_range_tcode LIKE LINE OF lt_range_tcode,
      lt_range_repid TYPE ty_program_range,
      ls_range_repid LIKE LINE OF lt_range_repid.
DATA: lt_values TYPE vrm_values,
      ls_value  LIKE LINE OF lt_values,
      lv_prio   TYPE x.
CONSTANTS:
  cs_dummy TYPE cl_syslog=>fc VALUE IS INITIAL.


SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (31) TEXT-005 FOR FIELD date_fr.
    PARAMETERS: date_fr TYPE dats.
    SELECTION-SCREEN COMMENT (5) TEXT-007.
    PARAMETERS: time_fr TYPE tims.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT (31) TEXT-006 FOR FIELD date_to.
    PARAMETERS: date_to TYPE dats.
    SELECTION-SCREEN COMMENT (5) TEXT-007.
    PARAMETERS: time_to TYPE tims.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b1.

SELECT-OPTIONS: s_user  FOR sy-uname OBLIGATORY MATCHCODE OBJECT sx_user,
                s_tcode FOR sy-tcode,
                s_repid FOR sy-cprog.

PARAMETERS: p_prio TYPE c LENGTH 2 AS LISTBOX VISIBLE LENGTH 10.

INITIALIZATION.
*-> Set initial date and time
  IF date_fr IS INITIAL AND time_fr IS INITIAL.
    IF sy-uzeit >= 7200.
      date_fr = sy-datum.
      time_fr = sy-uzeit - 7200.
    ELSE. " between 00:00:00 and 00:59:59
      date_fr = sy-datum - 1.
      time_fr = '230000'.
    ENDIF.
    time_fr = ( time_fr / 3600 ) * 3600.
  ENDIF.

  PERFORM init_dropdown.

FORM init_dropdown.

  " Eintrag 01
  ls_value-key  = '01'.
  ls_value-text = '01 - Very High Priority'.
  APPEND ls_value TO lt_values.

  " Eintrag 02
  ls_value-key  = '02'.
  ls_value-text = '02 -  High Priority'.
  APPEND ls_value TO lt_values.

  " Eintrag 04
  ls_value-key  = '04'.
  ls_value-text = '04 - Warning'.
  APPEND ls_value TO lt_values.

  " Eintrag 08
  ls_value-key  = '08'.
  ls_value-text = '08 - Information'.
  APPEND ls_value TO lt_values.

  " Drop-Down setzen
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'P_PRIO'     " Name des Parameters
      values = lt_values
    EXCEPTIONS
      OTHERS = 1.
ENDFORM.

START-OF-SELECTION.

  DATA: l_datetime_fr TYPE rslgtime VALUE cl_syslog_filter=>emptyfilter_datetime,
        l_datetime_to TYPE rslgtime VALUE cl_syslog_filter=>emptyfilter_datetime.


  IF date_fr IS NOT INITIAL.
    CONCATENATE date_fr time_fr INTO l_datetime_fr.
  ENDIF.
  IF date_to IS NOT INITIAL.
    CONCATENATE date_to time_to INTO l_datetime_to.
  ENDIF.


  CASE p_prio.
    WHEN '01'.
      lv_prio = '01'.  "Very High Priority
    WHEN '02'.
      lv_prio = '02'.  "High Priority
    WHEN '04'.
      lv_prio = '04'.  "Warning
    WHEN '08'.
      lv_prio = '08'.  "Information
    WHEN OTHERS.
*      WRITE: / 'No valid selection.'.
  ENDCASE.

  IF s_user-low IS NOT INITIAL.
    ls_range_user-sign   = 'I'.      " Include
    ls_range_user-option = 'EQ'.     " Equal
    ls_range_user-low    = s_user-low.
    CLEAR ls_range_user-high.
    APPEND ls_range_user TO lt_range_user.
  ENDIF.

  IF s_tcode-low IS NOT INITIAL.
    ls_range_tcode-sign   = 'I'.      " Include
    ls_range_tcode-option = 'EQ'.     " Equal
    ls_range_tcode-low    = s_tcode-low.
    CLEAR ls_range_tcode-high.
    APPEND ls_range_tcode TO lt_range_tcode.
  ENDIF.

  IF s_repid-low IS NOT INITIAL.
    ls_range_repid-sign   = 'I'.      " Include
    ls_range_repid-option = 'EQ'.     " Equal
    ls_range_repid-low    = s_repid-low.
    CLEAR ls_range_repid-high.
    APPEND ls_range_repid TO lt_range_repid.
  ENDIF.

  DATA(lo_log_filter) = NEW cl_syslog_filter( ).

  lo_log_filter->set_filter_severity( i_severity = lv_prio ).
  IF lt_range_tcode IS NOT INITIAL.
    lo_log_filter->set_range_tcode( im_range_tcode = lt_range_tcode ).
  ENDIF.
  IF lt_range_repid IS NOT INITIAL.
    lo_log_filter->set_range_program( im_range_progid = lt_range_repid ).
  ENDIF.
  IF lt_range_user IS NOT INITIAL.
    lo_log_filter->set_range_user( im_range_user = lt_range_user ).
  ENDIF.

  lo_log_filter->set_filter_datetime(
        EXPORTING im_datetime_from = |{ l_datetime_fr }| " system time zone or UTC
                  im_datetime_to   = |{ l_datetime_to }|  ). " empty = till now
  DATA(lo_log) = cl_syslog=>get_instance_by_filter( lo_log_filter ).
  lo_log->read_entries( cs_dummy ).

  DATA(log_entries) = lo_log->get_entries( ).


*--------------------------------------------------------------------*
  DATA: lo_alv TYPE REF TO cl_salv_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = log_entries ).

*-> Ausblenden von Spalte
      DATA(lo_columns) = lo_alv->get_columns( ).
      DATA: lo_column TYPE REF TO cl_salv_column.

      TRY.
          lo_column ?= lo_columns->get_column( 'INSTANCE' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'WP_TYPE' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'PROCESSID' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SEVERITY' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'MESSAGEID' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'DEVCLASS' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'CLASID' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'MONBEW' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'MONKAT' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'LINECOLOR' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'TERMINAL' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGDATA' ).
          lo_column->set_visible( abap_false ).


          lo_column ?= lo_columns->get_column( 'SLGFTYPE' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGPASSPORT' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGROOTCONTEXT' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGCONNECTION' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGCONNECTIONCOUNTER' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGPROC' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'SLGMODE' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'ERRNO' ).
          lo_column->set_visible( abap_false ).

          lo_column ?= lo_columns->get_column( 'ERRORNAME' ).
          lo_column->set_visible( abap_false ).

*-> Spalte Länge
          lo_column ?= lo_columns->get_column( 'ICON' ).
          lo_column->set_output_length( 3 ).   " Länge = 5 Zeichen

          lo_column ?= lo_columns->get_column( 'TEXT' ).
          lo_column->set_output_length( 80 ).   " Länge = 5 Zeichen

        CATCH cx_salv_not_found INTO DATA(lx_notfound).
          MESSAGE lx_notfound->get_text( ) TYPE 'I'.
      ENDTRY.

      DATA(lo_func_list) = lo_alv->get_functions( ).
      lo_func_list->set_all( abap_true ).

      DATA(lo_display) = lo_alv->get_display_settings( ).
      lo_display->set_list_header( |Selected User: { s_user-low } Current Date: { sy-datum }  Current Time: { sy-uzeit }| ).

*->  Anzeigen ALV
      lo_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.
