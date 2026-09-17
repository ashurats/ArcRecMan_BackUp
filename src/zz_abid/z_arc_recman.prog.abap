*-------------------------------------------------------------------------------------------*
* Titel   : Z_ARC_RECMAN                                                                    *
*-------------------------------------------------------------------------------------------*
* Copyright  (c) 2025 Archon Meridian GbR, Deutschland All rights reserved                  *
*                                                                                           *
* Projekt : SAP Role Recertification Manager (“ArcRecMan”)                                  *
*                                                                                           *
* Autor  : Uwe Schlegel                                                                     *
*                                                                                           *
* Beschreibung: Diese Anwendung wird vom Autorisierungsadministrator verwendet.             *
*              Wenn der Autorisierungsadministrator mit dieser Anwendung eine neue          *
*              Sammelrolle erstellt, wird ein automatischer Genehmigungsworkflow ausgelöst. *
*              Alle Benutzer, die derzeit eine der in der neuen Sammelrolle enthaltenen     *
*              Einzelrollen innehaben, erhalten eine E-Mail-Benachrichtigung.               *
*              In dieser E-Mail werden sie um ihre Zustimmung oder Ablehnung gebeten und    *
*              erhalten eine Begründung des Administrators für die Kombination der Rollen.  *
*                                                                                           *
*-------------------------------------------------------------------------------------------*
*    Dev.          DATE            Description                                              *
*-------------------------------------------------------------------------------------------*
*   <ALIABID>   20250630  Zusammengesetzte Rollenerstellung mit Workflow E-Mail Genehmigung *
*                         durch die Rolleninhaber und Rollentransport                       *
*-------------------------------------------------------------------------------------------*
* HISTORIE ÄNDERN                                                                           *
*-------------------------------------------------------------------------------------------*
* Dev.          DARUM          Beschreibung                                                 *
*-------------------------------------------------------------------------------------------*
REPORT z_arc_recman.
TYPE-POOLS: vrm.
TABLES: agr_agrs, zagr_agrs, agr_texts, zcomp_role_hdr.

DATA: gv_agr_desc TYPE zagr_agrs-agr_name_descr.
DATA: gv_agr_desc_old TYPE zagr_agrs-agr_name_descr.

DATA: gv_owner_group TYPE zcomp_role_hdr-owner_group.

DATA: gt_owner_group TYPE vrm_values,
      gs_owner_group TYPE vrm_value.

********* Start of Code by Kanishk Arora **************

DATA : gv_action_mode     TYPE char10,
       gv_old_owner_group TYPE zz_owner_group.

DATA gv_ownergrp_edit TYPE abap_bool.

********* End of Code by Kanishk Arora **************

DATA: gt_domvalues TYPE TABLE OF dd07v,
      gs_domvalue  TYPE dd07v.


CONTROLS recman TYPE TABLEVIEW USING SCREEN 100.
DATA: lv_cols  LIKE LINE OF recman-cols,
      lv_lines TYPE i.

DATA: ok_code     TYPE sy-ucomm,
      save_ok     TYPE sy-ucomm,
      gv_modified TYPE c.

DATA: it_actgrp        TYPE TABLE OF agr_txt WITH HEADER LINE,
      it_actgrp1       TYPE TABLE OF agr_txt WITH HEADER LINE,
      it_actgrp_new    TYPE TABLE OF agr_txt,
      it_actgrp_delete TYPE TABLE OF agr_txt,
      it_bapiret       TYPE TABLE OF bapiret2,
      it_bapiret2      TYPE TABLE OF bapiret2,
      it_bapiret3      TYPE TABLE OF bapiret2.

DATA: lt_bal_t_msg TYPE STANDARD TABLE OF bal_s_msg.

DATA: itab_1      TYPE TABLE OF zagr_agrs,
      it_snapshot TYPE STANDARD TABLE OF zagr_agrs.
DATA: itab_2 TYPE TABLE OF zagr_agrs.

LOOP AT recman-cols INTO lv_cols. "WHERE index GT 2.
  lv_cols-screen-input = '0'.
  MODIFY recman-cols FROM lv_cols INDEX sy-tabix.
ENDLOOP.

*---------------------------------------------------------------------------------*
"<-- Kontrolle auf autorisierten Benutzer, der das Programm ausführen darf
*---------------------------------------------------------------------------------*

SELECT * FROM zrecman_admin INTO TABLE @DATA(lt_recman_admin). "#CI_NOWHERE

READ TABLE lt_recman_admin ASSIGNING FIELD-SYMBOL(<fs_recman_admin>) WITH KEY admin = sy-uname.
IF sy-subrc IS NOT INITIAL.
  MESSAGE e005(zz_arc_recman).
  EXIT.
ENDIF.

CALL SCREEN 001.

MODULE cancel INPUT.
  DATA: lv_answer TYPE c.
  IF gv_modified = 'X'.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = TEXT-000
        text_question         = TEXT-001
        text_button_1         = TEXT-002
        text_button_2         = TEXT-003
        default_button        = '2'
        display_cancel_button = 'X'
      IMPORTING
        answer                = lv_answer.

    CASE lv_answer.
      WHEN '1'. " Yes
        LEAVE PROGRAM.
      WHEN '2' OR 'A'. " No or Cancel
        RETURN. " Do nothing, stay on the screen
    ENDCASE.
  ELSE.
    LEAVE PROGRAM.
  ENDIF.
ENDMODULE.

MODULE read_table_control INPUT.
  MODIFY itab_1 FROM zagr_agrs INDEX recman-current_line.
ENDMODULE.
MODULE status_0100 OUTPUT.
*  DATA: lv_agr_descr TYPE agr_title.
  DATA: ls_agr_texts TYPE agr_texts.
  SET TITLEBAR 'TITLE'.
  SET PF-STATUS 'SCREEN_100'.
*  DESCRIBE TABLE itab_1 lv_lines lv_lines.
  lv_lines = lines( itab_1 ).
  recman-lines = lv_lines.

  zagr_agrs-agr_name = agr_agrs-agr_name.

  LOOP AT recman-cols INTO lv_cols.
    IF  lv_cols-screen-name = 'ZAGR_AGRS-CHILD_AGR_DESCR' AND lv_cols-screen-input = '1'.
      lv_cols-screen-input = '0'.
    ENDIF.
    MODIFY recman-cols FROM lv_cols INDEX sy-tabix.
  ENDLOOP.

  LOOP AT itab_1 ASSIGNING FIELD-SYMBOL(<ls_itab_1>).
    IF gv_agr_desc IS INITIAL.
      gv_agr_desc = <ls_itab_1>-agr_name_descr.
    ENDIF.
    IF <ls_itab_1>-reason_child_agr IS INITIAL.
      SELECT SINGLE * FROM zcomp_role_hdr INTO @zcomp_role_hdr ##WARN_OK
        WHERE agr_name = @<ls_itab_1>-agr_name
          AND child_agr = @<ls_itab_1>-child_agr.
      IF sy-subrc IS INITIAL.
        <ls_itab_1>-reason_child_agr  = zcomp_role_hdr-reason_child_agr.
      ENDIF.
    ENDIF.
*    IF <ls_itab_1>-agr_name_descr IS INITIAL. "- Composite Role description
*      SELECT SINGLE * FROM agr_texts INTO @ls_agr_texts ##WARN_OK
*        WHERE agr_name = @<ls_itab_1>-agr_name
*          AND spras EQ 'EN'.
*      IF sy-subrc IS INITIAL.
*        <ls_itab_1>-agr_name       = ls_agr_texts-agr_name.
*        <ls_itab_1>-agr_name_descr = ls_agr_texts-text.
*        zagr_agrs-agr_name_descr   = ls_agr_texts-text.
*        gv_agr_desc   = ls_agr_texts-text.
*      ENDIF.
*    ENDIF.
    IF <ls_itab_1>-child_agr_descr IS INITIAL. "- Single child Role description
      SELECT SINGLE * FROM agr_texts INTO @ls_agr_texts ##WARN_OK
        WHERE agr_name = @<ls_itab_1>-child_agr
          AND spras EQ 'EN'.
      IF sy-subrc IS INITIAL.
        <ls_itab_1>-child_agr       = ls_agr_texts-agr_name.
        <ls_itab_1>-child_agr_descr = ls_agr_texts-text.
        zagr_agrs-child_agr_descr   = ls_agr_texts-text.
      ENDIF.
    ENDIF.
  ENDLOOP.

