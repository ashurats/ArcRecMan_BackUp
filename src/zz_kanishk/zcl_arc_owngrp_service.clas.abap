CLASS zcl_arc_owngrp_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CLASS-METHODS get_owner_details
      IMPORTING
        VALUE(iv_role_name)   TYPE agr_name
        VALUE(iv_owner_group) TYPE zz_owner_group
      EXPORTING
        VALUE(ev_owner_id)    TYPE zrecman_owners-owner_id
        VALUE(ev_owner_email) TYPE zrecman_owners-owner_email.

    CLASS-METHODS create_or_update_request
      IMPORTING
        VALUE(iv_role_name)       TYPE agr_name
        VALUE(iv_old_owner_group) TYPE zz_owner_group
        VALUE(iv_new_owner_group) TYPE zz_owner_group
        VALUE(iv_requested_by)    TYPE syuname.

    CLASS-METHODS approve_request
      IMPORTING
        VALUE(iv_req_id) TYPE zcomp_owngrp_req-req_id
        VALUE(iv_user)   TYPE syuname.

    CLASS-METHODS reject_request
      IMPORTING
        VALUE(iv_req_id) TYPE zcomp_owngrp_req-req_id
        VALUE(iv_user)   TYPE syuname
        VALUE(iv_reason) TYPE zz_reject_reason.

    CLASS-METHODS send_reminder_mail
      IMPORTING
        VALUE(is_req)      TYPE zcomp_owngrp_req
        VALUE(iv_send_old) TYPE abap_bool
        VALUE(iv_send_new) TYPE abap_bool.

CLASS-METHODS is_user_in_owner_group
  IMPORTING
    VALUE(iv_user)         TYPE syuname
    VALUE(iv_owner_group)  TYPE zz_owner_group
    VALUE(iv_escalated)    TYPE abap_bool
  RETURNING
    VALUE(rv_authorized)   TYPE abap_bool.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-METHODS send_approval_request_mail
      IMPORTING
        VALUE(is_req)       TYPE zcomp_owngrp_req
        VALUE(iv_old_email) TYPE zrecman_owners-owner_email
        VALUE(iv_new_email) TYPE zrecman_owners-owner_email.

ENDCLASS.



CLASS ZCL_ARC_OWNGRP_SERVICE IMPLEMENTATION.


  METHOD approve_request.

    DATA:
      ls_req       TYPE zcomp_owngrp_req,
      lv_ts        TYPE timestampl,
      lv_d         TYPE d,
      lv_t         TYPE t,
      lv_timestamp TYPE zz_approved_at.

    SELECT SINGLE *
      FROM zcomp_owngrp_req
      INTO @ls_req
      WHERE req_id = @iv_req_id.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA:
  lv_old_auth TYPE abap_bool,
  lv_new_auth TYPE abap_bool.

lv_old_auth =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = iv_user
    iv_owner_group = ls_req-old_owner_group
    iv_escalated   = xsdbool(
                        ls_req-escalation_sent = 'X' ) ).

lv_new_auth =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = iv_user
    iv_owner_group = ls_req-new_owner_group
    iv_escalated   = xsdbool(
                        ls_req-escalation_sent = 'X' ) ).

    IF ls_req-final_status <> 'PENDING'.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD lv_ts.

    CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
      INTO DATE lv_d TIME lv_t.

    lv_timestamp = |{ lv_d }{ lv_t }|.

    "------------------------------------------
    " Old approver approves
    "------------------------------------------
    IF lv_old_auth = abap_true.

      IF ls_req-old_approver_status = 'PENDING'.

        ls_req-old_approver_status = 'APPROVED'.
        ls_req-old_approved_at     = lv_timestamp.

      ENDIF.

    ENDIF.

    "------------------------------------------
    " New approver approves
    "------------------------------------------
    IF lv_new_auth = abap_true.

      IF ls_req-new_approver_status = 'PENDING'.

        ls_req-new_approver_status = 'APPROVED'.
        ls_req-new_approved_at     = lv_timestamp.

      ENDIF.

    ENDIF.

    "------------------------------------------
    " Both approved?
    "------------------------------------------
    IF ls_req-old_approver_status = 'APPROVED'
