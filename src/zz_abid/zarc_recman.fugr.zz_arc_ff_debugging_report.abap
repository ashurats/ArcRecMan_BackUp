FUNCTION zz_arc_ff_debugging_report.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_USER) TYPE  UNAME
*"     REFERENCE(IV_TCODE) TYPE  TCODE OPTIONAL
*"     REFERENCE(IV_REPID) TYPE  CPROG OPTIONAL
*"     REFERENCE(IV_PRIO) TYPE  CHAR2 OPTIONAL
*"     REFERENCE(IV_DATE_START) TYPE  SYST_DATUM OPTIONAL
*"     REFERENCE(IV_DATE_END) TYPE  SYST_DATUM OPTIONAL
*"     REFERENCE(IV_TIME_START) TYPE  SYST_UZEIT OPTIONAL
*"     REFERENCE(IV_TIME_END) TYPE  SYST_UZEIT OPTIONAL
*"  EXPORTING
*"     REFERENCE(ET_LOG_ENTRIES) TYPE  RSLGENTR_TAB
*"----------------------------------------------------------------------
  DATA: lt_values TYPE vrm_values,
        ls_value  LIKE LINE OF lt_values,
        lv_prio   TYPE x.
  TYPES: ty_user_range    TYPE RANGE OF sy-uname,
         ty_tcode_range   TYPE RANGE OF tcode,
         ty_program_range TYPE RANGE OF program_id.
  DATA: lt_range_user  TYPE ty_user_range,
        ls_range_user  LIKE LINE OF lt_range_user,
        lt_range_tcode TYPE ty_tcode_range,
        ls_range_tcode LIKE LINE OF lt_range_tcode,
        lt_range_repid TYPE ty_program_range,
        ls_range_repid LIKE LINE OF lt_range_repid.
  CONSTANTS:
    cs_dummy TYPE cl_syslog=>fc VALUE IS INITIAL.


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

**************************Access Start*******************************

  DATA: l_datetime_fr TYPE rslgtime VALUE cl_syslog_filter=>emptyfilter_datetime,
        l_datetime_to TYPE rslgtime VALUE cl_syslog_filter=>emptyfilter_datetime.

  DATA: lv_date_start TYPE syst_datum,
        lv_time_start TYPE syst_uzeit,
        lv_date_end   TYPE syst_datum,
        lv_time_end   TYPE syst_uzeit.
  DATA: lv_timestamp_start TYPE tzonref-tstamps.
  DATA: lv_timestamp_end TYPE tzonref-tstamps.

  CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
    EXPORTING
      i_datlo     = IV_DATE_START
      i_timlo     = IV_TIME_START
*     i_tzone     = ls_fire_req-req_tzone
      i_tzone     = 'UTC'
    IMPORTING
      e_timestamp = lv_timestamp_start.

  IF lv_timestamp_start IS NOT INITIAL.
    CALL FUNCTION 'IB_CONVERT_FROM_TIMESTAMP'
      EXPORTING
        i_timestamp = lv_timestamp_start
        i_tzone     = 'INDIA'
      IMPORTING
        e_datlo     = lv_date_start
        e_timlo     = lv_time_start.
  ENDIF.

**************************Access End*******************************
  CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
    EXPORTING
      i_datlo     = IV_DATE_END
      i_timlo     = IV_TIME_END
      i_tzone     = 'UTC'
    IMPORTING
      e_timestamp = lv_timestamp_end.

  IF lv_timestamp_end IS NOT INITIAL.
    CALL FUNCTION 'IB_CONVERT_FROM_TIMESTAMP'
      EXPORTING
        i_timestamp = lv_timestamp_end
        i_tzone     = 'INDIA' "sy-zonlo
      IMPORTING
        e_datlo     = lv_date_end
        e_timlo     = lv_time_end.
  ENDIF.

  IF IV_DATE_START IS NOT INITIAL.
    CONCATENATE lv_date_start lv_time_start INTO l_datetime_fr.
  ENDIF.
  IF IV_DATE_END IS NOT INITIAL.
    CONCATENATE lv_date_end lv_time_end INTO l_datetime_to.
  ENDIF.

  CASE iv_prio.
    WHEN '01'.
      lv_prio = '01'.  "Very High Priority
    WHEN '02'.
      lv_prio = '02'.  "High Priority
    WHEN '04'.
      lv_prio = '04'.  "Warning
    WHEN '08'.
      lv_prio = '08'.  "Information
    WHEN ''.
  ENDCASE.

  IF iv_user IS NOT INITIAL.
    ls_range_user-sign   = 'I'.      " Include
    ls_range_user-option = 'EQ'.     " Equal
    ls_range_user-low    = iv_user.
    CLEAR ls_range_user-high.
    APPEND ls_range_user TO lt_range_user.
  ENDIF.

  IF iv_tcode IS NOT INITIAL.
    ls_range_tcode-sign   = 'I'.      " Include
    ls_range_tcode-option = 'EQ'.     " Equal
    ls_range_tcode-low    = iv_tcode.
    CLEAR ls_range_tcode-high.
    APPEND ls_range_tcode TO lt_range_tcode.
  ENDIF.

  IF iv_repid IS NOT INITIAL.
    ls_range_repid-sign   = 'I'.      " Include
    ls_range_repid-option = 'EQ'.     " Equal
    ls_range_repid-low    = iv_repid.
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

  et_log_entries = lo_log->get_entries( ).

***  FIELD-SYMBOLS <lt_er> TYPE rslgentr_tab.
***
***  CREATE DATA er_data LIKE lt_log_entries.
***  ASSIGN er_data->* TO <lt_er>.
***  IF sy-subrc = 0.
***    "Fill the changing parameter via the field-symbol
***    <lt_er> = lt_log_entries.                 "overwrite
***    "or:
***    "APPEND LINES OF lt_logs TO <lt_er>.  "append
***  ENDIF.

ENDFUNCTION.
