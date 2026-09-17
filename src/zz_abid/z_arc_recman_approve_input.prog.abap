*&---------------------------------------------------------------------*
*& Include          Z_ARC_RECMAN_APPROVE_INPUT
*&---------------------------------------------------------------------*


      MODULE user_command_0200 INPUT.
        DATA: lt_rows     TYPE lvc_t_row,
              ls_row      TYPE lvc_s_row,
              ls_role_hdr TYPE zcomp_role_hdr,
              lv_now      TYPE char14.

        CASE sy-ucomm.
          WHEN 'BACK' OR 'CANCEL' OR 'EXIT'.
            LEAVE TO SCREEN 0.

          WHEN 'REFRESH'.
            SET SCREEN '0200'.
            LEAVE SCREEN.

          WHEN 'APPROVE' OR 'REJECT'.
*      GET PARAMETER ID 'CHK' FIELD chk.

            DATA: ls_zrecman_logs TYPE zrecman_logs,
                  lt_zrecman_logs TYPE TABLE OF zrecman_logs.
            DATA: ls_text TYPE t884t-txt.
            DATA: lv_ts TYPE timestamp, lv_d TYPE d, lv_t TYPE t.

            DATA: lv_requser TYPE zcomp_role_hdr-req_user,
                  lv_reqid   TYPE zfire_req-req_id,
                  lv_message TYPE bapi_msg.


            GET TIME STAMP FIELD lv_ts.
            CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
            lv_now = |{ lv_d }{ lv_t }|.          " -> 'YYYYMMDDHHMMSS'

            lo_alv_200->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
            IF lt_rows IS INITIAL.
              MESSAGE 'Select at least one request.' TYPE 'I'.
              RETURN.
            ENDIF.

            IF lv_requser = sy-uname.
              MESSAGE e002(zz_arc_firefighter)
                         WITH lv_reqid INTO lv_message.
            ENDIF.

            LOOP AT lt_rows INTO ls_row.
              READ TABLE lt_pending_out INTO ls_role_hdr INDEX ls_row-index.
              IF sy-subrc <> 0.
                CONTINUE.
              ENDIF.

              TRY.
                  CALL FUNCTION 'ENQUEUE_EZAGR_AGRS'
                    EXPORTING
*                     MODE_AGR_AGRS  = 'X'
                      mandt          = sy-mandt
                      agr_name       = ls_role_hdr-agr_name
*                     CHILD_AGR      =
*                     X_AGR_NAME     = ' '
*                     X_CHILD_AGR    = ' '
*                     _SCOPE         = '2'
*                     _WAIT          = ' '
*                     _COLLECT       = ' '
                    EXCEPTIONS
                      foreign_lock   = 1
                      system_failure = 2
                      OTHERS         = 3.
                  IF sy-subrc <> 0.
                    CASE sy-subrc.
                      WHEN 1.
                        MESSAGE e010(zz_arc_recman) WITH ls_role_hdr-agr_name.
                      WHEN 2.
                        MESSAGE e011(zz_arc_recman).
                      WHEN OTHERS.
                        MESSAGE e008(zz_arc_recman).
                    ENDCASE.
                  ENDIF.
                CATCH cx_sy_no_handler INTO DATA(lx_err).
                  MESSAGE lx_err->get_text( ) TYPE 'E'.
              ENDTRY.


              SELECT SINGLE * FROM zcomp_role_hdr INTO @ls_role_hdr
               WHERE agr_name = @ls_role_hdr-agr_name
                AND child_agr = @ls_role_hdr-child_agr.
              IF sy-subrc <> 0 OR ls_role_hdr-wf_approval_status <> 'PENDING'.
                CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
                  EXPORTING
                    mandt    = sy-mandt         " Enqueue argument 01
                    agr_name = ls_role_hdr-agr_name.               " Enqueue argument 02
                CONTINUE.
              ENDIF.

              IF sy-ucomm = 'APPROVE'. " Approve roles

*-> Role Owners and Emails address Mapping table
                " --- Get Role Owners
                DATA: lt_dd07v TYPE STANDARD TABLE OF dd07v,
                      lt_rng   TYPE RANGE OF zrecman_owners-owner_group.