AND ls_req-new_approver_status = 'APPROVED'.

      DATA:
        ls_og_trail TYPE zcomp_og_trail,
        lv_uuid     TYPE sysuuid_x16.

      ls_req-final_status = 'APPROVED'.

      UPDATE zcomp_role_hdr
         SET owner_group = ls_req-new_owner_group
       WHERE agr_name    = ls_req-agr_name.

      IF sy-subrc = 0.

        CALL FUNCTION 'SYSTEM_UUID_CREATE'
          IMPORTING
            uuid = lv_uuid.

        CLEAR ls_og_trail.

        ls_og_trail-mandt         = sy-mandt.
        ls_og_trail-audit_id      = lv_uuid.
        ls_og_trail-role_name     = ls_req-agr_name.
        ls_og_trail-old_owner_grp = ls_req-old_owner_group.
        ls_og_trail-new_owner_grp = ls_req-new_owner_group.
        ls_og_trail-changed_by    = ls_req-requested_by.
        ls_og_trail-changed_at    = lv_ts.
        ls_og_trail-action_type   = 'CHANGE'.

        INSERT zcomp_og_trail FROM ls_og_trail.

      ENDIF.

    ENDIF.

    MODIFY zcomp_owngrp_req FROM ls_req.


    COMMIT WORK.

  ENDMETHOD.


  METHOD create_or_update_request.

    DATA:
      ls_req          TYPE zcomp_owngrp_req,
      lv_old_owner_id TYPE zrecman_owners-owner_id,
      lv_old_email    TYPE zrecman_owners-owner_email,
      lv_new_owner_id TYPE zrecman_owners-owner_id,
      lv_new_email    TYPE zrecman_owners-owner_email,
      lv_uuid         TYPE sysuuid_x16,
      lv_ts           TYPE timestampl,
      lv_d            TYPE d,
      lv_t            TYPE t,
      lv_timestamp    TYPE zz_requested_at.

    "--------------------------------------------------
    " Resolve Approvers
    "--------------------------------------------------

    zcl_arc_owngrp_service=>get_owner_details(
      EXPORTING
        iv_role_name   = iv_role_name
        iv_owner_group = iv_old_owner_group
      IMPORTING
        ev_owner_id    = lv_old_owner_id
        ev_owner_email = lv_old_email ).

    zcl_arc_owngrp_service=>get_owner_details(
      EXPORTING
        iv_role_name   = iv_role_name
        iv_owner_group = iv_new_owner_group
      IMPORTING
        ev_owner_id    = lv_new_owner_id
        ev_owner_email = lv_new_email ).

    "--------------------------------------------------
    " Current Timestamp
    "--------------------------------------------------

    GET TIME STAMP FIELD lv_ts.

    CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
      INTO DATE lv_d TIME lv_t.

    lv_timestamp = |{ lv_d }{ lv_t }|.

    "--------------------------------------------------
    " Existing Pending Request?
    "--------------------------------------------------

    SELECT SINGLE *
      FROM zcomp_owngrp_req
      INTO @ls_req
      WHERE agr_name     = @iv_role_name
        AND final_status = 'PENDING'.

    IF sy-subrc = 0.

      "=========================================
      " OVERWRITE EXISTING REQUEST
      "=========================================

      ls_req-old_owner_group = iv_old_owner_group.
      ls_req-new_owner_group = iv_new_owner_group.

      ls_req-old_approver = lv_old_owner_id.
      ls_req-new_approver = lv_new_owner_id.
      ls_req-old_approver_email = lv_old_email.
      ls_req-new_approver_email = lv_new_email.

      ls_req-old_approver_status = 'PENDING'.
      ls_req-new_approver_status = 'PENDING'.

      CLEAR:
        ls_req-old_approved_at,
        ls_req-new_approved_at.

      ls_req-final_status = 'PENDING'.

      CLEAR ls_req-reject_reason.

      ls_req-requested_by = iv_requested_by.
      ls_req-requested_at = lv_timestamp.

      zcl_arc_owngrp_service=>send_approval_request_mail(
  is_req       = ls_req
  iv_old_email = lv_old_email
  iv_new_email = lv_new_email ).

      ls_req-initial_email_sent = 'X'.
      ls_req-initial_email_sent_at = lv_timestamp.

      ls_req-reminder_count = 0.
      CLEAR:
  ls_req-last_reminder_at,
  ls_req-escalation_sent,
  ls_req-escalation_sent_at.


      MODIFY zcomp_owngrp_req FROM ls_req.



    ELSE.

      "=========================================
      " CREATE NEW REQUEST
      "=========================================

      CALL FUNCTION 'SYSTEM_UUID_CREATE'
        IMPORTING
          uuid = lv_uuid.

      CLEAR ls_req.

      ls_req-mandt = sy-mandt.
      ls_req-req_id = lv_uuid.

      ls_req-agr_name = iv_role_name.

      ls_req-old_owner_group = iv_old_owner_group.
      ls_req-new_owner_group = iv_new_owner_group.

      ls_req-old_approver = lv_old_owner_id.
      ls_req-new_approver = lv_new_owner_id.

      ls_req-old_approver_email = lv_old_email.
      ls_req-new_approver_email = lv_new_email.

      ls_req-old_approver_status = 'PENDING'.
      ls_req-new_approver_status = 'PENDING'.

      ls_req-final_status = 'PENDING'.

      ls_req-requested_by = iv_requested_by.
      ls_req-requested_at = lv_timestamp.

      zcl_arc_owngrp_service=>send_approval_request_mail(
  is_req       = ls_req
  iv_old_email = lv_old_email
  iv_new_email = lv_new_email ).

      ls_req-initial_email_sent = 'X'.
      ls_req-initial_email_sent_at = lv_timestamp.

      ls_req-reminder_count = 0.
      CLEAR: ls_req-last_reminder_at,
  ls_req-escalation_sent,
  ls_req-escalation_sent_at.

      INSERT zcomp_owngrp_req FROM ls_req.



    ENDIF.

    COMMIT WORK.

  ENDMETHOD.


  METHOD get_owner_details.

    DATA:
      lt_owners      TYPE TABLE OF zrecman_owners,
      ls_owner       TYPE zrecman_owners,
      ls_best_match  TYPE zrecman_owners,
      lv_role        TYPE string,
      lv_ident       TYPE string,
      lv_best_length TYPE i VALUE 0,
      lv_length      TYPE i.

    CLEAR:
      ev_owner_id,
      ev_owner_email.

    lv_role = to_upper( iv_role_name ).

    SELECT *
      FROM zrecman_owners
      INTO TABLE @lt_owners
      WHERE owner_group = @iv_owner_group.

    IF lt_owners IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_owners INTO ls_owner
      WHERE identicator IS NOT INITIAL.

      lv_ident = to_upper( ls_owner-identicator ).

      IF lv_role CS lv_ident.

        lv_length = strlen( lv_ident ).

        IF lv_length > lv_best_length.

          lv_best_length = lv_length.
          ls_best_match  = ls_owner.

        ENDIF.

      ENDIF.

    ENDLOOP.

    IF lv_best_length > 0.

      ev_owner_id    = ls_best_match-owner_id.
      ev_owner_email = ls_best_match-owner_email.

      RETURN.

    ENDIF.

    READ TABLE lt_owners INTO ls_best_match INDEX 1.

    IF sy-subrc = 0.

      ev_owner_id    = ls_best_match-owner_id.
      ev_owner_email = ls_best_match-owner_email.

    ENDIF.

  ENDMETHOD.


  METHOD is_user_in_owner_group.

  rv_authorized = abap_false.

  SELECT *
    FROM zrecman_owners
    INTO TABLE @DATA(lt_owners)
    WHERE owner_group = @iv_owner_group.

  LOOP AT lt_owners INTO DATA(ls_owner).

    " Primary Owner
    IF ls_owner-owner_id = iv_user.
      rv_authorized = abap_true.
      RETURN.
    ENDIF.

    " Backup Owner
    IF ls_owner-backup_owner_id = iv_user.
      rv_authorized = abap_true.
      RETURN.
    ENDIF.

    " Escalation Manager
    IF iv_escalated = abap_true
       AND ls_owner-escalation_manager = iv_user.

      rv_authorized = abap_true.
      RETURN.

    ENDIF.

  ENDLOOP.