*********Start of Code by Kanishk Arora ***********

  LOOP AT SCREEN.

    IF screen-name = 'GV_OWNER_GROUP'.

      IF gv_ownergrp_edit = abap_true.
        screen-input = '1'.
      ELSE.
        screen-input = '0'.
      ENDIF.

      MODIFY SCREEN.

    ENDIF.

  ENDLOOP.

*********End of Code by Kanishk Arora***************
  IF it_snapshot IS INITIAL.
    " Fetch data into it_display
    it_snapshot[] = itab_1[]. " Take the snapshot
    gv_agr_desc_old = gv_agr_desc. " Take the snapshot
  ENDIF.

ENDMODULE.

MODULE user_command_0100 INPUT.
  TYPES: tt_role_log TYPE STANDARD TABLE OF zcomp_role_log.

  save_ok = ok_code.
  CLEAR ok_code.
  CASE save_ok.
    WHEN 'BACK'.
      CLEAR: itab_1, zagr_agrs, gv_agr_desc.
      LEAVE TO SCREEN 0.
*      SET SCREEN 100.
*      LEAVE SCREEN.
    WHEN 'EXIT'.
      CLEAR: itab_1, zagr_agrs, gv_agr_desc.
      LEAVE TO SCREEN 0. " Navigates back one step in the call stack

    WHEN 'CANCEL'.
      CLEAR: itab_1, zagr_agrs, gv_agr_desc.
      LEAVE PROGRAM.

    WHEN 'DELETE'.
*--------------------------------------------------------------------*
      "<-- Zeile entfernen
*--------------------------------------------------------------------*
      DELETE ADJACENT DUPLICATES FROM itab_1 COMPARING child_agr.

      LOOP AT recman-cols INTO lv_cols. "WHERE index GT 2.
        IF  lv_cols-screen-input = '0'.
          lv_cols-screen-input = '1'.
        ENDIF.
        MODIFY recman-cols FROM lv_cols INDEX sy-tabix.
      ENDLOOP.

      CLEAR itab_2.
      READ TABLE recman-cols INTO lv_cols WITH KEY screen-input = '1'.
      IF sy-subrc = 0.
        LOOP AT itab_1 INTO zagr_agrs WHERE mark = 'X'.
          APPEND zagr_agrs TO itab_2.
          DELETE itab_1.
        ENDLOOP.
      ENDIF.
      gv_modified = 'X'.
      DATA(gv_delete_flag) = 'X'.

    WHEN 'INSERT'.
*--------------------------------------------------------------------*
      " <-- Neue Zeile hinzufügen
*--------------------------------------------------------------------*
      LOOP AT recman-cols INTO lv_cols.
        IF  lv_cols-screen-name = 'ZAGR_AGRS-CHILD_AGR' AND lv_cols-screen-input = '0'.
          lv_cols-screen-input = '1'.
        ENDIF.
        IF  lv_cols-screen-name = 'ZAGR_AGRS-AGR_NAME_DESCR' AND lv_cols-screen-input = '0'.
          lv_cols-screen-input = '1'.
        ENDIF.
        IF  lv_cols-screen-name = 'ZAGR_AGRS-REASON_CHILD_AGR' AND lv_cols-screen-input = '0'.
          lv_cols-screen-input = '1'.
        ENDIF.
        MODIFY recman-cols FROM lv_cols INDEX sy-tabix.
      ENDLOOP.
      CLEAR: zagr_agrs-child_agr, zagr_agrs-child_agr_descr, zagr_agrs-reason_child_agr.

*- Single Role description
      zagr_agrs-agr_name = agr_agrs-agr_name.
      zagr_agrs-child_agr = agr_agrs-child_agr.

      zagr_agrs-agr_name_descr = gv_agr_desc.
*        zagr_agrs-child_agr_descr = <ls_itab_1>-child_agr_descr.

      APPEND zagr_agrs TO itab_1.
      lv_lines = lines( itab_1 ).
      recman-lines = lv_lines.
      gv_modified = 'X'.
      DATA(gv_save_flag) = 'X'.


    WHEN 'SAVE'.

********* Start of Code by Kanishk Arora **************

*      SELECT SINGLE agr_name
*  FROM zcomp_role_hdr
*  INTO @DATA(lv_existing_role)
*  WHERE agr_name = @agr_agrs-agr_name.
*
*IF sy-subrc = 0.
*  lv_is_create = abap_false.
*ELSE.
*  lv_is_create = abap_true.
*ENDIF.

      IF zagr_agrs-agr_name_descr IS INITIAL OR gv_agr_desc IS INITIAL.
        MESSAGE 'Composite role description is mandatory' TYPE 'E'.
      ENDIF.

      IF itab_1[] = it_snapshot[] AND gv_agr_desc = gv_agr_desc_old AND gv_owner_group = gv_old_owner_group.
        MESSAGE 'No changes were made to the data.' TYPE 'S'.
      ELSE.

        IF itab_1[] IS INITIAL.
          MESSAGE 'Add single role before saving' TYPE 'E'.
        ENDIF.

        PERFORM check_owner_group.


********* End of Code by Kanishk Arora **************

        DATA: lt_agr_agrs     TYPE TABLE OF agr_agrs,
              lt_agr_agrs_del TYPE TABLE OF agr_agrs.

        DATA: lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line,
              lv_key  TYPE string.

        zagr_agrs-owner_group    = gv_owner_group.
        zagr_agrs-agr_name_descr = gv_agr_desc.

        CALL FUNCTION 'PRGN_RFC_CREATE_AGR_MULTIPLE'
          EXPORTING
            activity_group                = agr_agrs-agr_name
            activity_group_text           = zagr_agrs-agr_name_descr
            collective_agr                = abap_true
          TABLES
            return                        = it_bapiret
          EXCEPTIONS
            activity_group_already_exists = 1
            invalid_inheriting_role       = 2
            activity_group_enqueued       = 3
            namespace_problem             = 4
            illegal_characters            = 5
            error_when_creating_actgroup  = 6
            not_authorized                = 7
            OTHERS                        = 8.

        CLEAR lt_seen.
        LOOP AT itab_1 ASSIGNING FIELD-SYMBOL(<fs_new>).

          " Build key = parent||child
          lv_key = |{ agr_agrs-agr_name }-{ <fs_new>-child_agr }|.

          " 1. Check duplicate inside current ALV
          READ TABLE lt_seen WITH KEY table_line = lv_key TRANSPORTING NO FIELDS.
          IF sy-subrc = 0.
            MESSAGE |Duplicate entry: Child role { <fs_new>-child_agr } is entered more than once|
              TYPE 'E'.  " Error → stop processing
            EXIT.
          ENDIF.
          INSERT lv_key INTO TABLE lt_seen.
        ENDLOOP.

        DELETE ADJACENT DUPLICATES FROM itab_1 COMPARING child_agr.
        DELETE ADJACENT DUPLICATES FROM itab_2 COMPARING child_agr.

