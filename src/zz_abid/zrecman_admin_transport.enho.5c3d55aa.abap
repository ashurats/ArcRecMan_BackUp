"Name: \PR:SAPLPRGN_TREE\FO:TRANSPORT_ACTIVITY_GROUP_NEW\SE:BEGIN\EI
ENHANCEMENT 0 ZRECMAN_ADMIN_TRANSPORT.
     DATA: lv_coll_role       TYPE char01,
           ls_zrecman_logs_tr TYPE zrecman_logs_tr,
           lt_zrecman_logs_tr TYPE TABLE OF zrecman_logs_tr,
           lv_ts              TYPE timestamp,
           lv_d               TYPE d,
           lv_t               TYPE t,
           lv_timestamp       TYPE char14.

     GET TIME STAMP FIELD lv_ts.
     CONVERT TIME STAMP lv_ts TIME ZONE 'UTC' INTO DATE lv_d TIME lv_t.
     lv_timestamp = |{ lv_d }{ lv_t }|.          " -> 'YYYYMMDDHHMMSS'

     CALL FUNCTION 'PRGN_GET_COLLECTIVE_AGR_FLAG'
       EXPORTING
         activity_group      = id_role
       IMPORTING
         collective_agr_flag = lv_coll_role
       EXCEPTIONS
         agr_does_not_exist  = 1
         flag_not_available  = 2
         OTHERS              = 3.
     IF lv_coll_role EQ abap_true.
       SELECT * FROM zcomp_role_hdr INTO TABLE @DATA(lt_zcomp_role_hdr)
         WHERE agr_name EQ @id_role
           AND wf_approval_status NE 'APPROVED'.
       IF sy-subrc IS INITIAL.
         LOOP AT lt_zcomp_role_hdr INTO DATA(ls_zcomp_role_hdr).
           MOVE-CORRESPONDING ls_zcomp_role_hdr TO ls_zrecman_logs_tr.
           ls_zrecman_logs_tr-blocked_role      = ls_zrecman_logs_tr-child_agr.
           ls_zrecman_logs_tr-blocked_timestamp = lv_timestamp.
           ls_zrecman_logs_tr-blocked_by        = sy-uname.
           ls_zrecman_logs_tr-system_id         = sy-sysid.
           APPEND ls_zrecman_logs_tr TO lt_zrecman_logs_tr.
           CLEAR: ls_zrecman_logs_tr.
         ENDLOOP.
         MODIFY zrecman_logs_tr FROM TABLE lt_zrecman_logs_tr.
         MESSAGE e012(zz_arc_recman) WITH id_role.
         EXIT.
       ENDIF.
     ENDIF.

     SET PARAMETER ID 'ZUC' FIELD sy-ucomm. "This stores the value of sy-ucomm in SAP memory.

ENDENHANCEMENT.