ENDMETHOD.


  METHOD reject_request.

    DATA:
      ls_req       TYPE zcomp_owngrp_req,
      lv_ts        TYPE timestampl,
      lv_d         TYPE d,
      lv_t         TYPE t,
      lv_timestamp TYPE zz_approved_at.



    SELECT SINGLE *
      FROM zcomp_owngrp_req
      INTO @ls_req
      WHERE req_id = @iv_req_id.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF ls_req-final_status <> 'PENDING'.
      RETURN.
    ENDIF.

     DATA:
  lv_old_auth TYPE abap_bool,
  lv_new_auth TYPE abap_bool.

lv_old_auth =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = iv_user
    iv_owner_group = ls_req-old_owner_group
    iv_escalated   = xsdbool(
                       ls_req-escalation_sent = 'X' ) ).

lv_new_auth =
  zcl_arc_owngrp_service=>is_user_in_owner_group(
    iv_user        = iv_user
    iv_owner_group = ls_req-new_owner_group
    iv_escalated   = xsdbool(
                       ls_req-escalation_sent = 'X' ) ).

    "------------------------------------------
    " Security check
    "------------------------------------------
 IF lv_old_auth = abap_false
AND lv_new_auth = abap_false.
  RETURN.
ENDIF.

    GET TIME STAMP FIELD lv_ts.

    CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
      INTO DATE lv_d TIME lv_t.

    lv_timestamp = |{ lv_d }{ lv_t }|.

    "------------------------------------------
    " Old approver rejected
    "------------------------------------------
    IF lv_old_auth = abap_true.

  IF ls_req-old_approver_status = 'PENDING'.

    ls_req-old_approver_status = 'REJECTED'.

    IF ls_req-old_approved_at IS INITIAL.
      ls_req-old_approved_at = lv_timestamp.
    ENDIF.

  ENDIF.