*******Create New Role***************
        IF itab_1 IS NOT INITIAL.
          CLEAR: it_actgrp, it_bapiret2.

          LOOP AT itab_1 ASSIGNING FIELD-SYMBOL(<fs_itab>).
            <fs_itab>-agr_name_descr = gv_agr_desc.
            it_actgrp-agr_name       = <fs_itab>-child_agr.
            it_actgrp-text           = <fs_itab>-child_agr_descr.
            <fs_itab>-owner_group    = zagr_agrs-owner_group.
            APPEND it_actgrp.
          ENDLOOP.

          CALL FUNCTION 'PRGN_RFC_ADD_AGRS_TO_COLL_AGR'
            EXPORTING
              activity_group                = agr_agrs-agr_name
            TABLES
              activity_groups               = it_actgrp
              return                        = it_bapiret2
            EXCEPTIONS
              activity_group_does_not_exist = 1
              no_collective_activity_group  = 2
              activity_group_enqueued       = 3
              namespace_problem             = 4
              not_authorized                = 5
              authority_incomplete          = 6
              OTHERS                        = 7.

          IF it_bapiret2 IS NOT INITIAL.
            lt_bal_t_msg = CORRESPONDING #( it_bapiret2 MAPPING msgty = type
                                                                msgid = id
                                                                msgno = number
                                                                msgv1 = message_v1
                                                                 ).
            zz_cl_arc_bal_log_details=>log_display( it_bal_t_msg = lt_bal_t_msg ).
          ELSE.
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
          ENDIF.
          DATA: lv_ts  TYPE timestamp, lv_d TYPE d, lv_t TYPE t,lv_now TYPE char14.
          DATA: lt_comp_role_hdr TYPE TABLE OF zcomp_role_hdr.
          GET TIME STAMP FIELD lv_ts.
          CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
          lv_now = |{ lv_d }{ lv_t }|.          " -> 'YYYYMMDDHHMMSS'


          zcomp_role_hdr-agr_name         = zagr_agrs-agr_name.
          zcomp_role_hdr-child_agr        = zagr_agrs-child_agr.
          zcomp_role_hdr-owner_group      = zagr_agrs-owner_group.
          zcomp_role_hdr-agr_name_descr   = zagr_agrs-agr_name_descr.
          zcomp_role_hdr-child_agr_descr  = zagr_agrs-child_agr_descr.
          zcomp_role_hdr-reason_child_agr = zagr_agrs-reason_child_agr.
          zcomp_role_hdr-req_user         = sy-uname.

          lt_comp_role_hdr = CORRESPONDING #( itab_1 MAPPING agr_name = agr_name
                                                             child_agr =  child_agr
                                                             owner_group = owner_group
                                                             agr_name_descr = agr_name_descr
                                                             child_agr_descr = child_agr_descr
                                                             reason_child_agr = reason_child_agr
                                             ).

********Start of Code By Kanishk Arora******************
          IF gv_action_mode = 'CHANGE' AND gv_old_owner_group <> gv_owner_group.

            zcl_arc_owngrp_service=>create_or_update_request(
              EXPORTING
                iv_role_name       = zagr_agrs-agr_name
                iv_old_owner_group = gv_old_owner_group
                iv_new_owner_group = gv_owner_group
                iv_requested_by    = sy-uname ).

          ENDIF.

********End of Code By Kanishk Arora******************

          LOOP AT lt_comp_role_hdr ASSIGNING FIELD-SYMBOL(<ls_comp_role_hdr>).
            IF <ls_comp_role_hdr>-created_at IS INITIAL.
              <ls_comp_role_hdr>-created_at = lv_now.
            ENDIF.
            IF <ls_comp_role_hdr>-changed_at IS INITIAL.
              <ls_comp_role_hdr>-changed_at = lv_now.
            ENDIF.
            <ls_comp_role_hdr>-req_user = sy-uname.
            <ls_comp_role_hdr>-wf_approval_status = 'PENDING'.
          ENDLOOP.

********Start of Code By Kanishk Arora******************
          IF gv_action_mode = 'CHANGE' AND gv_old_owner_group <> gv_owner_group.

            LOOP AT lt_comp_role_hdr ASSIGNING <ls_comp_role_hdr>.
              <ls_comp_role_hdr>-owner_group = gv_old_owner_group.
            ENDLOOP.

          ENDIF.
********End of Code By Kanishk Arora******************
          MODIFY zcomp_role_hdr FROM TABLE lt_comp_role_hdr.
*          PERFORM write_change_log.
***          COMMIT WORK.

*-> Change documents for Logging details
***        IF gv_action_mode = 'CREATE'.
***          DATA: lt_cdtxt TYPE STANDARD TABLE OF cdtxt,
***                lt_xstu  TYPE STANDARD TABLE OF yzcomp_role_hdr,
***                ls_xstu  TYPE yzcomp_role_hdr.
***
***          MOVE-CORRESPONDING <ls_comp_role_hdr> TO ls_xstu.
***          ls_xstu-kz = 'I'.
***          APPEND ls_xstu TO lt_xstu.
***
***          CALL FUNCTION 'ZZ_ARC_ROLE_HDR_WRITE_DOCUMENT'
***            EXPORTING
***              objectid                   = CONV cdobjectv( zagr_agrs-agr_name )
***              tcode                      = 'Z_ARC_RECMAN'
***              utime                      = sy-uzeit
***              udate                      = sy-datum
***              username                   = sy-uname
****             PLANNED_CHANGE_NUMBER      = ' '
***              object_change_indicator    = 'I'
****             PLANNED_OR_REAL_CHANGES    = ' '
****             NO_CHANGE_POINTERS         = ' '
***              upd_icdtxt_zz_arc_role_hdr = 'I'
***              upd_zcomp_role_hdr         = 'I'
***            TABLES
***              icdtxt_zz_arc_role_hdr     = lt_cdtxt
***              xzcomp_role_hdr            = lt_xstu.
****              yzcomp_role_hdr            =.
***
***        ELSEIF gv_action_mode = 'CHANGE'.
***          DATA: "lt_cdtxt TYPE STANDARD TABLE OF cdtxt,
***            lw_cdtxt TYPE cdtxt,
***            "lt_xstu  TYPE STANDARD TABLE OF yzcomp_role_hdr,
***            "ls_xstu  TYPE yzcomp_role_hdr,
***            lt_ystu  TYPE STANDARD TABLE OF yzcomp_role_hdr.
***
***          MOVE-CORRESPONDING lt_comp_role_hdr TO lt_xstu.
***          READ TABLE lt_xstu INTO ls_xstu INDEX 1.
***          REFRESH lt_xstu.
***          ls_xstu-agr_name = zagr_agrs-agr_name.
***          ls_xstu-mandt = sy-mandt.
***          ls_xstu-kz = 'U'.
***          APPEND ls_xstu TO lt_xstu.
***
***          CLEAR ls_xstu.
***          MOVE-CORRESPONDING <ls_comp_role_hdr> TO ls_xstu.
***          ls_xstu-kz = 'U'.
***          APPEND ls_xstu TO lt_ystu.
***
***          CALL FUNCTION 'ZZ_ARC_ROLE_HDR_WRITE_DOCUMENT'
***            EXPORTING
***              objectid                = CONV cdobjectv( zagr_agrs-agr_name )
***              tcode                   = 'Z_ARC_RECMAN'
***              utime                   = sy-uzeit
***              udate                   = sy-datum
***              username                = sy-uname
***              object_change_indicator = 'U'   " For Updating
***              upd_zcomp_role_hdr      = 'U'
***            TABLES
***              icdtxt_zz_arc_role_hdr  = lt_cdtxt
***              xzcomp_role_hdr         = lt_xstu  " Updated Data
***              yzcomp_role_hdr         = lt_ystu. " Old Data ​
***
***        ENDIF.
*
*          DATA: lt_x   TYPE STANDARD TABLE OF yzcomp_role_hdr,   " new image + change indicator
*                lt_y   TYPE STANDARD TABLE OF yzcomp_role_hdr,   " old image + change indicator
*                ls_x   TYPE yzcomp_role_hdr,
*                ls_y   TYPE yzcomp_role_hdr,
*                ls_old TYPE zcomp_role_hdr.

          TYPES: BEGIN OF ty_cd,
                   upd TYPE cdchngind,        " 'I' / 'U' / 'D'  (per-row operation)
                   n   TYPE zcomp_role_hdr,   " new image
                   o   TYPE zcomp_role_hdr,   " old image
                 END OF ty_cd.

          DATA: lt_cd      TYPE STANDARD TABLE OF ty_cd,
                ls_cd      TYPE ty_cd,
                ls_old     TYPE zcomp_role_hdr,
                lv_obj_ind TYPE cdhdr-change_ind.

          lv_obj_ind = COND #( WHEN gv_action_mode = 'CREATE' THEN 'I' ELSE 'U' ).

          IF gv_action_mode = 'CREATE'.
            LOOP AT itab_1 INTO DATA(ls_new_c).
              CLEAR ls_cd.
              MOVE-CORRESPONDING ls_new_c TO ls_cd-n.
              ls_cd-n-agr_name = zagr_agrs-agr_name.   " ensure key is set
              ls_cd-upd        = 'I'.
              APPEND ls_cd TO lt_cd.
            ENDLOOP.

          ELSE.                                        " CHANGE
