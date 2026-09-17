FUNCTION zz_arc_ff_change_doc_report.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IT_USER) TYPE  RSELOPTION OPTIONAL
*"     REFERENCE(IT_TCODE) TYPE  RSELOPTION OPTIONAL
*"     REFERENCE(IV_DATE_START) TYPE  SYST_DATUM OPTIONAL
*"     REFERENCE(IV_DATE_END) TYPE  SYST_DATUM OPTIONAL
*"     REFERENCE(IV_TIME_START) TYPE  SYST_UZEIT OPTIONAL
*"     REFERENCE(IV_TIME_END) TYPE  SYST_UZEIT OPTIONAL
*"  TABLES
*"      ET_DATA TYPE  ZZARC_FF_CHNGDOC_TT
*"  CHANGING
*"     REFERENCE(ET_RETURN) TYPE  BAPIRET2_T
*"----------------------------------------------------------------------
****"----------------------------------------------------------------------

  CLEAR: et_data, et_return.

***  "------------------------------------------------------------
***  " Validate inputs
***  "------------------------------------------------------------
***  IF iv_date_start IS INITIAL OR iv_date_end IS INITIAL
***  OR iv_time_start IS INITIAL OR iv_time_end IS INITIAL.
***
***    PERFORM add_return USING
***      'E' 'ZMSG' '001'
***      'Start date/time and End date/time are mandatory'
***      CHANGING et_return.
***
***    RETURN.
***  ENDIF.
***
***  IF iv_date_start > iv_date_end
***   OR ( iv_date_start = iv_date_end AND iv_time_start > iv_time_end ).
***
***    PERFORM add_return USING
***      'E' 'ZMSG' '001'
***      'Start date/time must be <= End date/time'
***      CHANGING et_return.
***
***    RETURN.
***  ENDIF.
***
***  "------------------------------------------------------------
***  " Read CDHDR
***  "------------------------------------------------------------
***  DATA: lt_cdhdr TYPE STANDARD TABLE OF cdhdr,
***        lt_cdpos TYPE STANDARD TABLE OF cdpos.
***
***  IF it_user IS NOT INITIAL.
***    SELECT *
***      FROM cdhdr
***      INTO TABLE @lt_cdhdr
***      WHERE username = @iv_user
***        AND udate BETWEEN @iv_date_start AND @iv_date_end
***        AND utime BETWEEN @iv_time_start AND @iv_time_end.
***  ENDIF.
***
***  IF lt_cdhdr IS INITIAL.
***    PERFORM add_return USING
***      'I' 'ZMSG' '002'
***      'No change documents found for given selection'
***      CHANGING et_return.
***    RETURN.
***  ENDIF.
***
***  SORT lt_cdhdr BY objectclas objectid changenr.
***
***  "------------------------------------------------------------
***  " Read CDPOS
***  "------------------------------------------------------------
***  SELECT *
***    FROM cdpos
***    INTO TABLE @lt_cdpos
***    FOR ALL ENTRIES IN @lt_cdhdr
***    WHERE objectclas = @lt_cdhdr-objectclas
***      AND objectid   = @lt_cdhdr-objectid
***      AND changenr   = @lt_cdhdr-changenr.
***
***  IF lt_cdpos IS INITIAL.
***    PERFORM add_return USING
***      'I' 'ZMSG' '003'
***      'No change details found for given selection'
***      CHANGING et_return.
***    RETURN.
***  ENDIF.
***
***  SORT lt_cdpos BY objectclas objectid changenr.
***
***  LOOP AT lt_cdpos INTO DATA(ls_pos).
***    READ TABLE lt_cdhdr INTO DATA(ls_hdr)
***         WITH KEY objectclas = ls_pos-objectclas
***                  objectid   = ls_pos-objectid
***                  changenr   = ls_pos-changenr
***         BINARY SEARCH.
***
***    IF sy-subrc = 0.
***      DATA(lv_chngtxt) = SWITCH string( ls_pos-chngind
***        WHEN 'U' THEN 'Update'
***        WHEN 'I' THEN 'Insert'
***        WHEN 'E' THEN 'Delete (single field documentation)'
***        WHEN 'D' THEN 'Delete'
***        WHEN 'J' THEN 'Insert (single field documentation)'
***        ELSE 'Unknown' ).
***
***      APPEND VALUE #(
***        username   = ls_hdr-username
***        objectclas = ls_hdr-objectclas
***        objectid   = ls_hdr-objectid
***        tcode      = ls_hdr-tcode
***        udate      = ls_hdr-udate
***        utime      = ls_hdr-utime
***        tzone      = sy-zonlo
***        tabname    = ls_pos-tabname
***        fname      = ls_pos-fname
***        tabkey     = ls_pos-tabkey
***        chngind    = ls_pos-chngind
***        chngtxt    = lv_chngtxt
***        value_new  = ls_pos-value_new
***        value_old  = ls_pos-value_old
***      ) TO et_data.
***    ENDIF.
***  ENDLOOP.
***
***  " Optional success message
****  IF et_data IS NOT INITIAL.
****    PERFORM add_return USING
****      'S' 'ZMSG' '000'
****      |Records found: { lines( et_data ) }|
****      CHANGING et_return.
****  ENDIF.
***
***ENDFUNCTION.
***FORM add_return
***  USING    iv_type    TYPE bapiret2-type
***           iv_id      TYPE symsgid
***           iv_number  TYPE symsgno
***           iv_message TYPE string
***  CHANGING ct_return  TYPE bapiret2_t.
***
***  APPEND VALUE #( type    = iv_type
***                  id      = iv_id
***                  number  = iv_number
***                  message = iv_message ) TO ct_return.
***ENDFORM.