ENDIF.

    "------------------------------------------
    " New approver rejected
    "------------------------------------------
    IF lv_new_auth = abap_true.

  IF ls_req-new_approver_status = 'PENDING'.

    ls_req-new_approver_status = 'REJECTED'.

    IF ls_req-new_approved_at IS INITIAL.
      ls_req-new_approved_at = lv_timestamp.
    ENDIF.

  ENDIF.

ENDIF.

    "------------------------------------------
    " Final rejection
    "------------------------------------------
    ls_req-final_status = 'REJECTED'.

    ls_req-reject_reason = iv_reason.

    MODIFY zcomp_owngrp_req FROM ls_req.


    COMMIT WORK.

  ENDMETHOD.


  METHOD send_approval_request_mail.

    DATA:
      lt_to           TYPE zcl_arc_mailer=>tty_addr,
      lv_subject      TYPE string,
      lv_success      TYPE abap_bool,
      lt_ret          TYPE zcl_arc_mailer=>tty_ret,
      lt_html_content TYPE bcsy_text.

    DATA:
  lt_old_owners TYPE TABLE OF zrecman_owners,
  lt_new_owners TYPE TABLE OF zrecman_owners.

    lv_subject =
      '[ArcRecMan] Owner Group Change Approval Required'.

    SELECT *
  FROM zrecman_owners
  INTO TABLE lt_old_owners
  WHERE owner_group = is_req-old_owner_group.

SELECT *
  FROM zrecman_owners
  INTO TABLE lt_new_owners
  WHERE owner_group = is_req-new_owner_group.

  LOOP AT lt_old_owners INTO DATA(ls_old).

  IF ls_old-owner_email IS NOT INITIAL.
    APPEND ls_old-owner_email TO lt_to.
  ENDIF.

  IF ls_old-backup_owner_email IS NOT INITIAL.
    APPEND ls_old-backup_owner_email TO lt_to.
  ENDIF.

ENDLOOP.

LOOP AT lt_new_owners INTO DATA(ls_new).

  IF ls_new-owner_email IS NOT INITIAL.
    APPEND ls_new-owner_email TO lt_to.
  ENDIF.

  IF ls_new-backup_owner_email IS NOT INITIAL.
    APPEND ls_new-backup_owner_email TO lt_to.
  ENDIF.

ENDLOOP.

SORT lt_to BY table_line.

DELETE ADJACENT DUPLICATES
  FROM lt_to
  COMPARING table_line.

IF lt_to IS INITIAL.
  RETURN.
ENDIF.


APPEND '<html><body>' TO lt_html_content.

APPEND '<p>An owner group change requires your approval.</p>' TO lt_html_content.

APPEND |<p><b>Composite Role:</b> { is_req-agr_name }</p>| TO lt_html_content.

APPEND |<p><b>Requested By:</b> { is_req-requested_by }</p>| TO lt_html_content.
APPEND |<p><b>Requested At:</b> { is_req-requested_at }</p>| TO lt_html_content.