*                CALL FUNCTION 'DD_DOMVALUES_GET'
*                  EXPORTING
*                    domname   = 'ZZ_OWNER_GROUP'
*                    langu     = sy-langu
*                  TABLES
*                    dd07v_tab = lt_dd07v.
*
*                LOOP AT lt_dd07v INTO DATA(ls_dd07v) WHERE domvalue_l IS NOT INITIAL.
*                  IF ls_role_hdr-agr_name CS ls_dd07v-domvalue_l.
*                    APPEND VALUE #( sign   = 'I'
*                                    option = 'CP'
*                                    low    = |*{ ls_dd07v-domvalue_l }*| ) TO lt_rng.
*                  ENDIF.
*                ENDLOOP.
*
*                SELECT owner_id
*                  FROM zrecman_owners
*                  INTO  @DATA(lv_role_owner)
*                  WHERE owner_group IN @lt_rng.
*                ENDSELECT.
*                IF sy-subrc EQ 0.
*                  ls_role_hdr-wf_approval_status = 'APPROVED'.
*                  ls_role_hdr-approved_at        = lv_now.  " set on approve
*                  ls_role_hdr-approver           = sy-uname.
*                  MOVE-CORRESPONDING ls_role_hdr TO ls_zrecman_logs.
*                  ls_zrecman_logs-system_id       = sy-sysid.
*                ELSE.
*                  MESSAGE e013(zz_arc_recman) WITH ls_role_hdr-child_agr .
*                ENDIF.

*************Start of Code by Kanishk Arora**************************

                CLEAR:
                  lv_role_authorized,
                  lv_role_escalated.

                SELECT SINGLE escalation_sent
                  FROM zrecman_reminder
                  INTO @lv_role_escalated
                  WHERE agr_name  = @ls_role_hdr-agr_name
                    AND child_agr = @ls_role_hdr-child_agr.

                lv_role_authorized =
                  zcl_arc_owngrp_service=>is_user_in_owner_group(
                    iv_user        = sy-uname
                    iv_owner_group = ls_role_hdr-owner_group
                    iv_escalated   = xsdbool(
                                       lv_role_escalated = 'X' ) ).

                IF lv_role_authorized = abap_true.

                  ls_role_hdr-wf_approval_status = 'APPROVED'.
                  ls_role_hdr-approved_at        = lv_now.
                  ls_role_hdr-approver           = sy-uname.

                  MOVE-CORRESPONDING ls_role_hdr TO ls_zrecman_logs.
                  ls_zrecman_logs-system_id = sy-sysid.

                ELSE.

                  MESSAGE e013(zz_arc_recman)
                      WITH ls_role_hdr-child_agr.

                ENDIF.

*************End of Code by Kanishk Arora****************************

              ELSEIF sy-ucomm = 'REJECT'.  " Reject roles
                " --- Get Role Owners
*                CALL FUNCTION 'DD_DOMVALUES_GET'
*                  EXPORTING
*                    domname   = 'ZZ_OWNER_GROUP'
*                    langu     = sy-langu
*                  TABLES
*                    dd07v_tab = lt_dd07v.
*
*                LOOP AT lt_dd07v INTO ls_dd07v WHERE domvalue_l IS NOT INITIAL.
*                  IF ls_role_hdr-agr_name CS ls_dd07v-domvalue_l.
*                    APPEND VALUE #( sign   = 'I'
*                                    option = 'CP'
*                                    low    = |*{ ls_dd07v-domvalue_l }*| ) TO lt_rng.
*                  ENDIF.
*                ENDLOOP.
*
*                SELECT owner_id
*                  FROM zrecman_owners
*                  INTO  lv_role_owner
*                WHERE owner_group IN lt_rng.
*                ENDSELECT.
*                IF sy-subrc EQ 0.
*                  CALL FUNCTION 'POPUP_TO_MODIFY_TEXT'
*                    EXPORTING
*                      titel          = TEXT-001
*                      value1         = ''
*                    IMPORTING
*                      value1         = ls_text
*                    EXCEPTIONS
*                      titel_too_long = 1
*                      OTHERS         = 2.
*
*                  IF ls_text IS INITIAL.
*                    MESSAGE e016(zz_arc_recman).
*                    EXIT.
*                    LEAVE TO SCREEN 0.
*                  ENDIF.
*                  ls_role_hdr-wf_approval_status = 'REJECTED'.
*                  ls_role_hdr-rejected_at   = lv_now.  " set on reject
*                  ls_role_hdr-reject_reason = ls_text.  " set on reject reason
*                  MOVE-CORRESPONDING ls_role_hdr TO ls_zrecman_logs.
*                  ls_zrecman_logs-system_id       = sy-sysid.
*                ENDIF.
*             ENDIF.

