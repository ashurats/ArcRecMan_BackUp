"Name: \PR:SAPLPRGN_TREE\FO:AGR_SAVE_TO_DATABASE_AGRS\SE:END\EI
ENHANCEMENT 0 ZRECMAN_AGR_AGRS_SAVE.

  DATA: lt_zcomp_role_hdr_1 TYPE TABLE OF zcomp_role_hdr WITH HEADER LINE.
  DATA: lv_ts           TYPE timestamp,
        lv_date         TYPE d,
        lv_time         TYPE t,
        lv_current_tmps TYPE char14,
        lv_changed_at   TYPE char14,
        lv_ucomm        TYPE sy-ucomm,
        lv_coll_role    TYPE char01,
        lv_owner_grp    TYPE zz_owner_group,
        lv_og           TYPE zz_owner_group.


  TYPES: BEGIN OF ty_owner,
           owner_group TYPE dd07v-domvalue_l,
           text        TYPE dd07v-ddtext,
         END OF ty_owner.

  DATA: lt_dd07v  TYPE TABLE OF dd07v,
        lt_owner  TYPE TABLE OF ty_owner,
        lt_return TYPE TABLE OF ddshretval,
        ls_return TYPE ddshretval.

  DATA: lt_db_existing TYPE TABLE OF zcomp_role_hdr,
        lt_to_delete   TYPE TABLE OF zcomp_role_hdr,
        ls_db_existing TYPE zcomp_role_hdr,
        ls_to_delete   TYPE zcomp_role_hdr.

*-> Owner Group Pop Up

  CLEAR lv_og.

  SELECT SINGLE owner_group FROM zcomp_role_hdr
    INTO @lv_og
    WHERE agr_name = @p_agr_name.

  IF lv_og IS INITIAL .
    CALL FUNCTION 'DD_DOMVALUES_GET'
      EXPORTING
        domname        = 'ZZ_OWNER_GROUP'
        text           = abap_true
        langu          = sy-langu
      TABLES
        dd07v_tab      = lt_dd07v
      EXCEPTIONS
        wrong_textflag = 1
        OTHERS         = 2.

    IF sy-subrc <> 0 OR lt_dd07v IS INITIAL.
      MESSAGE 'No fixed values found in domain ZZ_OWNER_GROUP' TYPE 'E'.
    ENDIF.

    LOOP AT lt_dd07v INTO DATA(ls_dd07v).
      APPEND VALUE ty_owner(
        owner_group = ls_dd07v-domvalue_l
        text        = ls_dd07v-ddtext
      ) TO lt_owner.
    ENDLOOP.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield        = 'OWNER_GROUP'
        window_title    = 'Select Owner Group'
        value_org       = 'S'
      TABLES
        value_tab       = lt_owner
        return_tab      = lt_return
      EXCEPTIONS
        parameter_error = 1
        no_values_found = 2
        OTHERS          = 3.

    IF sy-subrc = 0.
      READ TABLE lt_return INTO ls_return INDEX 1.
      IF sy-subrc = 0.
        lv_owner_grp = ls_return-fieldval.
      ENDIF.
    ENDIF.
  ENDIF.