*             inserts + updates
            LOOP AT itab_1 INTO DATA(ls_new).
              READ TABLE it_snapshot INTO ls_old
                   WITH KEY child_agr = ls_new-child_agr.
              IF sy-subrc <> 0.
                CLEAR ls_cd.
                MOVE-CORRESPONDING ls_new TO ls_cd-n.
                ls_cd-n-agr_name = zagr_agrs-agr_name.
                ls_cd-upd = 'I'.
                APPEND ls_cd TO lt_cd.
              ELSEIF ls_new <> ls_old.
                CLEAR ls_cd.
                MOVE-CORRESPONDING ls_new TO ls_cd-n.
                MOVE-CORRESPONDING ls_old TO ls_cd-o.
                ls_cd-n-agr_name = zagr_agrs-agr_name.
                ls_cd-o-agr_name = zagr_agrs-agr_name.
                ls_cd-upd = 'U'.
                APPEND ls_cd TO lt_cd.
              ENDIF.
            ENDLOOP.

*             deletes
            LOOP AT it_snapshot INTO ls_old.
              READ TABLE itab_1 TRANSPORTING NO FIELDS
                   WITH KEY child_agr = ls_old-child_agr.
              IF sy-subrc <> 0.
                CLEAR ls_cd.
                MOVE-CORRESPONDING ls_old TO ls_cd-o.
                ls_cd-o-agr_name = zagr_agrs-agr_name.
                ls_cd-upd = 'D'.
                APPEND ls_cd TO lt_cd.
              ENDIF.
            ENDLOOP.
          ENDIF.

          LOOP AT lt_cd INTO ls_cd.
            CALL FUNCTION 'ZCOMP_ROLE_WRITE_DOCUMENT'
              EXPORTING
                objectid                = CONV cdhdr-objectid( zagr_agrs-agr_name )
                tcode                   = 'Z_ARC_RECMAN'
                utime                   = sy-uzeit
                udate                   = sy-datum
                username                = sy-uname
                object_change_indicator = lv_obj_ind
                n_zcomp_role_hdr        = ls_cd-n
                o_zcomp_role_hdr        = ls_cd-o
                upd_zcomp_role_hdr      = ls_cd-upd.
          ENDLOOP.



******* Start of code by KANISHK ARORA *********************

          DATA: ls_og_trail     TYPE zcomp_og_trail,
                lv_uuid         TYPE sysuuid_x16,
                lv_ts_audit     TYPE timestampl,
                lv_old_ownergrp TYPE zz_owner_group.

          GET TIME STAMP FIELD lv_ts_audit.

          " ==========================================
          " CREATE CASE
          " ==========================================
          IF gv_action_mode = 'CREATE'.

            CALL FUNCTION 'SYSTEM_UUID_CREATE'
              IMPORTING
                uuid = lv_uuid.

            CLEAR ls_og_trail.

            ls_og_trail-mandt         = sy-mandt.
            ls_og_trail-audit_id      = lv_uuid.
            ls_og_trail-role_name     = agr_agrs-agr_name.
            ls_og_trail-old_owner_grp = ''.
            ls_og_trail-new_owner_grp = gv_owner_group.
            ls_og_trail-changed_by    = sy-uname.
            ls_og_trail-changed_at    = lv_ts_audit.
            ls_og_trail-action_type   = 'CREATE'.

            INSERT zcomp_og_trail FROM ls_og_trail.

          ENDIF.

          " ==========================================
          " CHANGE CASE
          " ==========================================
*          IF gv_action_mode = 'CHANGE'.
*
*
*            IF gv_old_owner_group <> gv_owner_group.
*
*              CALL FUNCTION 'SYSTEM_UUID_CREATE'
*                IMPORTING
*                  uuid = lv_uuid./
*
*              CLEAR ls_og_trail.
*
*              ls_og_trail-mandt         = sy-mandt.
*              ls_og_trail-audit_id      = lv_uuid.
*              ls_og_trail-role_name     = agr_agrs-agr_name.
*              ls_og_trail-old_owner_grp = gv_old_owner_group.
*              ls_og_trail-new_owner_grp = gv_owner_group.
*              ls_og_trail-changed_by    = sy-uname.
*              ls_og_trail-changed_at    = lv_ts_audit.
*              ls_og_trail-action_type   = 'CHANGE'.
*
*              INSERT zcomp_og_trail FROM ls_og_trail.
*
*            ENDIF.
*
*          ENDIF.


******* End of code by KANISHK ARORA *********************

          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
        ENDIF.
*****************Delete logic******
        IF itab_2 IS NOT INITIAL.
          CLEAR: it_actgrp1, it_bapiret3.
          "gv_delete_flag.
*        it_actgrp1 = CORRESPONDING #( itab_2 MAPPING agr_name = child_agr ).
          LOOP AT itab_2 ASSIGNING FIELD-SYMBOL(<fs_itab2>).
            it_actgrp1-agr_name =  <fs_itab2>-child_agr.
            it_actgrp1-text =  <fs_itab2>-child_agr_descr.
            <fs_itab2>-owner_group = zagr_agrs-owner_group.
            APPEND it_actgrp1.
          ENDLOOP.

          CALL FUNCTION 'PRGN_RFC_DEL_AGRS_IN_COLL_AGR'
            EXPORTING
              activity_group                = zagr_agrs-agr_name
            TABLES
              activity_groups               = it_actgrp1
              return                        = it_bapiret3
            EXCEPTIONS
              activity_group_does_not_exist = 1
              no_collective_activity_group  = 2
              activity_group_enqueued       = 3
              namespace_problem             = 4
              not_authorized                = 5
              authority_incomplete          = 6
              OTHERS                        = 7.
          IF it_bapiret3 IS NOT INITIAL.
            lt_bal_t_msg = CORRESPONDING #( it_bapiret3 MAPPING msgty = type
                                                                msgid = id
                                                                msgno = number
                                                                msgv1 = message_v1
                                                                 ).
            zz_cl_arc_bal_log_details=>log_display( it_bal_t_msg = lt_bal_t_msg ).
          ELSE.
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
          ENDIF.

*            DATA: lv_ts  TYPE timestamp, lv_d TYPE d, lv_t TYPE t,lv_now TYPE char14.

          DATA: lt_comp_role_hdr_delete TYPE TABLE OF zcomp_role_hdr.
          GET TIME STAMP FIELD lv_ts.
          CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
          lv_now = |{ lv_d }{ lv_t }|.          " -> 'YYYYMMDDHHMMSS'

          zcomp_role_hdr-agr_name         = zagr_agrs-agr_name.
          zcomp_role_hdr-child_agr        = zagr_agrs-child_agr.
