*&---------------------------------------------------------------------*
*& Include          Z_ARC_RECMAN_APPROVE_OUTPUT
*&---------------------------------------------------------------------*
MODULE check_auth_0200 OUTPUT.
*  DATA lv_exists TYPE c.
*  SELECT SINGLE mandt
*    FROM zrole_approvers
*    WHERE approver  = @sy-uname
*      AND smtp_addr IS NOT INITIAL
*    INTO @lv_exists.
*  IF sy-subrc <> 0.
*    MESSAGE 'You are not authorized to open Pending Approvals.' TYPE 'E'.
*  ENDIF.
ENDMODULE.

MODULE status_0200 OUTPUT.
  SET PF-STATUS 'STATUS_0200'.
  SET TITLEBAR 'TITLE_0200'.
ENDMODULE.

MODULE fetch_pending OUTPUT.
*  CLEAR lt_pending_db.
*  SELECT *
*    FROM zcomp_role_hdr
*    WHERE wf_approval_status = 'PENDING'
*    ORDER BY created_at DESCENDING, agr_name DESCENDING
*    INTO TABLE @lt_pending_db.
*
*  lt_pending_out = lt_pending_db.
**  DELETE ADJACENT DUPLICATES FROM lt_pending_out COMPARING agr_name.

******************Start of Code by Kanishk Arora***************************************

CLEAR:
  lt_pending_db,
  lt_pending_out.

DATA:
  lt_pending_roles_auth TYPE TABLE OF zcomp_role_hdr,
  lv_role_authorized    TYPE abap_bool,
  lv_role_escalated     TYPE c LENGTH 1.

SELECT *
  FROM zcomp_role_hdr
  INTO TABLE @lt_pending_roles_auth
  WHERE wf_approval_status = 'PENDING'
  ORDER BY created_at DESCENDING,
           agr_name DESCENDING.

  LOOP AT lt_pending_roles_auth INTO DATA(ls_pending_role_auth).

      CLEAR lv_role_escalated.

  SELECT SINGLE escalation_sent
    FROM zrecman_reminder
    INTO @lv_role_escalated
    WHERE agr_name  = @ls_pending_role_auth-agr_name
      AND child_agr = @ls_pending_role_auth-child_agr.

      lv_role_authorized =
    zcl_arc_owngrp_service=>is_user_in_owner_group(
      iv_user        = sy-uname
      iv_owner_group = ls_pending_role_auth-owner_group
      iv_escalated   = xsdbool(
                         lv_role_escalated = 'X' ) ).

      IF lv_role_authorized = abap_true.

    APPEND ls_pending_role_auth TO lt_pending_db.

  ENDIF.

ENDLOOP.

lt_pending_out = lt_pending_db.

******************End of Code by Kanishk Arora*****************************************

ENDMODULE.