*-> Check for Collective role (Prüfung auf Sammelrolle)
  CALL FUNCTION 'PRGN_GET_COLLECTIVE_AGR_FLAG'
    EXPORTING
      activity_group      = p_agr_name
    IMPORTING
      collective_agr_flag = lv_coll_role
    EXCEPTIONS
      agr_does_not_exist  = 1
      flag_not_available  = 2
      OTHERS              = 3.

  IF lv_coll_role EQ abap_true.
    GET PARAMETER ID 'ZUC' FIELD lv_ucomm.

    GET TIME STAMP FIELD lv_ts.                       " UTC timestamp
    CONVERT TIME STAMP lv_ts TIME ZONE 'UTC'
            INTO DATE lv_date TIME lv_time.           " split to date/time


    CLEAR lt_zcomp_role_hdr_1[].

    IF lv_ucomm = 'AEND'. "Changing composite role
      SELECT *
        FROM zcomp_role_hdr
        INTO TABLE @lt_db_existing
        WHERE agr_name = @agr_name_neu.
    ENDIF.

    LOOP AT i_actgroups.
      CLEAR lt_zcomp_role_hdr_1.
      lv_current_tmps = |{ lv_date }{ lv_time }|.

      IF lv_ucomm = 'SANLE'. "Creating composite role
        lt_zcomp_role_hdr_1-created_at = lv_current_tmps.

      ELSEIF lv_ucomm = 'AEND'. "Changing composite role
        READ TABLE lt_db_existing INTO ls_db_existing
          WITH KEY agr_name  = agr_name_neu
                   child_agr = i_actgroups-agr_name.

        IF sy-subrc = 0.
          lt_zcomp_role_hdr_1-created_at = ls_db_existing-created_at.
          lt_zcomp_role_hdr_1-changed_at = lv_current_tmps.
        ELSE.
          lt_zcomp_role_hdr_1-created_at = lv_current_tmps.
          lt_zcomp_role_hdr_1-changed_at = lv_current_tmps.
        ENDIF.
      ENDIF.

      lt_zcomp_role_hdr_1-mandt              = sy-mandt.
      lt_zcomp_role_hdr_1-agr_name           = agr_name_neu.
      lt_zcomp_role_hdr_1-child_agr_descr    = i_actgroups-text.
      lt_zcomp_role_hdr_1-child_agr          = i_actgroups-agr_name.
      lt_zcomp_role_hdr_1-wf_approval_status = 'PENDING'.
      IF lv_og IS INITIAL.
        lt_zcomp_role_hdr_1-owner_group      = lv_owner_grp.
      ELSE.
        lt_zcomp_role_hdr_1-owner_group      = lv_og.
      ENDIF.

      APPEND lt_zcomp_role_hdr_1.
    ENDLOOP.

    IF lv_ucomm = 'AEND'. "Delete removed entries
      LOOP AT lt_db_existing INTO ls_db_existing.
        READ TABLE i_actgroups WITH KEY agr_name = ls_db_existing-child_agr TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          CLEAR ls_to_delete.
          ls_to_delete = ls_db_existing.
          APPEND ls_to_delete TO lt_to_delete.
        ENDIF.
      ENDLOOP.

      IF lt_to_delete IS NOT INITIAL.
        DELETE zcomp_role_hdr FROM TABLE lt_to_delete.
      ENDIF.
    ENDIF.

    IF lt_zcomp_role_hdr_1[] IS NOT INITIAL.
      MODIFY zcomp_role_hdr FROM TABLE lt_zcomp_role_hdr_1.
      COMMIT WORK.

      TYPES: BEGIN OF ty_cd,
               upd TYPE cdchngind,        " 'I' / 'U' / 'D'  (per-row operation)
               n   TYPE zcomp_role_hdr,   " new image
               o   TYPE zcomp_role_hdr,   " old image
             END OF ty_cd.

      DATA: lt_cd      TYPE STANDARD TABLE OF ty_cd,
            ls_cd      TYPE ty_cd,
            ls_old     TYPE zcomp_role_hdr,
            lv_obj_ind TYPE cdhdr-change_ind.

      lv_obj_ind = COND #( WHEN lv_ucomm = 'SANLE' THEN 'I' ELSE 'U' ).

***      IF lv_ucomm = 'SANLE'. "Creating composite role
***        LOOP AT i_actgroups INTO DATA(ls_new_c).
***          CLEAR ls_cd.
***          MOVE-CORRESPONDING ls_new_c TO ls_cd-n.
***          ls_cd-n-agr_name = zagr_agrs-agr_name.   " ensure key is set
***          ls_cd-upd        = 'I'.
***          APPEND ls_cd TO lt_cd.
***        ENDLOOP.
***      ELSEIF lv_ucomm = 'AEND'. "Changing composite role
****             inserts + updates
***        LOOP AT itab_1 INTO DATA(ls_new).
***          READ TABLE it_snapshot INTO ls_old
***               WITH KEY child_agr = ls_new-child_agr.
***          IF sy-subrc <> 0.
***            CLEAR ls_cd.
***            MOVE-CORRESPONDING ls_new TO ls_cd-n.
***            ls_cd-n-agr_name = zagr_agrs-agr_name.
***            ls_cd-upd = 'I'.
***            APPEND ls_cd TO lt_cd.
***          ELSEIF ls_new <> ls_old.
***            CLEAR ls_cd.
***            MOVE-CORRESPONDING ls_new TO ls_cd-n.
***            MOVE-CORRESPONDING ls_old TO ls_cd-o.
***            ls_cd-n-agr_name = zagr_agrs-agr_name.
***            ls_cd-o-agr_name = zagr_agrs-agr_name.
***            ls_cd-upd = 'U'.
***            APPEND ls_cd TO lt_cd.
***          ENDIF.
***        ENDLOOP.
***
****             deletes
***        LOOP AT it_snapshot INTO ls_old.
***          READ TABLE itab_1 TRANSPORTING NO FIELDS
***               WITH KEY child_agr = ls_old-child_agr.
***          IF sy-subrc <> 0.
***            CLEAR ls_cd.
***            MOVE-CORRESPONDING ls_old TO ls_cd-o.
***            ls_cd-o-agr_name = zagr_agrs-agr_name.
***            ls_cd-upd = 'D'.
***            APPEND ls_cd TO lt_cd.
***          ENDIF.
***        ENDLOOP.
***      ENDIF.
***
***      LOOP AT lt_cd INTO ls_cd.
***        CALL FUNCTION 'ZCOMP_ROLE_WRITE_DOCUMENT'
***          EXPORTING
***            objectid                = CONV cdhdr-objectid( zagr_agrs-agr_name )
***            tcode                   = 'Z_ARC_RECMAN'
***            utime                   = sy-uzeit
***            udate                   = sy-datum
***            username                = sy-uname
***            object_change_indicator = lv_obj_ind
***            n_zcomp_role_hdr        = ls_cd-n
***            o_zcomp_role_hdr        = ls_cd-o
***            upd_zcomp_role_hdr      = ls_cd-upd.
***      ENDLOOP.
    ENDIF.

  ENDIF.
ENDENHANCEMENT.