*        zcomp_role_hdr-created_at      = lv_now.
          zcomp_role_hdr-agr_name_descr   = zagr_agrs-agr_name_descr.
          zcomp_role_hdr-child_agr_descr  = zagr_agrs-child_agr_descr.
          zcomp_role_hdr-reason_child_agr = zagr_agrs-reason_child_agr.
          zcomp_role_hdr-owner_group      = zagr_agrs-owner_group.

          lt_comp_role_hdr_delete = CORRESPONDING #( itab_2 MAPPING agr_name = agr_name
                                                             child_agr =  child_agr
                                                             owner_group = owner_group
                                                             agr_name_descr = agr_name_descr
                                                             child_agr_descr = child_agr_descr
                                                             reason_child_agr = reason_child_agr
                                                    ).

          LOOP AT lt_comp_role_hdr_delete ASSIGNING <ls_comp_role_hdr>.
            IF <ls_comp_role_hdr>-created_at IS INITIAL.
              <ls_comp_role_hdr>-created_at = lv_now.
            ENDIF.
            IF <ls_comp_role_hdr>-changed_at IS INITIAL.
              <ls_comp_role_hdr>-changed_at = lv_now.
            ENDIF.
            <ls_comp_role_hdr>-req_user = sy-uname.
            <ls_comp_role_hdr>-wf_approval_status = 'PENDING'.
          ENDLOOP.

          DELETE zcomp_role_hdr FROM TABLE lt_comp_role_hdr_delete.

***          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
        ENDIF.


        DATA: lv_total TYPE i VALUE 200,
              lv_idx   TYPE i.

        DO lv_total TIMES.
          lv_idx = sy-index.

          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING
              percentage = ( lv_idx * 100 ) / lv_total
              text       = |Processing { lv_idx } / { lv_total }|.

          CALL METHOD cl_gui_cfw=>flush( ).

          " Slow down (seconds can be decimal in newer releases; if not, use integer)
          WAIT UP TO '0.01' SECONDS.  " 50 ms
        ENDDO.


        " Declare the range table
        DATA: s_rng TYPE RANGE OF zz_owner_group.

        s_rng = VALUE #( ( sign = 'I' option = 'EQ' low = gv_owner_group ) ).

*      PERFORM send_email.

        LOOP AT itab_1 ASSIGNING <fs_new>.
          SELECT SINGLE wf_approval_status FROM zcomp_role_hdr
            INTO @DATA(lv_status)
           WHERE agr_name = @<fs_new>-agr_name
             AND child_agr = @<fs_new>-child_agr.

          IF lv_status = 'PENDING'.
            DATA(lv_status_flag) = 'X'.
          ENDIF.
        ENDLOOP.

        IF lv_status_flag EQ 'X'.
          SUBMIT z_arc_recman_reminder WITH s_rng IN s_rng
          AND RETURN.
          MESSAGE i001(zz_arc_recman) WITH zagr_agrs-agr_name.
        ENDIF.

        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.


******* Start of code by KANISHK ARORA *********************

        CLEAR gv_action_mode.
        CLEAR gv_old_owner_group.
        CLEAR gv_owner_group.
        CLEAR itab_1.
        CLEAR itab_2.
        CLEAR zagr_agrs.

        " Update snapshot after a successful save
        it_snapshot[] = itab_1[].

        LEAVE TO SCREEN 0.

******* End of code by KANISHK ARORA *********************


*        ELSE.
*          MESSAGE s007(zz_arc_recman).
*        ENDIF.
      ENDIF.

    WHEN 'TRANSPORT'.
*--------------------------------------------------------------------*
* Transport der Rolle, wenn sie von den Rolleninhabern genehmigt wurde
*--------------------------------------------------------------------*
      TYPES:lr_agr_name_type TYPE RANGE OF agr_name,
            BEGIN OF type_output,
              status    TYPE char80,                       "icon
              role      TYPE agr_name,
              role_type TYPE char80,                       "icon
              text      TYPE agr_title,
              sgl_role  TYPE agr_name,
              inh_role  TYPE par_agr,
              rqst      TYPE trkorr,
              error     TYPE menu_attr,
              err_text  TYPE bapi_msg,
            END OF type_output.
      DATA : lr_agr_name_01 TYPE lr_agr_name_type, "Table 1
             lv_retc        TYPE sysubrc,
             lv_variant     TYPE raldb_vari.
      DATA: ls_comp_role_hdr   TYPE zcomp_role_hdr,
            ls_zrecman_logs_tr TYPE zrecman_logs_tr,
            lt_zrecman_logs_tr TYPE TABLE OF zrecman_logs_tr,
            lv_timestamp       TYPE char14,
            gt_output          TYPE TABLE OF type_output,
            ls_output          TYPE type_output.


      CONSTANTS: lc_var_col TYPE raldb_vari VALUE 'SAP&COMP_AGR'.

      GET TIME STAMP FIELD lv_ts.
      CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
      lv_timestamp = |{ lv_d }{ lv_t }|.          " -> 'YYYYMMDDHHMMSS'

      CHECK agr_agrs-agr_name IS NOT INITIAL.

      SELECT * FROM zcomp_role_hdr INTO TABLE @DATA(lt_zcomp_role_hdr)
      WHERE agr_name EQ @agr_agrs-agr_name.

      READ TABLE lt_zcomp_role_hdr INTO ls_comp_role_hdr
                                      WITH KEY agr_name = agr_agrs-agr_name.

      IF sy-subrc EQ 0 AND ls_comp_role_hdr-wf_approval_status NE 'APPROVED'.  " Rejected Role
        MOVE-CORRESPONDING ls_comp_role_hdr TO ls_zrecman_logs_tr.

        ls_zrecman_logs_tr-system_id         = sy-sysid.
        ls_zrecman_logs_tr-blocked_role      = ls_zrecman_logs_tr-child_agr.
        ls_zrecman_logs_tr-blocked_timestamp = lv_timestamp.
        ls_zrecman_logs_tr-blocked_by        = sy-uname.
        MODIFY zrecman_logs_tr FROM ls_zrecman_logs_tr.
        COMMIT WORK.

        MESSAGE i006(zz_arc_recman) WITH agr_agrs-child_agr.
      ELSEIF sy-subrc EQ 0 AND ls_comp_role_hdr-wf_approval_status EQ 'APPROVED'.  " Approved Role
        lr_agr_name_01 = VALUE lr_agr_name_type(
                                        LET s = 'I'
                                            o = 'EQ'
                                        IN sign   = s
                                           option = o
                                           ( low = agr_agrs-agr_name )
                                          ).
*----------------------------------------------------------------------------------------------------------------*
* PFCG_MASS_TRANSPORT ist ein SAP-Report, der in der Rollenpflege (Transaktion PFCG) verwendet wird,
* um mehrere Rollen in einem Transportauftrag zu bündeln und so den Rollentransport
* von der Entwicklung zu QA- oder Produktionssystemen zu rationalisieren.
*----------------------------------------------------------------------------------------------------------------*
        lv_variant = lc_var_col.
        CALL FUNCTION 'RS_VARIANT_EXISTS'
          EXPORTING
            report              = 'PFCG_MASS_TRANSPORT'
            variant             = lv_variant
          IMPORTING
            r_c                 = lv_retc
          EXCEPTIONS
            not_authorized      = 1
            no_report           = 2
            report_not_existent = 3
            OTHERS              = 4.

***        SUBMIT pfcg_mass_transport WITH agr_name IN lr_agr_name_01
***         VIA SELECTION-SCREEN USING SELECTION-SET lv_variant
***         AND RETURN.

        SUBMIT pfcg_mass_transport WITH agr_name IN lr_agr_name_01
*         VIA SELECTION-SCREEN USING SELECTION-SET lv_variant
         AND RETURN.


        IMPORT gt_output = gt_output FROM MEMORY ID 'TRO'.

        READ TABLE gt_output INTO ls_output WITH KEY role = agr_agrs-agr_name.
        IF sy-subrc EQ 0.
          MOVE-CORRESPONDING ls_comp_role_hdr TO ls_zrecman_logs_tr.
          ls_zrecman_logs_tr-system_id         = sy-sysid.
          ls_zrecman_logs_tr-transport_no = ls_output-rqst.
          MODIFY zrecman_logs_tr FROM ls_zrecman_logs_tr.
          COMMIT WORK.
        ENDIF.
      ENDIF.