**************Start of Code by Kanishk Arora********************************

                CLEAR: lv_role_authorized, lv_role_escalated.

                SELECT SINGLE escalation_sent
                  FROM zrecman_reminder
                  INTO @lv_role_escalated
                  WHERE agr_name  = @ls_role_hdr-agr_name
                    AND child_agr = @ls_role_hdr-child_agr.

                lv_role_authorized =
                  zcl_arc_owngrp_service=>is_user_in_owner_group(
                    iv_user        = sy-uname
                    iv_owner_group = ls_role_hdr-owner_group
                    iv_escalated   = xsdbool(
                                       lv_role_escalated = 'X' ) ).

                IF lv_role_authorized = abap_true.

                  CALL FUNCTION 'POPUP_TO_MODIFY_TEXT'
                    EXPORTING
                      titel          = TEXT-001
                      value1         = ''
                    IMPORTING
                      value1         = ls_text
                    EXCEPTIONS
                      titel_too_long = 1
                      OTHERS         = 2.

                  IF ls_text IS INITIAL.
                    MESSAGE e016(zz_arc_recman).
                    EXIT.
                    LEAVE TO SCREEN 0.
                  ENDIF.

                  ls_role_hdr-wf_approval_status = 'REJECTED'.
                  ls_role_hdr-rejected_at        = lv_now.
                  ls_role_hdr-reject_reason      = ls_text.
                  ls_role_hdr-approver           = sy-uname.

                  MOVE-CORRESPONDING ls_role_hdr TO ls_zrecman_logs.
                  ls_zrecman_logs-system_id = sy-sysid.

                ELSE.

                  MESSAGE e013(zz_arc_recman)
                    WITH ls_role_hdr-child_agr.

                ENDIF.
              ENDIF.


**************End of Code by Kanishk Arora**********************************

              MODIFY zcomp_role_hdr FROM ls_role_hdr.
              COMMIT WORK.

              MODIFY zrecman_logs FROM ls_zrecman_logs.
              COMMIT WORK.

              CALL FUNCTION 'DEQUEUE_EZAGR_AGRS'
                EXPORTING
*                 mode_agr_agrs = 'E'              " Lock mode for table AGR_AGRS
                  mandt    = sy-mandt         " Enqueue argument 01
                  agr_name = ls_role_hdr-agr_name.               " Enqueue argument 02
            ENDLOOP.
            MESSAGE s001(zz_arc_recman) WITH ls_role_hdr-agr_name.
            SET SCREEN '0200'.
            LEAVE SCREEN.
        ENDCASE.
      ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
      MODULE user_command_0100 INPUT.
        save_ok = ok_code.
        CLEAR ok_code.
        CASE save_ok.
          WHEN 'CHK'.
          WHEN 'LOGS_TR'.
            PERFORM tr_logs_alv.
          WHEN 'LOGS'.
            PERFORM logs_alv.
          WHEN 'DL_LOGS'.
            PERFORM dl_logs.
          WHEN 'PEND'.
            CALL SCREEN 200.
          WHEN 'LOGS_CHNG'.
            SUBMIT zcomp_role_change_logs VIA SELECTION-SCREEN AND RETURN.
**********Start of Code by Kanishk Arora**************************
          WHEN 'OWNGRP'.
            CALL SCREEN 300.