MODULE display_alv_0200 OUTPUT.
  DATA: lt_fcat TYPE lvc_t_fcat,
        ls_fcat TYPE lvc_s_fcat.
  DATA: lv_ts1        TYPE timestamp,
        lv_date       TYPE d,
        lv_time       TYPE t,
        lv_created_at TYPE char14,
        lv_ts_start   TYPE char32,
        lv_ts_end     TYPE char32,
        lv_acc_start  TYPE char14,
        lv_acc_end    TYPE char14,
        lv_tzone      TYPE tzone.

  IF lo_cust_200 IS NOT BOUND.
    CREATE OBJECT lo_cust_200 EXPORTING container_name = 'CUSTOM_200'.
  ENDIF.

  " This function module reads your data structure and creates a field
  " catalog for all its fields.
  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZCOMP_ROLE_HDR'
    CHANGING
      ct_fieldcat      = lt_fcat.

  " --- Modify the Field Catalog to Hide Columns ---
  " Loop through the generated catalog and set the 'NO_OUT' flag
  " for the columns you want to hide.
  LOOP AT lt_fcat INTO ls_fcat.
    " Use a CASE statement to check for the field names
    CASE ls_fcat-fieldname.
        "Hide the fields
      WHEN 'WF_APPROVAL_STATUS'.
        ls_fcat-no_out = 'X'.
      WHEN 'APPROVER'.
        ls_fcat-no_out = 'X'.
      WHEN 'APPROVE_REASON'.
        ls_fcat-no_out = 'X'.
      WHEN 'REJECT_REASON'.
        ls_fcat-no_out = 'X'.
      WHEN 'APPROVED_AT'.
        ls_fcat-no_out = 'X'.
      WHEN 'REJECTED_AT'.
        ls_fcat-no_out = 'X'.
      WHEN 'CHILD_AGR_DESCR'.
        ls_fcat-no_out = 'X'.
      WHEN 'AGR_NAME_DESCR'.
        ls_fcat-no_out = 'X'.
    ENDCASE.
    MODIFY lt_fcat FROM ls_fcat.
  ENDLOOP.



  LOOP AT lt_pending_out ASSIGNING FIELD-SYMBOL(<fs_pending_out>).
    IF <fs_pending_out>-created_at IS NOT INITIAL.
      lv_in = <fs_pending_out>-created_at.
      lv_year = lv_in+0(4).
      lv_mon  = lv_in+2(2).
      lv_day  = lv_in+4(2).
      lv_hh   = lv_in+6(2).
      lv_mm   = lv_in+8(2).
      lv_ss   = lv_in+10(2).

      lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

      <fs_pending_out>-created_at = |{ lv_out }|.
    ENDIF.

    IF <fs_pending_out>-approved_at IS NOT INITIAL.
      lv_in = <fs_pending_out>-approved_at.
      lv_year = lv_in+0(4).
      lv_mon  = lv_in+2(2).
      lv_day  = lv_in+4(2).
      lv_hh   = lv_in+6(2).
      lv_mm   = lv_in+8(2).
      lv_ss   = lv_in+10(2).

      lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

      <fs_pending_out>-approved_at = |{ lv_out }|.
    ENDIF.

    IF <fs_pending_out>-rejected_at IS NOT INITIAL.
      lv_in = <fs_pending_out>-rejected_at.
      lv_year = lv_in+0(4).
      lv_mon  = lv_in+2(2).
      lv_day  = lv_in+4(2).
      lv_hh   = lv_in+6(2).
      lv_mm   = lv_in+8(2).
      lv_ss   = lv_in+10(2).

      lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

      <fs_pending_out>-rejected_at = |{ lv_out }|.
    ENDIF.

    IF <fs_pending_out>-changed_at IS NOT INITIAL.
      lv_in = <fs_pending_out>-changed_at.
      lv_year = lv_in+0(4).
      lv_mon  = lv_in+2(2).
      lv_day  = lv_in+4(2).
      lv_hh   = lv_in+6(2).
      lv_mm   = lv_in+8(2).
      lv_ss   = lv_in+10(2).

      lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

      <fs_pending_out>-changed_at = |{ lv_out }|.
    ENDIF.

  ENDLOOP.


  " --- Display the ALV with the Modified Field Catalog ---
  IF lo_alv_200 IS NOT BOUND.
    CREATE OBJECT lo_alv_200 EXPORTING i_parent = lo_cust_200.
  ENDIF.

  lo_alv_200->set_table_for_first_display(
    EXPORTING
      i_structure_name              = 'ZCOMP_ROLE_HDR'
    CHANGING
      it_outtab                     = lt_pending_out
      it_fieldcatalog               = lt_fcat
  ).
  IF sy-subrc <> 0.
*   MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*     WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.

  PERFORM Logo.


ENDMODULE.

*FORM LOAD_PIC_FROM_DB CHANGING URL.
*  DATA QUERY_TABLE LIKE W3QUERY OCCURS 1 WITH HEADER LINE.
*  DATA HTML_TABLE LIKE W3HTML OCCURS 1.
*  DATA RETURN_CODE LIKE  W3PARAM-RET_CODE.
*  DATA CONTENT_TYPE LIKE  W3PARAM-CONT_TYPE.
*  DATA CONTENT_LENGTH LIKE  W3PARAM-CONT_LEN.
*  DATA PIC_DATA LIKE W3MIME OCCURS 0.
*  DATA PIC_SIZE TYPE I.
*
*  REFRESH QUERY_TABLE.
*  QUERY_TABLE-NAME = '_OBJECT_ID'.
**  QUERY_TABLE-VALUE = 'ENJOYSAP_LOGO'.
*  QUERY_TABLE-VALUE = 'ARCHONMERIDIAN-LOGO'.
*  APPEND QUERY_TABLE.
*
*##FM_OLDED
*  CALL FUNCTION 'WWW_GET_MIME_OBJECT'
*       TABLES
*            QUERY_STRING        = QUERY_TABLE
*            HTML                = HTML_TABLE
*            MIME                = PIC_DATA
*       CHANGING
*            RETURN_CODE         = RETURN_CODE
*            CONTENT_TYPE        = CONTENT_TYPE
*            CONTENT_LENGTH      = CONTENT_LENGTH
*       EXCEPTIONS
*            OBJECT_NOT_FOUND    = 1
*            PARAMETER_NOT_FOUND = 2
*            OTHERS              = 3.
*  if sy-subrc = 0.
*    PIC_SIZE = CONTENT_LENGTH.
*  endif.
*
*CALL FUNCTION 'DP_CREATE_URL'
*         EXPORTING
*              TYPE     = 'image'
*              SUBTYPE  = cndp_sap_tab_unknown
*              SIZE     = PIC_SIZE
*              lifetime = cndp_lifetime_transaction
*         TABLES
*              DATA     = PIC_DATA
*         CHANGING
*              URL      = URL
*##FM_SUBRC_OK
*         EXCEPTIONS
*              others   = 1.
*
*
*ENDFORM.                    " LOAD_PIC_FROM_DB
*&---------------------------------------------------------------------*
*& Form Logo
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM Logo .
  IF init IS INITIAL.