****      SELECT * FROM zcomp_role_hdr INTO TABLE @DATA(lt_zcomp_role_hdr)
****        WHERE agr_name EQ @agr_agrs-agr_name
****          AND wf_approval_status NE 'APPROVED'.
****      IF sy-subrc IS INITIAL.
****        LOOP AT lt_zcomp_role_hdr INTO DATA(ls_zcomp_role_hdr).
****          MOVE-CORRESPONDING ls_zcomp_role_hdr TO ls_zrecman_logs_tr.
****          ls_zrecman_logs_tr-blocked_role = ls_zrecman_logs_tr-child_agr.
****          ls_zrecman_logs_tr-blocked_timestamp = lv_timestamp.
****          ls_zrecman_logs_tr-blocked_by = sy-uname.
****          APPEND ls_zrecman_logs_tr TO lt_zrecman_logs_tr.
****          CLEAR: ls_zrecman_logs_tr.
****        ENDLOOP.
****        MODIFY zrecman_logs_tr FROM TABLE lt_zrecman_logs_tr.
****        MESSAGE i006(zz_arc_recman) WITH zagr_agrs-child_agr.
****        EXIT.
****      ELSE.
****        MESSAGE e017(zz_arc_recman) DISPLAY LIKE 'I'.
****        EXIT.
****      ENDIF.




***      SELECT * FROM zcomp_role_hdr INTO TABLE lt_comp_role_hdr
***       WHERE agr_name = agr_agrs-agr_name
***       AND wf_approval_status EQ 'APPROVED'.
***      IF sy-subrc IS INITIAL.
***        READ TABLE lt_comp_role_hdr INTO ls_comp_role_hdr
***                                    WITH KEY agr_name = agr_agrs-agr_name.
***
***        IF ls_comp_role_hdr-wf_approval_status = 'APPROVED'.
***          lr_agr_name_01 = VALUE lr_agr_name_type(
***                                          LET s = 'I'
***                                              o = 'EQ'
***                                          IN sign   = s
***                                             option = o
***                                             ( low = agr_agrs-agr_name )
***                                            ).
****----------------------------------------------------------------------------------------------------------------*
**** PFCG_MASS_TRANSPORT ist ein SAP-Report, der in der Rollenpflege (Transaktion PFCG) verwendet wird,
**** um mehrere Rollen in einem Transportauftrag zu bündeln und so den Rollentransport
**** von der Entwicklung zu QA- oder Produktionssystemen zu rationalisieren.
****----------------------------------------------------------------------------------------------------------------*
***          lv_variant = lc_var_col.
***          CALL FUNCTION 'RS_VARIANT_EXISTS'
***            EXPORTING
***              report              = 'PFCG_MASS_TRANSPORT'
***              variant             = lv_variant
***            IMPORTING
***              r_c                 = lv_retc
***            EXCEPTIONS
***              not_authorized      = 1
***              no_report           = 2
***              report_not_existent = 3
***              OTHERS              = 4.
***
***          SUBMIT pfcg_mass_transport WITH agr_name IN lr_agr_name_01
***                 VIA SELECTION-SCREEN USING SELECTION-SET lv_variant
***                 AND RETURN.
***          READ TABLE gt_output INTO ls_output WITH KEY role = agr_agrs-agr_name.
***          IF sy-subrc EQ 0.
***            ls_zrecman_logs_tr-transport_no = ls_output-rqst.
***            MODIFY zrecman_logs_tr FROM ls_zrecman_logs_tr.
***            COMMIT WORK.
***          ENDIF.
***        ENDIF.
***      ENDIF.

    WHEN 'EMAIL'.
*      PERFORM send_email.

********** Start of Code by Kanishk Arora ***********

    WHEN 'CHGOWNGRP'.

      DATA lv_answer_chgowngrp TYPE c.

      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = 'Warning'
          text_question         = 'Do you really want to change the owner group?'
          text_button_1         = 'Yes'
          text_button_2         = 'No'
          default_button        = '2'
          display_cancel_button = 'X'
        IMPORTING
          answer                = lv_answer_chgowngrp.

      IF lv_answer_chgowngrp = '1'.

        gv_ownergrp_edit = abap_true.

        LEAVE TO SCREEN 100.

      ENDIF.

********** End of Code by Kanishk Arora *************
  ENDCASE.

ENDMODULE.

FORM dequeue_lock.

  CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
    EXPORTING
*     mode_agr_agrs = 'E'              " Lock mode for table AGR_AGRS
      mandt    = sy-mandt         " Enqueue argument 01
      agr_name = agr_agrs-agr_name                " Enqueue argument 02
*     child_agr     =                  " Enqueue argument 03
*     x_agr_name    = space            " Fill argument 02 with initial value?
*     x_child_agr   = space            " Fill argument 03 with initial value?
*     _scope   = '3'
*     _synchron     = space            " Synchonous unlock
*     _collect = ' '              " Initially only collect lock
    .

ENDFORM.

FORM enqueue_lock.
*  DATA: lv_subrc TYPE sy-subrc.
*  " Example: Lock one record
  READ TABLE itab_1 INTO zagr_agrs INDEX 1.
**  READ TABLE itab_1 INTO ezfire_req INDEX recman-current_line.
*  IF sy-subrc = 0.
  TRY.
      CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
        EXPORTING
*         MODE_AGR_AGRS  = 'X'
          mandt          = sy-mandt
          agr_name       = agr_agrs-agr_name
*         CHILD_AGR      =
*         X_AGR_NAME     = ' '
*         X_CHILD_AGR    = ' '
*         _SCOPE         = '2'
*         _WAIT          = ' '
*         _COLLECT       = ' '
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      IF sy-subrc <> 0.
        CASE sy-subrc.
          WHEN 1.
            MESSAGE e010(zz_arc_recman) WITH agr_agrs-agr_name.
          WHEN 2.
            MESSAGE e011(zz_arc_recman).
          WHEN OTHERS.
            MESSAGE e008(zz_arc_recman).
        ENDCASE.
      ENDIF.
    CATCH cx_sy_no_handler INTO DATA(lx_err).
      MESSAGE lx_err->get_text( ) TYPE 'E'.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module STATUS_0001 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0001 OUTPUT.
  SET PF-STATUS 'STATUS_0001'.
  SET TITLEBAR 'TITLE'.
  SELECT SINGLE text FROM agr_texts INTO zagr_agrs-agr_name_descr ##WARN_OK
    WHERE agr_name = agr_agrs-agr_name
      AND spras EQ sy-langu.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0001  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0001 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.
  CASE save_ok.
    WHEN 'DOWNLOAD'.
***      SUBMIT z_arc_download_composite_role
***        WITH p_role = agr_agrs-agr_name
***        AND RETURN.
    WHEN 'BACK'.
      CLEAR: itab_1, zagr_agrs, gv_agr_desc.
      LEAVE TO SCREEN 0.
*      SET SCREEN 100.
*      LEAVE SCREEN.
    WHEN 'EXIT'.
      CLEAR: itab_1, zagr_agrs, gv_agr_desc.
      LEAVE TO SCREEN 0. " Navigates back one step in the call stack
    WHEN 'CANCEL'.
      CLEAR: itab_1, zagr_agrs, gv_agr_desc.
      LEAVE PROGRAM.

    WHEN 'CREATE'.
      IF agr_agrs-agr_name IS INITIAL.
        MESSAGE e000(zz_arc_recman) DISPLAY LIKE 'E'.
*      ELSE.
*        PERFORM check_owner_group.
      ENDIF.

      SELECT *
        FROM agr_agrs
        INTO CORRESPONDING FIELDS OF TABLE @itab_1 ##TOO_MANY_ITAB_FIELDS
        WHERE agr_name = @agr_agrs-agr_name.
      IF sy-subrc EQ 0.
        MESSAGE e003(zz_arc_recman) DISPLAY LIKE 'I' WITH agr_agrs-agr_name.
        LEAVE SCREEN.
      ELSE.