**********End of Code by Kanishk Arora****************************
          WHEN 'EXIT' OR 'BACK'.
            LEAVE PROGRAM.
        ENDCASE.

      ENDMODULE.


      FORM dl_logs.
        SUBMIT z_arc_recman_dl_roles_logs_rpt VIA SELECTION-SCREEN AND RETURN.
      ENDFORM.

      FORM logs_alv .

        DATA(lt_logs_db) = VALUE ty_it_logs( ).

        TRY.
            SELECT * FROM zrecman_logs
              INTO CORRESPONDING FIELDS OF TABLE @lt_logs_db
              ORDER BY created_at DESCENDING, agr_name DESCENDING.

            cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                    CHANGING  t_table      = lt_logs_db ).
            " Enable standard functions (sort, filter, layout, export…)
            lo_functions = lo_alv->get_functions( ).
            lo_functions->set_all( abap_true ).


            "  Enable ALV layout (variants)
            lo_alv->get_layout( )->set_key( VALUE salv_s_layout_key( report = sy-repid ) ).
            lo_alv->get_layout( )->set_save_restriction( if_salv_c_layout=>restrict_none ).

            " --- Set column width manually
            DATA(lo_cols) = lo_alv->get_columns( ).
            lo_cols->get_column( 'AGR_NAME' )->set_output_length( value = '40' ).
            IF sy-langu EQ 'EN'.
              lv_scrtext_s = 'Composite Role' .
              lo_cols->get_column( 'AGR_NAME' )->set_short_text( value = lv_scrtext_s ).
              lo_cols->get_column( 'AGR_NAME' )->set_medium_text( 'Composite Role' ).
              lo_cols->get_column( 'AGR_NAME' )->set_long_text( 'Composite Role' ).

              lv_scrtext_s = 'Single Role' .
              lo_cols->get_column( 'CHILD_AGR' )->set_short_text( value = lv_scrtext_s ).
              lo_cols->get_column( 'CHILD_AGR' )->set_medium_text( 'Single Role' ).
              lo_cols->get_column( 'CHILD_AGR' )->set_long_text( 'Single Role' ).
            ELSEIF sy-langu EQ 'DE'.
              lv_scrtext_s = 'Sammel-Rolle' .
              lo_cols->get_column( 'AGR_NAME' )->set_short_text( value = lv_scrtext_s ).
              lo_cols->get_column( 'AGR_NAME' )->set_medium_text( 'Sammel-Rolle' ).
              lo_cols->get_column( 'AGR_NAME' )->set_long_text( 'Sammel-Rolle' ).

              lv_scrtext_s = 'Einzel-Rolle' .
              lo_cols->get_column( 'CHILD_AGR' )->set_short_text( lv_scrtext_s ).
              lo_cols->get_column( 'CHILD_AGR' )->set_medium_text( 'Einzel-Rolle' ).
              lo_cols->get_column( 'CHILD_AGR' )->set_long_text( 'Einzel-Rolle' ).
            ENDIF.
            lo_cols->get_column( 'CHILD_AGR' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'SYSTEM_ID' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'WF_APPROVAL_STATUS' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'APPROVER' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'REJECT_REASON' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'APPROVED_AT' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'REJECTED_AT' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'CREATED_AT' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'CHANGED_AT' )->set_output_length( value = '20' ).


            " --- Set cell color
            LOOP AT lt_logs_db ASSIGNING FIELD-SYMBOL(<fs_logs_db>).
              IF <fs_logs_db>-wf_approval_status = 'REJECTED'.
                <fs_logs_db>-color = VALUE #( ( fname = 'WF_APPROVAL_STATUS'
                                                color-col = col_negative
                                                color-int = 1
                                                color-inv = 0 ) ).
              ELSEIF <fs_logs_db>-wf_approval_status = 'APPROVED'.
                <fs_logs_db>-color = VALUE #( ( fname = 'WF_APPROVAL_STATUS'
                                                color-col = col_positive
                                                color-int = 1
                                                color-inv = 0 ) ).
              ENDIF.

              IF <fs_logs_db>-created_at IS NOT INITIAL.
                lv_in = <fs_logs_db>-created_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_db>-created_at = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_db>-approved_at IS NOT INITIAL.
                lv_in = <fs_logs_db>-approved_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_db>-approved_at = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_db>-rejected_at IS NOT INITIAL.
                lv_in = <fs_logs_db>-rejected_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_db>-rejected_at = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_db>-changed_at IS NOT INITIAL.
                lv_in = <fs_logs_db>-changed_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_db>-changed_at = |{ lv_out }|.
              ENDIF.

            ENDLOOP.

            lo_alv->get_columns( )->set_color_column( 'COLOR' ).

            " --- Display ALV
            lo_alv->display( ).

          CATCH cx_root INTO DATA(e_text).
            WRITE: / e_text->get_text( ).
        ENDTRY.

      ENDFORM.
      FORM tr_logs_alv.
        TRY.
            DATA(lt_logs_tr) = VALUE ty_it_logs_tr( ).
            DATA: lo_alv TYPE REF TO cl_salv_table.
            DATA: lv_SCRTEXT_S TYPE scrtext_s.

            SELECT * FROM zrecman_logs_tr
              INTO CORRESPONDING FIELDS OF TABLE @lt_logs_tr
              ORDER BY created_at DESCENDING, agr_name DESCENDING.


            cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                    CHANGING  t_table      = lt_logs_tr ).

            " --- Set column width manually
            DATA(lo_cols) = lo_alv->get_columns( ).
            lo_cols->get_column( 'AGR_NAME' )->set_output_length( value = '40' ).
            IF sy-langu EQ 'EN'.
              lv_scrtext_s = 'Composite Role' .
              lo_cols->get_column( 'AGR_NAME' )->set_short_text( value = lv_scrtext_s ).
              lo_cols->get_column( 'AGR_NAME' )->set_medium_text( 'Composite Role' ).
              lo_cols->get_column( 'AGR_NAME' )->set_long_text( 'Composite Role' ).

              lv_scrtext_s = 'Single Role' .
              lo_cols->get_column( 'CHILD_AGR' )->set_short_text( value = lv_scrtext_s ).
              lo_cols->get_column( 'CHILD_AGR' )->set_medium_text( 'Single Role' ).
              lo_cols->get_column( 'CHILD_AGR' )->set_long_text( 'Single Role' ).
            ELSEIF sy-langu EQ 'DE'.
              lv_scrtext_s = 'Sammel-Rolle' .
              lo_cols->get_column( 'AGR_NAME' )->set_short_text( value = lv_scrtext_s ).
              lo_cols->get_column( 'AGR_NAME' )->set_medium_text( 'Sammel-Rolle' ).
              lo_cols->get_column( 'AGR_NAME' )->set_long_text( 'Sammel-Rolle' ).

              lv_scrtext_s = 'Einzel-Rolle' .
              lo_cols->get_column( 'CHILD_AGR' )->set_short_text( lv_scrtext_s ).
              lo_cols->get_column( 'CHILD_AGR' )->set_medium_text( 'Einzel-Rolle' ).
              lo_cols->get_column( 'CHILD_AGR' )->set_long_text( 'Einzel-Rolle' ).
            ENDIF.
            lo_cols->get_column( 'CHILD_AGR' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'SYSTEM_ID' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'BLOCKED_ROLE' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'BLOCKED_TIMESTAMP' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'WF_APPROVAL_STATUS' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'APPROVER' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'REJECT_REASON' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'APPROVED_AT' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'REJECTED_AT' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'CREATED_AT' )->set_output_length( value = '20' ).
            lo_cols->get_column( 'CHANGED_AT' )->set_output_length( value = '20' ).


            " --- Set cell color
            LOOP AT lt_logs_tr ASSIGNING FIELD-SYMBOL(<fs_logs_tr>).
              IF <fs_logs_tr>-blocked_role IS NOT INITIAL.
                <fs_logs_tr>-color = VALUE #( ( fname = 'BLOCKED_ROLE'
                                                color-col = col_negative
                                                color-int = 1
                                                color-inv = 0 ) ).
              ENDIF.

              IF <fs_logs_tr>-blocked_timestamp IS NOT INITIAL.
                lv_in = <fs_logs_tr>-blocked_timestamp.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_tr>-blocked_timestamp = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_tr>-approved_at IS NOT INITIAL.
                lv_in = <fs_logs_tr>-approved_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_tr>-approved_at = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_tr>-rejected_at IS NOT INITIAL.
                lv_in = <fs_logs_tr>-rejected_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_tr>-rejected_at = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_tr>-created_at IS NOT INITIAL.
                lv_in = <fs_logs_tr>-created_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_tr>-created_at = |{ lv_out }|.
              ENDIF.

              IF <fs_logs_tr>-changed_at IS NOT INITIAL.
                lv_in = <fs_logs_tr>-changed_at.
                lv_year = lv_in+0(4).
                lv_mon  = lv_in+2(2).
                lv_day  = lv_in+4(2).
                lv_hh   = lv_in+6(2).
                lv_mm   = lv_in+8(2).
                lv_ss   = lv_in+10(2).

                lv_out = |{ lv_day }.{ lv_mon }.{ lv_year } { lv_hh }:{ lv_mm }:{ lv_ss }|.

                <fs_logs_tr>-changed_at = |{ lv_out }|.
              ENDIF.

            ENDLOOP.



            lo_alv->get_columns( )->set_color_column( 'COLOR' ).

            " --- Display ALV
            lo_alv->display( ).

          CATCH cx_root INTO DATA(e_text).
            WRITE: / e_text->get_text( ).
        ENDTRY.
      ENDFORM.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0300  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
      MODULE user_command_0300 INPUT.

        DATA:
          lt_rows_0300 TYPE lvc_t_row,
          ls_row_0300  TYPE lvc_s_row,
          ls_req       TYPE zcomp_owngrp_req.

        CASE sy-ucomm.

          WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
            LEAVE TO SCREEN 100.

          WHEN 'REFRESH'.
            SET SCREEN '0300'.
            LEAVE SCREEN.

          WHEN 'APPROVE_OWNGRP'.
            lo_alv_300->get_selected_rows(
        IMPORTING
          et_index_rows = lt_rows_0300 ).

            IF lt_rows_0300 IS INITIAL.
              MESSAGE 'Select at least one request.' TYPE 'I'.
              RETURN.
            ENDIF.

            LOOP AT lt_rows_0300 INTO ls_row_0300.

              READ TABLE lt_owngrp_pending
                INTO ls_req
                INDEX ls_row_0300-index.

              IF sy-subrc <> 0.
                CONTINUE.
              ENDIF.

              zcl_arc_owngrp_service=>approve_request(
                iv_req_id = ls_req-req_id
                iv_user   = sy-uname ).

            ENDLOOP.

            MESSAGE 'Request approved successfully.' TYPE 'S'.

            SET SCREEN '0300'.
            LEAVE SCREEN.

          WHEN 'REJECT_OWNGRP'.

            DATA: lv_reason_popup TYPE t884t-txt,
                  lv_reason       TYPE zcomp_owngrp_req-reject_reason.

            CALL FUNCTION 'POPUP_TO_MODIFY_TEXT'
              EXPORTING
                titel  = 'Rejection Reason'
                value1 = ''
              IMPORTING
                value1 = lv_reason_popup.

            lv_reason = lv_reason_popup.

            IF lv_reason IS INITIAL.
              MESSAGE 'Rejection reason is mandatory.' TYPE 'E'.
            ENDIF.

            lo_alv_300->get_selected_rows(
              IMPORTING
                et_index_rows = lt_rows_0300 ).

            IF lt_rows_0300 IS INITIAL.
              MESSAGE 'Select at least one request.' TYPE 'I'.
              RETURN.
            ENDIF.

            LOOP AT lt_rows_0300 INTO ls_row_0300.

              READ TABLE lt_owngrp_pending
                INTO ls_req
                INDEX ls_row_0300-index.

              IF sy-subrc <> 0.
                CONTINUE.
              ENDIF.

              zcl_arc_owngrp_service=>reject_request(
                iv_req_id = ls_req-req_id
                iv_user   = sy-uname
                iv_reason = lv_reason ).

            ENDLOOP.

            MESSAGE 'Request rejected.' TYPE 'S'.

            SET SCREEN '0300'.
            LEAVE SCREEN.

        ENDCASE.

      ENDMODULE.