* create the custom container
    CREATE OBJECT container
      EXPORTING
        container_name = 'CUSTOM'.
* create the picture control
    CREATE OBJECT picture
      EXPORTING
        parent = container.

* Request an URL from the data provider by exporting the pic_data.

    CLEAR url.
    PERFORM load_pic_from_db CHANGING url.

* load picture
    CALL METHOD picture->load_picture_from_url
      EXPORTING
        url = url.
    init = 'X'.

    CALL METHOD cl_gui_cfw=>flush
      EXCEPTIONS
        cntl_system_error = 1
        cntl_error        = 2.
    IF sy-subrc <> 0.
* error handling
    ENDIF.
  ENDIF.
ENDFORM.

FORM load_pic_from_db CHANGING url.
  DATA query_table LIKE w3query OCCURS 1 WITH HEADER LINE.
  DATA html_table LIKE w3html OCCURS 1.
  DATA return_code LIKE  w3param-ret_code.
  DATA content_type LIKE  w3param-cont_type.
  DATA content_length LIKE  w3param-cont_len.
  DATA pic_data LIKE w3mime OCCURS 0.
  DATA pic_size TYPE i.

  REFRESH query_table.
  query_table-name = '_OBJECT_ID'.
  query_table-value = 'ENJOYSAP_LOGO'.
*  QUERY_TABLE-VALUE = 'ARCHON_LOGO'.
  APPEND query_table.

  ##FM_OLDED
  CALL FUNCTION 'WWW_GET_MIME_OBJECT'
    TABLES
      query_string        = query_table
      html                = html_table
      mime                = pic_data
    CHANGING
      return_code         = return_code
      content_type        = content_type
      content_length      = content_length
    EXCEPTIONS
      object_not_found    = 1
      parameter_not_found = 2
      OTHERS              = 3.
  IF sy-subrc = 0.
    pic_size = content_length.
  ENDIF.

  CALL FUNCTION 'DP_CREATE_URL'
    EXPORTING
      type     = 'image'
      subtype  = cndp_sap_tab_unknown
      size     = pic_size
      lifetime = cndp_lifetime_transaction
    TABLES
      data     = pic_data
    CHANGING
      url      = url
      ##FM_SUBRC_OK
    EXCEPTIONS
      OTHERS   = 1.


ENDFORM.                    " LOAD_PIC_FROM_DB
*&---------------------------------------------------------------------*
*& Module STATUS_0300 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
 SET PF-STATUS 'STATUS_0300'.
* SET TITLEBAR 'xxx'.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module FETCH_OWNGRP_PENDING OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE fetch_owngrp_pending OUTPUT.
** SET PF-STATUS 'xxxxxxxx'.
** SET TITLEBAR 'xxx'.
*    CLEAR lt_owngrp_pending.
*
*  SELECT *
*    FROM zcomp_owngrp_req
*    INTO TABLE @lt_owngrp_pending
*    WHERE final_status = 'PENDING'
*AND (
*      ( old_approver = @sy-uname
*        AND old_approver_status = 'PENDING' )
*
*   OR
*
*      ( new_approver = @sy-uname
*        AND new_approver_status = 'PENDING' )
*    )
*    ORDER BY requested_at DESCENDING.

  CLEAR lt_owngrp_pending.

DATA:
  lt_all_pending TYPE TABLE OF zcomp_owngrp_req,
  lv_old_auth    TYPE abap_bool,
  lv_new_auth    TYPE abap_bool.