*----------------------------------------------------------------------------------------------------------------*
* Lock-Objekte wurden verwendet, um den Zugriff auf dieselben Daten durch mehrere Programme zu synchronisieren.
*----------------------------------------------------------------------------------------------------------------*
        PERFORM enqueue_lock.

********* Start of Code by Kanishk Arora **************

        gv_action_mode = 'CREATE'.
        CLEAR gv_owner_group.
        CLEAR gv_old_owner_group.
        gv_ownergrp_edit = abap_true.

********* End of Code by Kanishk Arora **************


        CALL SCREEN 100.
      ENDIF.

    WHEN 'CHANGE'.
      IF agr_agrs-agr_name IS INITIAL.
        MESSAGE e000(zz_arc_recman) DISPLAY LIKE 'E'.
*      ELSE.
*        PERFORM check_owner_group.
      ENDIF.
      IF itab_1 IS INITIAL.
        SELECT *
*              FROM agr_agrs
              FROM zcomp_role_hdr
              INTO CORRESPONDING FIELDS OF TABLE @itab_1 ##TOO_MANY_ITAB_FIELDS
              WHERE agr_name = @agr_agrs-agr_name.

        IF sy-subrc IS NOT INITIAL.
          MESSAGE e018(zz_arc_recman) DISPLAY LIKE 'E' WITH agr_agrs-agr_name.
        ENDIF.

********** Start of Code by Kanishk Arora***********

        SELECT SINGLE owner_group
          FROM zcomp_role_hdr
          INTO gv_old_owner_group
          WHERE agr_name = agr_agrs-agr_name.

        gv_owner_group = gv_old_owner_group.

********** End of Code by Kanishk Arora*************

      ENDIF.
*----------------------------------------------------------------------------------------------------------------*
* Lock-Objekte wurden verwendet, um den Zugriff auf dieselben Daten durch mehrere Programme zu synchronisieren.
*----------------------------------------------------------------------------------------------------------------*
      PERFORM enqueue_lock.

********* Start of Code by Kanishk Arora **************

      gv_action_mode = 'CHANGE'.
      gv_ownergrp_edit = abap_false.

********* End of Code by Kanishk Arora **************

      CALL SCREEN 100.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form send_email
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM send_email.
  DATA: lt_to      TYPE zcl_arc_mailer=>tty_addr,
        lv_subject TYPE string,
        lv_body    TYPE string,
        lv_success TYPE abap_bool,
        lt_ret     TYPE zcl_arc_mailer=>tty_ret,
        ls_req     TYPE zcomp_role_hdr. " adjust type if needed
  DATA: lo_send_request TYPE REF TO cl_bcs,
        lo_document     TYPE REF TO cl_document_bcs,
        lo_sender       TYPE REF TO cl_sapuser_bcs,
        lo_recipient    TYPE REF TO if_recipient_bcs,
        lt_html_content TYPE bcsy_text.

  " --- Get Role Owners
  DATA: lt_dd07v TYPE STANDARD TABLE OF dd07v,
*        lt_rng   TYPE RANGE OF zrecman_owners-owner_group.
        lt_rng   TYPE RANGE OF zrecman_owners-owner_group.

  CALL FUNCTION 'DD_DOMVALUES_GET'
    EXPORTING
      domname   = 'ZZ_OWNER_GROUP'
      langu     = sy-langu
    TABLES
      dd07v_tab = lt_dd07v.

  LOOP AT lt_dd07v INTO DATA(ls_dd07v) WHERE domvalue_l IS NOT INITIAL.
    " Check if AGR_NAME contains the domain value
    IF zagr_agrs-agr_name CS ls_dd07v-domvalue_l.
      APPEND VALUE #( sign   = 'I'
                      option = 'CP'
                      low    = |*{ ls_dd07v-domvalue_l }*| ) TO lt_rng.
    ENDIF.
  ENDLOOP.

*-> Role Owners and Emails address Mapping table
  SELECT *
    FROM zrecman_owners
    INTO TABLE @DATA(lt_role_owners)
    WHERE owner_group IN @lt_rng.

*  IF lt_to IS INITIAL.
  IF lt_role_owners IS INITIAL.
    MESSAGE 'No role owner has been maintained for this composite role' TYPE 'E'.
    RETURN.
    EXIT.
  ENDIF.

  " Collect all non-empty email addresses from role owners into mailer address list
  LOOP AT lt_role_owners INTO DATA(ls_owner).
    IF ls_owner-owner_email IS NOT INITIAL.
      APPEND ls_owner-owner_email TO lt_to.
    ENDIF.
    IF ls_owner-backup_owner_email IS NOT INITIAL.
      APPEND ls_owner-backup_owner_email TO lt_to.
    ENDIF.
  ENDLOOP.

  LOOP AT itab_1 INTO ls_req.

    CLEAR: lv_subject, lv_body, lv_success, lt_ret, lt_html_content.

    lv_subject = |[RecMan] New PENDING request for Single role { ls_req-child_agr } in composite Role { ls_req-agr_name }|.


*--- Build HTML email body<b>Z_ARC_RECMAN_APPROVE</b>
    APPEND '<html><body>'                                     TO lt_html_content.
    APPEND |<p>Dear { sy-uname },</p>|                        TO lt_html_content.
    APPEND |<p><b>Composite Role :</b> { ls_req-agr_name }</p>|     TO lt_html_content.
    APPEND |<p><b>Description :</b> { ls_req-agr_name_descr }</p>|     TO lt_html_content.
    APPEND |<p><b>Single Role :</b> { ls_req-child_agr }</p>|     TO lt_html_content.
    APPEND '<p><b>Status :</b> PENDING</p>'                   TO lt_html_content.
    APPEND '<p>Please use one of the below link to open the SAP transaction  to approve or reject the role:</p>' TO lt_html_content.

    "  Web UI Link
    APPEND '<a href="https://s4h2023.remoteides.com:44323/sap/bc/gui/sap/its/webgui?~transaction=Z_ARC_RECMAN_APPROVE">' TO lt_html_content.
    APPEND '👉 Open Z_ARC_RECMAN_APPROVE in Browser (Fiori / WebGUI)</a></p>' TO lt_html_content.


    APPEND '<p>Best regards,<br/>SAP Security Admin</p>' TO lt_html_content.
    APPEND '</body></html>' TO lt_html_content.

    CALL METHOD zcl_arc_mailer=>send
      EXPORTING
        it_to        = lt_to
        iv_subject   = lv_subject
        iv_body_text = lv_body
        iv_body_html = lt_html_content
      IMPORTING
        ev_success   = lv_success
        et_return    = lt_ret.

    IF lv_success = abap_true.
      MESSAGE |Approvers notified for { ls_req-agr_name }.| TYPE 'S'.
    ELSE.
      MESSAGE |Email failed for { ls_req-agr_name } — check SOST.| TYPE 'E'.
    ENDIF.

  ENDLOOP.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_owner_group
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM check_owner_group .
  DATA: lt_values TYPE STANDARD TABLE OF dd07v,
        ls_value  TYPE dd07v,
        lv_agr    TYPE zrecman_owners-identicator,
        lv_found  TYPE abap_bool.

  " Read current role name from screen
  lv_agr = agr_agrs-agr_name.

  DATA: lv_agr_upper   TYPE string,
        lv_identicator TYPE string.

***  lv_agr_upper = to_upper( |*{ lv_agr }*| ).
  lv_agr_upper = to_upper( |{ lv_agr }| ).
  lv_found     = abap_false.

  IF gv_owner_group IS INITIAL.
    MESSAGE e024(zz_arc_recman) DISPLAY LIKE 'I' WITH lv_agr.
  ENDIF.

  SELECT * FROM zrecman_owners INTO TABLE @DATA(lt_owners)
    WHERE owner_group = @gv_owner_group.

  LOOP AT lt_owners ASSIGNING FIELD-SYMBOL(<ls_owner>)
    WHERE identicator IS NOT INITIAL.

    lv_identicator = <ls_owner>-identicator.
