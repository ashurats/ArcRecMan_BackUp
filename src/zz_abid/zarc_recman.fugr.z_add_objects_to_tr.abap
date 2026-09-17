FUNCTION z_add_objects_to_tr.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(IV_TR_DESC) TYPE  AS4TEXT OPTIONAL
*"     REFERENCE(IV_TR_ID) TYPE  TRKORR OPTIONAL
*"     REFERENCE(IV_SELECTED_TR) TYPE  TRKORR OPTIONAL
*"  EXPORTING
*"     REFERENCE(EV_ORDER) LIKE  E070-TRKORR
*"     REFERENCE(EV_TASK) LIKE  E070-TRKORR
*"----------------------------------------------------------------------

*"     VALUE(IV_CATEGORY) LIKE  E070-KORRDEV DEFAULT 'CUST'
  DATA: lv_order_type  LIKE e070-trfunction,
        lv_task_type   LIKE e070-trfunction,
        lv_externalps  TYPE ctsproject-externalps,
        lv_externalid  TYPE ctsproject-externalid,
        lv_ps_order    TYPE trkorr_p,
        lv_ps_use_order_project TYPE trkorr_p,
        lt_objects     TYPE tredt_objects,
        lt_keys        TYPE tredt_keys,
        lv_e070        LIKE e070,
        lt_e071        LIKE e071     OCCURS 0        WITH HEADER LINE,
        lt_e071k       LIKE e071k    OCCURS 0        WITH HEADER LINE,
        lt_e070use     LIKE e070use  OCCURS 0        WITH HEADER LINE.

    CALL FUNCTION 'TR_TASK_GET'
       EXPORTING
            iv_username      = sy-uname
            iv_category      = 'CUST'
            iv_client        = sy-mandt
       TABLES
            tt_e070use       = lt_e070use
       EXCEPTIONS
            invalid_username = 01
            invalid_category = 01
            invalid_client   = 01.

    CALL FUNCTION 'TRINT_ORDER_CHOICE'
       EXPORTING
            wi_simulation          = ' '
            wi_order_type          = 'W' "lv_order_type
            wi_task_type           = 'Q' "lv_task_type
            wi_category            = 'CUST' "iv_category
            wi_client              = sy-mandt
            wi_order               = ' '
            wi_e070                = lv_e070
            wi_suppress_dialog     = 'X'
            wi_cli_dep             = 'X' "iv_cli_dep
            wi_remove_locks        = 'X'
            wi_display_button      = ' '
            iv_current_project     = lv_ps_order
            iv_project_check       = ' ' "iv_project_check
       IMPORTING
            we_order               = ev_order
            we_task                = ev_task
       TABLES
            wt_e071                = lt_e071
            wt_e071k               = lt_e071k
       EXCEPTIONS
            no_correction_selected = 01
            object_append_error    = 01.
  IF sy-subrc <> 0.
    "current_message_raising no_correction_selected.
  ENDIF.

ENDFUNCTION.
