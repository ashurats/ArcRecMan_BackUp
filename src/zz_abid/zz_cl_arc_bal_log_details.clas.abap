class ZZ_CL_ARC_BAL_LOG_DETAILS definition
  public
  final
  create public .

public section.

  class-methods LOG_DISPLAY
    importing
      !IT_BAL_T_MSG type BAL_T_MSG .
  class-methods ADD_MESSAGE
    importing
      !IT_BAL_T_MSG type BAL_T_MSG .
protected section.
private section.
ENDCLASS.



CLASS ZZ_CL_ARC_BAL_LOG_DETAILS IMPLEMENTATION.


  METHOD add_message.
    DATA: lv_profile    TYPE bal_s_prof,
          lt_log_handle TYPE bal_t_logh.

    DATA: lv_log_handle TYPE balloghndl.

    " Step 1: Display popup to get profile from user
    CALL FUNCTION 'BAL_DSP_PROFILE_POPUP_GET'
      IMPORTING
        e_s_display_profile = lv_profile
      EXCEPTIONS
        OTHERS              = 1.

    IF sy-subrc <> 0.
      MESSAGE 'Display profile popup canceled or failed' TYPE 'E'.
      EXIT.
    ENDIF.

    " Step 2: Fill lt_log_handle with data
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = VALUE bal_s_log( extnumber = 'ARC_LOG' )
      IMPORTING
        e_log_handle = lv_log_handle
      EXCEPTIONS
        OTHERS       = 1.


    LOOP AT it_bal_t_msg ASSIGNING FIELD-SYMBOL(<ls_bal_s_msg>).
      CALL FUNCTION 'BAL_LOG_MSG_ADD'
        EXPORTING
          i_log_handle = lv_log_handle
          i_s_msg      = VALUE bal_s_msg( msgid = <ls_bal_s_msg>-msgid
                                          msgno = <ls_bal_s_msg>-msgno
                                          msgty = <ls_bal_s_msg>-msgty
                                          msgv1 = <ls_bal_s_msg>-msgv1 )
        EXCEPTIONS
          OTHERS       = 1.
      APPEND lv_log_handle TO lt_log_handle.
    ENDLOOP.
  ENDMETHOD.


  METHOD log_display.
*----------------------------------------------------------------------------------*
* Titel   : LOG_DISPLAY                                                           *
*----------------------------------------------------------------------------------*
* Copyright  (c) 2025 Archon Meridian GbR, Deutschland All rights reserved         *
*                                                                                  *
* Project : SAP Role Recertification Manager (“ArcRecMan”)                         *
*                                                                                  *
* Author  : Uwe Schlegel                                                           *
*                                                                                  *
* Description: This Method will be used to display the Applications logs           *
*                                                                                  *
*----------------------------------------------------------------------------------*
*    Dev.          DATE            Description                                     *
*----------------------------------------------------------------------------------*
*   <ALIABID>     20250630   Display the Applications logs                         *
*----------------------------------------------------------------------------------*
* CHANGE  HISTORY                                                                  *
*----------------------------------------------------------------------------------*
* Dev.          DATE          Description                                          *
*----------------------------------------------------------------------------------*
    DATA: lv_profile    TYPE bal_s_prof,
          lt_log_handle TYPE bal_t_logh.

    DATA: lv_log_handle TYPE balloghndl.

    " Step 1: Display popup to get profile from user
    CALL FUNCTION 'BAL_DSP_PROFILE_POPUP_GET'
      IMPORTING
        e_s_display_profile = lv_profile
      EXCEPTIONS
        OTHERS              = 1.

    IF sy-subrc <> 0.
      MESSAGE 'Display profile popup canceled or failed' TYPE 'E'.
      EXIT.
    ENDIF.

    " Step 2: Fill lt_log_handle with data
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = VALUE bal_s_log( extnumber = 'ARC_LOG' )
      IMPORTING
        e_log_handle = lv_log_handle
      EXCEPTIONS
        OTHERS       = 1.


    LOOP AT it_bal_t_msg ASSIGNING FIELD-SYMBOL(<ls_bal_s_msg>).
      CALL FUNCTION 'BAL_LOG_MSG_ADD'
        EXPORTING
          i_log_handle = lv_log_handle
          i_s_msg      = VALUE bal_s_msg( msgid = <ls_bal_s_msg>-msgid
                                          msgno = <ls_bal_s_msg>-msgno
                                          msgty = <ls_bal_s_msg>-msgty
                                          msgv1 = <ls_bal_s_msg>-msgv1 )
        EXCEPTIONS
          OTHERS       = 1.
      APPEND lv_log_handle TO lt_log_handle.
    ENDLOOP.


    " Step 3: Display the log using selected profile
    CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
      EXPORTING
        i_t_log_handle      = lt_log_handle
        i_s_display_profile = lv_profile
      EXCEPTIONS
        OTHERS              = 1.
  ENDMETHOD.
ENDCLASS.