***    CONDENSE lv_identicator NO-GAPS.
    lv_identicator = to_upper( |{ lv_identicator }| ).

    IF lv_agr_upper CS lv_identicator.
      lv_found = abap_true.
      EXIT.
    ENDIF.
  ENDLOOP.

  IF lv_found = abap_false.
    MESSAGE w021(zz_arc_recman) DISPLAY LIKE 'W' WITH lv_agr.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Module DROPDOWN OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE dropdown_ownergrp OUTPUT.
  CLEAR gt_owner_group.

  CALL FUNCTION 'DD_DOMVALUES_GET'
    EXPORTING
      domname        = 'ZZ_OWNER_GROUP'
      text           = 'X'
      langu          = sy-langu
    TABLES
      dd07v_tab      = gt_domvalues
    EXCEPTIONS
      wrong_textflag = 1
      OTHERS         = 2.

  IF sy-subrc = 0.
    LOOP AT gt_domvalues INTO gs_domvalue
      WHERE domvalue_l IS NOT INITIAL.

      CLEAR gs_owner_group.
      gs_owner_group-key  = gs_domvalue-domvalue_l.
      gs_owner_group-text = gs_domvalue-ddtext.
      APPEND gs_owner_group TO gt_owner_group.

    ENDLOOP.
  ENDIF.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'OWNER_GROUP'
      values = gt_owner_group.
ENDMODULE.

*&---------------------------------------------------------------------*
*&  Custom change log for ZCOMP_ROLE_HDR
*&  Target table ZCOMP_ROLE_LOG:
*&    MANDT(KEY) LOG_ID(KEY,C32) CHANGE_GROUP(C32) AGR_NAME(C30)
*&    CHILD_AGR(C30) CHANGE_TYPE(C10) FIELD_NAME(C30)
*&    VALUE_OLD(C255) VALUE_NEW(C255) ACTION_MODE(C10)
*&    CHANGED_BY(SYUNAME) CHANGED_ON(SYDATS) CHANGED_AT(TIMESTAMPL)
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*&  Call from SAVE, AFTER `MODIFY zcomp_role_hdr` and
*&  BEFORE the `COMMIT WORK` that closes the LUW:
*&      PERFORM write_change_log.
*&---------------------------------------------------------------------*
FORM write_change_log.

  DATA: lt_log     TYPE tt_role_log,
        ls_tpl     TYPE zcomp_role_log,
        ls_new_hdr TYPE zcomp_role_hdr,
        ls_old_hdr TYPE zcomp_role_hdr,
        lv_ts      TYPE timestampl.

  GET TIME STAMP FIELD lv_ts.

  " fields shared by every row written in this save
  CLEAR ls_tpl.
  TRY.
      ls_tpl-change_group = cl_system_uuid=>create_uuid_c32_static( ).
    CATCH cx_uuid_error.
      ls_tpl-change_group = |{ sy-datum }{ sy-uzeit }{ sy-uname }|.
  ENDTRY.
  ls_tpl-agr_name    = zagr_agrs-agr_name.
  ls_tpl-action_mode = gv_action_mode.
  ls_tpl-changed_by  = sy-uname.
  ls_tpl-changed_on  = sy-datum.
  ls_tpl-changed_at  = lv_ts.

  IF gv_action_mode = 'CREATE'.
    " new composite role -> every single role is an ADD
    LOOP AT itab_1 INTO DATA(ls_new_c).
      PERFORM append_log USING 'ADD' ls_new_c-child_agr space space space
                         CHANGING lt_log ls_tpl.
    ENDLOOP.

  ELSE.                                   " gv_action_mode = 'CHANGE'
    " adds + field-level changes
    LOOP AT itab_1 INTO DATA(ls_new).
      READ TABLE it_snapshot INTO DATA(ls_old)
           WITH KEY child_agr = ls_new-child_agr.
      IF sy-subrc <> 0.
        PERFORM append_log USING 'ADD' ls_new-child_agr space space space
                           CHANGING lt_log ls_tpl.
      ELSE.
        CLEAR: ls_new_hdr, ls_old_hdr.
        MOVE-CORRESPONDING ls_new TO ls_new_hdr.
        MOVE-CORRESPONDING ls_old TO ls_old_hdr.
        ls_new_hdr-agr_name = zagr_agrs-agr_name.
        ls_old_hdr-agr_name = zagr_agrs-agr_name.
        PERFORM compare_fields USING ls_old_hdr ls_new_hdr
                               CHANGING lt_log ls_tpl.
      ENDIF.
    ENDLOOP.

    " removals
    LOOP AT it_snapshot INTO ls_old.
      READ TABLE itab_1 TRANSPORTING NO FIELDS
           WITH KEY child_agr = ls_old-child_agr.
      IF sy-subrc <> 0.
        PERFORM append_log USING 'DELETE' ls_old-child_agr space space space
                           CHANGING lt_log ls_tpl.
      ENDIF.
    ENDLOOP.
  ENDIF.

  IF lt_log IS NOT INITIAL.
    INSERT zcomp_role_log FROM TABLE lt_log.
    " persisted by the existing COMMIT WORK of the save
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
FORM append_log USING p_type  TYPE c
                      p_child TYPE any
                      p_field TYPE c
                      p_old   TYPE any
                      p_new   TYPE any
             CHANGING pt_log  TYPE tt_role_log
                      ps_tpl  TYPE zcomp_role_log.

  DATA ls_log TYPE zcomp_role_log.

  ls_log = ps_tpl.                        " inherit common fields
  TRY.
      ls_log-log_id = cl_system_uuid=>create_uuid_c32_static( ).
    CATCH cx_uuid_error.
  ENDTRY.
  ls_log-child_agr   = p_child.
  ls_log-change_type = p_type.
  ls_log-field_name  = p_field.
  ls_log-value_old   = p_old.
  ls_log-value_new   = p_new.
  APPEND ls_log TO pt_log.

ENDFORM.

*&---------------------------------------------------------------------*
FORM compare_fields USING ps_old TYPE zcomp_role_hdr
                          ps_new TYPE zcomp_role_hdr
                 CHANGING pt_log TYPE tt_role_log
                          ps_tpl TYPE zcomp_role_log.

  " fields excluded from value logging (key + technical/audit columns)
  CONSTANTS lc_skip TYPE string
    VALUE 'MANDT,AGR_NAME,CHILD_AGR,CREATE_FLAG,CTRL_DOC_OK,WF_APPROVAL_STATUS,APPROVER,REJECT_REASON,APPROVED_AT,REJECTED_AT,CREATED_AT,CHANGED_AT'.

  DATA lo_sdescr TYPE REF TO cl_abap_structdescr.
  lo_sdescr ?= cl_abap_typedescr=>describe_by_data( ps_new ).

  LOOP AT lo_sdescr->components INTO DATA(ls_comp).
    IF |,{ lc_skip },| CS |,{ ls_comp-name },|.
      CONTINUE.
    ENDIF.
    ASSIGN COMPONENT ls_comp-name OF STRUCTURE ps_old TO FIELD-SYMBOL(<lo>).
    IF sy-subrc <> 0. CONTINUE. ENDIF.
    ASSIGN COMPONENT ls_comp-name OF STRUCTURE ps_new TO FIELD-SYMBOL(<ln>).
    IF sy-subrc <> 0. CONTINUE. ENDIF.
    IF <lo> <> <ln>.
      PERFORM append_log USING 'CHANGE' ps_new-child_agr ls_comp-name <lo> <ln>
                         CHANGING pt_log ps_tpl.
    ENDIF.
  ENDLOOP.

ENDFORM.