*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IT_USER) TYPE  RSELOPTION OPTIONAL
*"     VALUE(IT_TCODE) TYPE  RSELOPTION OPTIONAL
*"     REFERENCE(IV_DATE_START) TYPE  SYST_DATUM OPTIONAL
*"     REFERENCE(IV_DATE_END) TYPE  SYST_DATUM OPTIONAL
*"     REFERENCE(IV_TIME_START) TYPE  SYST_UZEIT OPTIONAL
*"     REFERENCE(IV_TIME_END) TYPE  SYST_UZEIT OPTIONAL
*"  EXPORTING
*"     VALUE(ET_DATA) TYPE  ZZARC_FF_CHNGDOC_TT
*"  EXCEPTIONS
*"      NOT_FOUND
*"----------------------------------------------------------------------

  DATA: lt_cdhdr TYPE TABLE OF cdhdr,
        lt_cdpos TYPE TABLE OF cdpos.

  " Local ranges to handle the scalar start/end inputs for Open SQL
  DATA: lt_r_date TYPE RANGE OF cdhdr-udate,
        lt_r_time TYPE RANGE OF cdhdr-utime.

  CLEAR ET_DATA.

  " 1. Build Date Range from Scalar Inputs
  IF iv_date_start IS NOT INITIAL OR iv_date_end IS NOT INITIAL.
    APPEND VALUE #(
      sign   = 'I'
      option = COND #( WHEN iv_date_start IS NOT INITIAL AND iv_date_end IS NOT INITIAL THEN 'BT'
                       WHEN iv_date_start IS NOT INITIAL THEN 'GE'
                       ELSE 'LE' )
      low    = iv_date_start
      high   = iv_date_end
    ) TO lt_r_date.
  ENDIF.

  " 2. Build Time Range from Scalar Inputs
  IF iv_time_start IS NOT INITIAL OR iv_time_end IS NOT INITIAL.
    APPEND VALUE #(
      sign   = 'I'
      option = COND #( WHEN iv_time_start IS NOT INITIAL AND iv_time_end IS NOT INITIAL THEN 'BT'
                       WHEN iv_time_start IS NOT INITIAL THEN 'GE'
                       ELSE 'LE' )
      low    = iv_time_start
      high   = iv_time_end
    ) TO lt_r_time.
  ENDIF.

  " Step 1: Read CDHDR
  " Note: If a range table is empty, Open SQL ignores it (selects all), which is perfect for optional parameters.
  SELECT *
    INTO TABLE @lt_cdhdr
    FROM cdhdr
   WHERE username IN @it_user
     AND tcode    IN @it_tcode
     AND udate    IN @lt_r_date
     AND utime    IN @lt_r_time.

  IF sy-subrc <> 0.
    RAISE not_found.
  ENDIF.

  SORT lt_cdhdr BY objectclas objectid changenr.

  " Step 2: Read CDPOS
  SELECT *
    INTO TABLE @lt_cdpos
    FROM cdpos
     FOR ALL ENTRIES IN @lt_cdhdr
   WHERE objectclas = @lt_cdhdr-objectclas
     AND objectid   = @lt_cdhdr-objectid
     AND changenr   = @lt_cdhdr-changenr.

  IF sy-subrc <> 0.
    RAISE not_found.
  ENDIF.

  SORT lt_cdpos BY objectclas objectid changenr.

*--------------------------------------------------------------------*
* Step 3: Combine Results
*--------------------------------------------------------------------*
  LOOP AT lt_cdpos INTO DATA(ls_pos).
    READ TABLE lt_cdhdr INTO DATA(ls_hdr)
         WITH KEY objectclas = ls_pos-objectclas
                  objectid   = ls_pos-objectid
                  changenr   = ls_pos-changenr
         BINARY SEARCH.

    IF sy-subrc = 0.

      " Determine Description
      DATA(lv_chngtxt) = SWITCH string( ls_pos-chngind
        WHEN 'U' THEN 'Update'
        WHEN 'I' THEN 'Insert'
        WHEN 'E' THEN 'Delete (single field documentation)'
        WHEN 'D' THEN 'Delete'
        WHEN 'J' THEN 'Insert (single field documentation)'
        ELSE 'Unknown' ).

      " Build record and append to Exporting table
      APPEND VALUE #(
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
      ) TO ET_DATA.

    ENDIF.
  ENDLOOP.

ENDFUNCTION.