APPEND '<p>Please review the request in ArcRecMan.</p>' TO lt_html_content.

APPEND '<a href="https://s4h2023.remoteides.com:44323/sap/bc/gui/sap/its/webgui?~transaction=Z_ARC_RECMAN_APPROVE">' TO lt_html_content.
APPEND '👉 Open Z_ARC_RECMAN_APPROVE in Browser</a>' TO lt_html_content.

APPEND '<p>Best regards,<br/>SAP Security Admin</p>' TO lt_html_content.

APPEND '</body></html>' TO lt_html_content.

zcl_arc_mailer=>send(
  EXPORTING
    it_to        = lt_to
    iv_subject   = lv_subject
    iv_body_html = lt_html_content
  IMPORTING
    ev_success   = lv_success
    et_return    = lt_ret ).


  ENDMETHOD.


  METHOD send_reminder_mail.

    DATA:
      lt_to           TYPE zcl_arc_mailer=>tty_addr,
      lv_subject      TYPE string,
      lv_success      TYPE abap_bool,
      lt_ret          TYPE zcl_arc_mailer=>tty_ret,
      lt_html_content TYPE bcsy_text.

DATA:
  lt_old_owners TYPE TABLE OF zrecman_owners,
  lt_new_owners TYPE TABLE OF zrecman_owners.

SELECT *
  FROM zrecman_owners
  INTO TABLE lt_old_owners
  WHERE owner_group = is_req-old_owner_group.

SELECT *
  FROM zrecman_owners
  INTO TABLE lt_new_owners
  WHERE owner_group = is_req-new_owner_group.

  IF iv_send_old = abap_true.

  LOOP AT lt_old_owners INTO DATA(ls_old).

    IF ls_old-owner_email IS NOT INITIAL.
      APPEND ls_old-owner_email TO lt_to.
    ENDIF.

    IF ls_old-backup_owner_email IS NOT INITIAL.
      APPEND ls_old-backup_owner_email TO lt_to.
    ENDIF.

  ENDLOOP.

ENDIF.

IF iv_send_new = abap_true.

  LOOP AT lt_new_owners INTO DATA(ls_new).

    IF ls_new-owner_email IS NOT INITIAL.
      APPEND ls_new-owner_email TO lt_to.
    ENDIF.

    IF ls_new-backup_owner_email IS NOT INITIAL.
      APPEND ls_new-backup_owner_email TO lt_to.
    ENDIF.

  ENDLOOP.

ENDIF.

SORT lt_to BY table_line.

DELETE ADJACENT DUPLICATES
  FROM lt_to
  COMPARING table_line.

    IF lt_to IS INITIAL.
      RETURN.
    ENDIF.

    lv_subject =
      '[ArcRecMan Reminder] Owner Group Change Approval Pending'.

    APPEND '<html><body>' TO lt_html_content.

    APPEND '<p>An owner group change approval is still pending.</p>' TO lt_html_content.

    APPEND |<p><b>Composite Role:</b> { is_req-agr_name }</p>| TO lt_html_content.

    APPEND |<p><b>Old Owner Group:</b> { is_req-old_owner_group }</p>| TO lt_html_content.

    APPEND |<p><b>New Owner Group:</b> { is_req-new_owner_group }</p>| TO lt_html_content.

    APPEND |<p><b>Requested By:</b> { is_req-requested_by }</p>| TO lt_html_content.

    APPEND '<p>Please review the request in ArcRecMan.</p>' TO lt_html_content.

    APPEND '<a href="https://s4h2023.remoteides.com:44323/sap/bc/gui/sap/its/webgui?~transaction=Z_ARC_RECMAN_APPROVE">' TO lt_html_content.
    APPEND '👉 Open Z_ARC_RECMAN_APPROVE in Browser</a>' TO lt_html_content.

    APPEND '<p>Best regards,<br/>SAP Security Admin</p>' TO lt_html_content.

    APPEND '</body></html>' TO lt_html_content.

    zcl_arc_mailer=>send(
      EXPORTING
        it_to        = lt_to
        iv_subject   = lv_subject
        iv_body_text = 'Owner Group Approval Reminder'
        iv_body_html = lt_html_content
      IMPORTING
        ev_success   = lv_success
        et_return    = lt_ret ).


  ENDMETHOD.
ENDCLASS.