SELECT *
  FROM zcomp_owngrp_req
  INTO TABLE @lt_all_pending
  WHERE final_status = 'PENDING'
  ORDER BY requested_at DESCENDING.

LOOP AT lt_all_pending INTO DATA(ls_pending_req).

 lv_old_auth =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = sy-uname
    iv_owner_group = ls_pending_req-old_owner_group
    iv_escalated   = xsdbool(
                       ls_pending_req-escalation_sent = 'X' ) ).

  lv_new_auth =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = sy-uname
    iv_owner_group = ls_pending_req-new_owner_group
    iv_escalated   = xsdbool(
                       ls_pending_req-escalation_sent = 'X' ) ).

  IF ( lv_old_auth = abap_true
     AND ls_pending_req-old_approver_status = 'PENDING' )

 OR

   ( lv_new_auth = abap_true
     AND ls_pending_req-new_approver_status = 'PENDING' ).

  APPEND ls_pending_req TO lt_owngrp_pending.

ENDIF.

ENDLOOP.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module DISPLAY_ALV_0300 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE display_alv_0300 OUTPUT.
* SET PF-STATUS 'xxxxxxxx'.
* SET TITLEBAR 'xxx'.

  DATA: lt_fcat_0300 TYPE lvc_t_fcat.

  IF lo_cust_300 IS NOT BOUND.
    CREATE OBJECT lo_cust_300
      EXPORTING
        container_name = 'CC_ALV_300'.
  ENDIF.

  IF lo_alv_300 IS NOT BOUND.
    CREATE OBJECT lo_alv_300
      EXPORTING
        i_parent = lo_cust_300.
  ENDIF.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'ZCOMP_OWNGRP_REQ'
    CHANGING
      ct_fieldcat      = lt_fcat_0300.

  LOOP AT lt_fcat_0300 ASSIGNING FIELD-SYMBOL(<ls_fcat>).

  CASE <ls_fcat>-fieldname.

    WHEN 'MANDT'.
  <ls_fcat>-no_out = 'X'.

    WHEN 'OLD_OWNER_GROUP'.
    <ls_fcat>-coltext   = 'Old Owner Group'.
    <ls_fcat>-scrtext_s = 'Old Owner'.
    <ls_fcat>-scrtext_m = 'Old Owner Group'.
    <ls_fcat>-scrtext_l = 'Old Owner Group'.

  WHEN 'NEW_OWNER_GROUP'.
    <ls_fcat>-coltext   = 'New Owner Group'.
    <ls_fcat>-scrtext_s = 'New Owner'.
    <ls_fcat>-scrtext_m = 'New Owner Group'.
    <ls_fcat>-scrtext_l = 'New Owner Group'.

  WHEN 'OLD_APPROVER'.
    <ls_fcat>-no_out = 'X'.

  WHEN 'NEW_APPROVER'.
    <ls_fcat>-no_out = 'X'.

  WHEN 'OLD_APPROVER_STATUS'.
    <ls_fcat>-coltext   = 'Old Approver Status'.

  WHEN 'NEW_APPROVER_STATUS'.
    <ls_fcat>-coltext   = 'New Approver Status'.

  WHEN 'OLD_APPROVED_AT'.
  <ls_fcat>-no_out = 'X'.

WHEN 'NEW_APPROVED_AT'.
  <ls_fcat>-no_out = 'X'.

WHEN 'REJECT_REASON'.
  <ls_fcat>-no_out = 'X'.

WHEN 'FINAL_STATUS'.
  <ls_fcat>-no_out = 'X'.

  WHEN 'REQUESTED_BY'.
    <ls_fcat>-coltext   = 'Requested By'.

  WHEN 'REQUESTED_AT'.
    <ls_fcat>-coltext   = 'Requested At'.

    WHEN 'ESCALATION_SENT'.
    <ls_fcat>-coltext   = 'Escalation Sent'.
    <ls_fcat>-scrtext_s = 'Escalated'.
    <ls_fcat>-scrtext_m = 'Escalation Sent'.
    <ls_fcat>-scrtext_l = 'Escalation Sent'.


  ENDCASE.

ENDLOOP.

  lo_alv_300->set_table_for_first_display(
    EXPORTING
      i_structure_name = 'ZCOMP_OWNGRP_REQ'
    CHANGING
      it_outtab        = lt_owngrp_pending
      it_fieldcatalog  = lt_fcat_0300 ).


ENDMODULE.
